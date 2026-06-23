# ADR-007: Azure Cache for Redis for Game State and Sessions

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

Real-time game state (active board, player hands, turn timers) and auth sessions (refresh tokens, rate limit counters) require sub-millisecond read/write latency that PostgreSQL cannot provide.

## Decision

Use Azure Cache for Redis Premium P1 tier with zone-redundancy and AOF persistence.

## Rationale

**Why Redis:**
- Sub-millisecond latency (< 1ms for local Redis, < 2ms via Azure private endpoint)
- Hash data structure maps perfectly to game board state
- Pub/Sub for broadcasting game moves to connected WebSocket clients
- TTL-based expiry for auto-cleaning inactive games and expired sessions
- MULTI/EXEC transactions for atomic game state updates (prevent partial updates)
- Native support as KEDA scaler source (queue length → pod count)

**Why Premium tier:**
- Zone-redundant: replicas in different AZs, automatic failover
- AOF persistence: Append-Only File ensures data survives Redis restarts
- Private endpoint: no public internet exposure
- 99.99% SLA (vs 99.9% for Standard)

**Premium P1 spec:** 6GB memory, zone-redundant, ~$280/month

**What is stored in Redis vs PostgreSQL:**

| Data | Redis | PostgreSQL | Reason |
|---|---|---|---|
| Active game board | ✓ | | Real-time, sub-ms reads |
| Player hands (cards) | ✓ | | Real-time, per-move access |
| Turn timers | ✓ | | TTL-based expiry |
| Auth refresh tokens | ✓ | | Fast lookup + TTL expiry |
| Rate limit counters | ✓ | | Atomic INCR + TTL |
| Game history | | ✓ | Permanent, queryable |
| User accounts | | ✓ | ACID, permanent |
| Leaderboards | | ✓ | Complex queries, joins |

## Common Mistake

Storing game history or user data in Redis. Redis is volatile — even with AOF persistence, it is designed for hot/ephemeral data. Permanent business data belongs in PostgreSQL. Redis is the cache; PostgreSQL is the system of record.

## Consequences

**Positive:**
- < 2ms game state reads via Azure private endpoint
- Pub/Sub eliminates polling for real-time move broadcasting
- TTL-based auto-cleanup of inactive games (no cron jobs needed)
- KEDA scales notification-service and matchmaking-service based on Redis queue depth

**Negative:**
- Premium tier cost ($280/month)
- Data loss risk: AOF persistence reduces but doesn't eliminate data loss risk on catastrophic failure
- Memory-limited: game state must be compact; cannot store large objects

## Interview Guidance

**Question:** "How does game state survive a game-service pod restart?"

Answer: "Active game state — the board, player hands, current turn — lives in Redis, not in the pod. When a game-service pod restarts (due to an update, node eviction, or crash), the reconnecting WebSocket client sends its gameId. The new game-service pod reads the current board state from Redis and sends it to the client. The player experiences a brief reconnect delay but the game state is intact. This is stateless pod design — pods are ephemeral, state is external."

**Question:** "Why not use a Redis cluster inside Kubernetes instead of Azure Cache for Redis?"

Answer: "For this project, managed Redis eliminates operational overhead that isn't the learning focus. In a production microservices environment, you generally want critical stateful services — databases, caches — outside the Kubernetes cluster to decouple their availability from cluster operations like upgrades, node evictions, and autoscaling events. A Redis cluster inside Kubernetes that loses quorum during a cluster upgrade would take down active game sessions."
