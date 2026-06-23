# SLO Definitions
## Sequence Platform — Service Level Objectives

**Version:** 1.0  
**Review Cycle:** Quarterly  
**Owner:** Platform Team

---

## 1. SLI/SLO/SLA Framework

```
SLI (Service Level Indicator)
  What you measure — a quantifiable aspect of service behavior.
  Always a ratio: good events / total events.

SLO (Service Level Objective)
  Your internal target — what percentage of time the SLI must be met.
  This is the line you cannot cross without consequences.

Error Budget
  The allowed failure: 1 - SLO, expressed as time or events.
  When burned, it triggers action (freeze deployments, post-mortem).

SLA (Service Level Agreement)
  External commitment — always less aggressive than SLO.
  SLO is your safety buffer before SLA is breached.
```

---

## 2. SLI Definitions

### Availability SLI

```
Definition: The proportion of HTTP requests that return a non-5xx response.

PromQL:
  sum(rate(http_requests_total{code!~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))

Exclusions:
  - 499 (client closed connection) is NOT counted as failure
  - Planned maintenance windows excluded (announced 72h in advance)
  - Health check endpoints (/healthz, /readyz) excluded from SLI measurement
```

### Latency SLI

```
Definition: The proportion of HTTP requests that complete within the threshold.

PromQL (game-service, 200ms threshold):
  sum(rate(http_request_duration_seconds_bucket{
    service="game-service", le="0.2"
  }[5m]))
  /
  sum(rate(http_request_duration_seconds_count{service="game-service"}[5m]))

Measurement: Measured at Envoy sidecar (Istio) — includes network overhead, 
not just application processing time.
```

---

## 3. SLO Targets

### auth-service

| SLI | Target | Window | Error Budget |
|---|---|---|---|
| Availability | 99.9% | 28 days | 40 minutes |
| Latency p99 < 100ms | 99.5% | 28 days | 201 minutes |

**Justification:** Auth is on the critical path for every user action. High availability target (99.9%) because auth failure means users cannot play at all.

### game-service

| SLI | Target | Window | Error Budget |
|---|---|---|---|
| Availability | 99.5% | 28 days | 201 minutes |
| Latency p99 < 200ms | 99.0% | 28 days | 403 minutes |

**Justification:** The most complex service with WebSocket state. Slightly lower availability target acknowledges higher deployment frequency and complexity. 200ms latency threshold accounts for Redis round-trip for game state.

### matchmaking-service

| SLI | Target | Window | Error Budget |
|---|---|---|---|
| Availability | 99.0% | 28 days | 403 minutes |
| Match found p95 < 5s | 95.0% | 28 days | — |

**Justification:** Matchmaking failure means players cannot start new games, but active games are unaffected. Lower target reflects asynchronous nature and acceptable degradation.

### leaderboard-service

| SLI | Target | Window | Error Budget |
|---|---|---|---|
| Availability | 99.0% | 28 days | 403 minutes |
| Latency p99 < 500ms | 99.0% | 28 days | 403 minutes |

**Justification:** Leaderboard is read-heavy, non-critical path. Slightly higher latency threshold because queries involve complex aggregations.

### notification-service

| SLI | Target | Window | Error Budget |
|---|---|---|---|
| Availability | 99.0% | 28 days | 403 minutes |
| Delivery success rate | 95.0% | 28 days | — |

**Justification:** Push notifications are best-effort. A missed notification is annoying but does not break gameplay.

---

## 4. Error Budget Calculations

### Formula

```
28-day error budget = (1 - SLO) × 28 × 24 × 60 minutes

auth-service (99.9% SLO):
  (1 - 0.999) × 40,320 = 40.32 minutes ≈ 40 minutes

game-service (99.5% SLO):
  (1 - 0.995) × 40,320 = 201.6 minutes ≈ 201 minutes

matchmaking-service (99.0% SLO):
  (1 - 0.990) × 40,320 = 403.2 minutes ≈ 403 minutes
```

---

## 5. SLO Measurement

### Prometheus Recording Rules

```yaml
groups:
- name: slo-recording-rules
  interval: 30s
  rules:

  # auth-service availability (5-minute window)
  - record: slo:auth_service:availability:ratio_rate5m
    expr: |
      sum(rate(http_requests_total{service="auth-service",code!~"5.."}[5m]))
      /
      sum(rate(http_requests_total{service="auth-service"}[5m]))

  # game-service availability (5-minute window)
  - record: slo:game_service:availability:ratio_rate5m
    expr: |
      sum(rate(http_requests_total{service="game-service",code!~"5.."}[5m]))
      /
      sum(rate(http_requests_total{service="game-service"}[5m]))

  # game-service latency SLI (200ms threshold)
  - record: slo:game_service:latency200ms:ratio_rate5m
    expr: |
      sum(rate(http_request_duration_seconds_bucket{service="game-service",le="0.2"}[5m]))
      /
      sum(rate(http_request_duration_seconds_count{service="game-service"}[5m]))
```

### Grafana Dashboard

See [../observability/grafana/dashboards/](../../observability/grafana/dashboards/) for the SLO dashboard JSON.

The SLO dashboard shows:
- Current SLI value (big number, red/green based on SLO threshold)
- Error budget remaining (percentage + time remaining)
- Error budget burn rate (current rate vs allowed rate)
- 28-day rolling window chart

---

## 6. Review Process

- **Weekly:** SLO review in team standup — are we within budget?
- **Monthly:** Error budget review — trend analysis, deployment correlation
- **Quarterly:** SLO target review — adjust targets based on operational maturity
- **Post-incident:** SLO impact assessment within 48 hours of any incident
