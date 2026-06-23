# Low Level Design (LLD)
## Sequence — Service Specifications

**Version:** 1.0  
**Date:** 2026-06-22

---

## 1. Service Inventory

| Service | Language | Port(s) | Protocol | Min Replicas | Max Replicas | Scaling Trigger |
|---|---|---|---|---|---|---|
| auth-service | Go | 8080 | REST | 2 | 10 | CPU > 70% |
| game-service | Go | 8080, 8081 | REST + WebSocket | 3 | 20 | Active WS connections (KEDA) |
| matchmaking-service | Go | 8080 | REST | 2 | 8 | Queue depth (KEDA) |
| leaderboard-service | Go | 8080 | REST | 2 | 6 | CPU > 60% |
| notification-service | Go | 8080 | REST | 2 | 8 | Queue depth (KEDA) |
| analytics-service | Go | 8080 | REST | 1 | 4 | CPU > 80% |

---

## 2. Auth Service

### Responsibilities
- User registration and login
- JWT access token issuance (RS256)
- Refresh token management via Redis
- Token validation endpoint (called by Istio JWT policy)

### API Contract

```
POST   /api/v1/auth/register
  Body:    { "email": "string", "password": "string", "displayName": "string" }
  Returns: 201 { "userId": "uuid", "accessToken": "jwt", "refreshToken": "string" }
  Errors:  409 email already exists | 400 validation error

POST   /api/v1/auth/login
  Body:    { "email": "string", "password": "string" }
  Returns: 200 { "accessToken": "jwt", "refreshToken": "string", "expiresIn": 900 }
  Errors:  401 invalid credentials | 429 rate limited

POST   /api/v1/auth/refresh
  Body:    { "refreshToken": "string" }
  Returns: 200 { "accessToken": "jwt", "expiresIn": 900 }
  Errors:  401 invalid/expired refresh token

GET    /api/v1/auth/me
  Headers: Authorization: Bearer <token>
  Returns: 200 { "userId": "uuid", "email": "string", "displayName": "string" }

DELETE /api/v1/auth/logout
  Headers: Authorization: Bearer <token>
  Returns: 204 (invalidates refresh token in Redis)

GET    /healthz       → 200 { "status": "ok" }
GET    /readyz        → 200 or 503
GET    /metrics       → Prometheus metrics (port 9090)
```

### Data Model

```sql
-- PostgreSQL schema
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) UNIQUE NOT NULL,
  display_name  VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,  -- bcrypt cost=12
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  is_active     BOOLEAN DEFAULT true
);

CREATE INDEX idx_users_email ON users(email);

-- Redis schema
-- Key: refresh_token:{token}  Value: userId  TTL: 7 days
-- Key: rate_limit:{ip}        Value: count   TTL: 60 seconds
```

### Security Configuration

```
- Passwords: bcrypt, cost factor 12
- Access tokens: JWT RS256, 15-minute expiry
  - Claims: sub (userId), email, iat, exp, iss
- Refresh tokens: 32-byte random, stored in Redis with TTL
- Rate limiting: 5 failed logins per minute per IP
- Private key: stored in Azure Key Vault, loaded at startup via CSI Driver
```

### Resource Requirements

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

---

## 3. Game Service

### Responsibilities
- Manage active game sessions (create, join, start)
- Validate and apply game moves (Sequence card game rules)
- Maintain real-time board state in Redis
- Broadcast moves to all players via WebSocket
- Persist completed games to PostgreSQL
- Publish domain events to NATS

### API Contract

```
REST Endpoints:
POST   /api/v1/games
  Body:    { "hostId": "uuid", "maxPlayers": 2 }
  Returns: 201 { "gameId": "uuid", "status": "waiting" }

POST   /api/v1/games/{gameId}/join
  Body:    { "playerId": "uuid" }
  Returns: 200 { "gameId": "uuid", "status": "ready" }

GET    /api/v1/games/{gameId}
  Returns: 200 { "gameId", "board", "players", "currentTurn", "status" }

WebSocket Endpoint: ws://game-service/ws/{gameId}?token=<jwt>

Client → Server Messages:
  { "type": "PLACE_CARD", "card": "KS", "position": {"row": 3, "col": 4} }
  { "type": "PING" }

Server → Client Messages:
  { "type": "GAME_STATE",   "board": [...], "hand": [...], "currentTurn": "uuid" }
  { "type": "MOVE_ACCEPTED","board": [...], "nextTurn": "uuid" }
  { "type": "MOVE_INVALID", "reason": "Card not in hand" }
  { "type": "GAME_OVER",    "winner": "uuid", "sequence": [...] }
  { "type": "PLAYER_JOINED","playerId": "uuid", "displayName": "string" }
  { "type": "PLAYER_LEFT",  "playerId": "uuid" }
  { "type": "PONG" }
```

### Game State Schema (Redis)

```
Key: game:{gameId}
Type: Hash
Fields:
  board        → JSON string (10x10 grid, each cell: null | {playerId, card})
  status       → "waiting" | "active" | "completed"
  current_turn → UUID of player whose turn it is
  players      → JSON array of {playerId, displayName, hand: [cards]}
  created_at   → Unix timestamp
  updated_at   → Unix timestamp
TTL: 4 hours (auto-expire inactive games)

Key: game:{gameId}:connections
Type: Set
Members: {playerId} (active WebSocket connections)
TTL: 4 hours
```

### Data Model (PostgreSQL)

```sql
CREATE TABLE game_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status       VARCHAR(20) NOT NULL,  -- waiting, active, completed
  host_id      UUID NOT NULL,
  winner_id    UUID,
  max_players  INTEGER DEFAULT 2,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE game_moves (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     UUID NOT NULL REFERENCES game_sessions(id),
  player_id   UUID NOT NULL,
  card        VARCHAR(5) NOT NULL,  -- e.g. "KS" = King of Spades
  position    JSONB NOT NULL,       -- {"row": 3, "col": 4}
  move_number INTEGER NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_game_moves_game_id ON game_moves(game_id);
```

### NATS Events Published

```
Event: game.move.made
Payload: { gameId, playerId, card, position, timestamp }

Event: game.completed
Payload: { gameId, winnerId, loserId, duration, moveCount }

Event: game.player.joined
Payload: { gameId, playerId, displayName }
```

### Resource Requirements

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "1000m"
    memory: "512Mi"
```

---

## 4. Matchmaking Service

### Responsibilities
- Maintain a queue of players waiting for a game
- Match players with similar skill ratings
- Create game sessions via game-service
- Notify matched players via notification-service

### API Contract

```
POST /api/v1/matchmaking/queue
  Body:    { "playerId": "uuid", "gameMode": "casual|ranked" }
  Returns: 202 { "queueId": "uuid", "estimatedWaitSeconds": 15 }

DELETE /api/v1/matchmaking/queue/{queueId}
  Returns: 204 (leave queue)

GET /api/v1/matchmaking/queue/{queueId}/status
  Returns: 200 { "status": "waiting|matched|expired", "gameId": "uuid?" }
```

### KEDA ScaledObject

```yaml
scaleTargetRef: matchmaking-service
triggers:
  - type: redis
    metadata:
      address: redis-sequence-prod.redis.cache.windows.net:6380
      listName: matchmaking_queue
      listLength: "5"   # scale up when 5+ players waiting
```

---

## 5. Leaderboard Service

### Responsibilities
- Maintain global player rankings
- Expose leaderboard API (top N players, player rank)
- Update rankings on game.completed events

### API Contract

```
GET /api/v1/leaderboard?limit=100&offset=0
  Returns: 200 { "players": [{rank, playerId, displayName, wins, losses, rating}] }

GET /api/v1/leaderboard/player/{playerId}
  Returns: 200 { "rank": 42, "rating": 1350, "wins": 28, "losses": 14 }
```

### Data Model

```sql
CREATE TABLE player_stats (
  player_id   UUID PRIMARY KEY,
  wins        INTEGER DEFAULT 0,
  losses      INTEGER DEFAULT 0,
  rating      INTEGER DEFAULT 1200,  -- ELO rating
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Materialized view for leaderboard (refreshed every minute)
CREATE MATERIALIZED VIEW leaderboard AS
SELECT
  ROW_NUMBER() OVER (ORDER BY rating DESC, wins DESC) as rank,
  player_id, wins, losses, rating
FROM player_stats
ORDER BY rating DESC;
```

---

## 6. Notification Service

### Responsibilities
- Consume game events from NATS
- Send push notifications to mobile clients
- Support email notifications (future)

### Event Subscriptions

```
Subscribes to: game.move.made      → Notify opponent: "It's your turn!"
Subscribes to: game.completed      → Notify loser: "Better luck next time"
Subscribes to: game.player.joined  → Notify host: "Player joined, ready to start"
```

### KEDA ScaledObject

```yaml
scaleTargetRef: notification-service
triggers:
  - type: nats-jetstream
    metadata:
      natsServerMonitoringEndpoint: nats-monitoring:8222
      streamName: GAME_EVENTS
      consumerName: notification-consumer
      lagThreshold: "10"
```

---

## 7. Analytics Service

### Responsibilities
- Consume all game events for business analytics
- Store aggregated metrics in PostgreSQL
- Expose reporting API

### Data Model

```sql
CREATE TABLE game_analytics (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id       UUID NOT NULL,
  event_type    VARCHAR(50) NOT NULL,
  player_id     UUID,
  event_data    JSONB,
  recorded_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_analytics_game_id ON game_analytics(game_id);
CREATE INDEX idx_analytics_recorded_at ON game_analytics(recorded_at);
```

---

## 8. Kubernetes Namespace Strategy

```
cluster
├── kube-system          → K8s system (CoreDNS, kube-proxy)
├── istio-system         → Istio control plane (istiod, ingress gateway)
├── cert-manager         → Certificate management
├── argocd               → GitOps controller
├── monitoring           → Prometheus, Grafana, Loki, Tempo, Alertmanager
├── keda                 → KEDA operator
├── sequence-dev         → Development environment (all services)
├── sequence-staging     → Staging environment (all services)
└── sequence-prod        → Production environment (all services)
```

---

## 9. Resource Sizing Summary

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---|---|---|---|---|
| auth-service | 100m | 500m | 128Mi | 256Mi |
| game-service | 250m | 1000m | 256Mi | 512Mi |
| matchmaking-service | 100m | 500m | 128Mi | 256Mi |
| leaderboard-service | 100m | 500m | 128Mi | 256Mi |
| notification-service | 100m | 500m | 128Mi | 256Mi |
| analytics-service | 100m | 500m | 128Mi | 256Mi |

> **Why this matters:** Every pod MUST have resource requests and limits. Without requests, the scheduler cannot make good placement decisions. Without limits, one misbehaving pod can starve all others on the node (the "noisy neighbor" problem). Kyverno enforces this via admission policy.
