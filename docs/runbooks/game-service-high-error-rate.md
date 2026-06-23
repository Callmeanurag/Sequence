# Runbook: game-service High Error Rate

**Alert Name:** `GameServiceHighErrorRate`  
**Severity:** P1 (error rate > 5%) / P2 (error rate 1-5%)  
**Last Updated:** 2026-06-22  
**Owner:** Platform Team

---

## Alert Definition

```yaml
alert: GameServiceHighErrorRate
expr: |
  (
    1 - sum(rate(http_requests_total{service="game-service",code!~"5.."}[5m]))
    /
    sum(rate(http_requests_total{service="game-service"}[5m]))
  ) > 0.01
for: 3m
labels:
  severity: warning
annotations:
  summary: "game-service error rate above 1%"
  runbook_url: "https://github.com/Callmeanurag/Sequence/blob/main/docs/runbooks/game-service-high-error-rate.md"
```

---

## Impact Assessment

| Error Rate | Impact | Severity |
|---|---|---|
| > 5% | Active games failing, players experiencing errors | P1 — page on-call |
| 1-5% | Some games affected, degraded experience | P2 — investigate within 30 minutes |
| 0.5-1% | Within SLO budget burn, monitor | P3 — create ticket |

---

## Step 1: Assess Scope

```bash
# How many pods are running?
kubectl get pods -n sequence-prod -l app=game-service

# What is the current error rate? (check Grafana or run PromQL)
# Dashboard: http://grafana.sequence.internal/d/game-service

# When did errors start? (check alert timeline)
kubectl get events -n sequence-prod --sort-by='.lastTimestamp' | tail -20
```

---

## Step 2: Check Pod Health

```bash
# Are any pods in CrashLoopBackOff or Error?
kubectl get pods -n sequence-prod -l app=game-service -o wide

# Describe a failing pod
kubectl describe pod <pod-name> -n sequence-prod

# What are the recent logs showing?
kubectl logs -n sequence-prod -l app=game-service --tail=100 --since=10m

# Are pods restarting frequently?
kubectl get pods -n sequence-prod -l app=game-service \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
```

**Common findings and actions:**

| Finding | Action |
|---|---|
| Pods in CrashLoopBackOff | Check logs for panic/OOM, check if bad deploy → rollback |
| High restart count (> 5) | Check memory limits — may need to increase |
| All pods healthy | Issue is upstream (Redis/Postgres) or downstream (clients) |

---

## Step 3: Check Dependencies

```bash
# Test Redis connectivity from inside a pod
kubectl exec -n sequence-prod deploy/game-service -- \
  redis-cli -h redis-sequence-prod.redis.cache.windows.net -p 6380 --tls ping

# Test PostgreSQL connectivity
kubectl exec -n sequence-prod deploy/game-service -- \
  pg_isready -h psql-sequence-prod.postgres.database.azure.com -U gameuser

# Check Redis memory usage (OOM causes errors)
kubectl exec -n sequence-prod deploy/game-service -- \
  redis-cli -h redis-sequence-prod.redis.cache.windows.net -p 6380 --tls \
  info memory | grep used_memory_human
```

---

## Step 4: Check Istio Circuit Breaker Status

```bash
# Is the circuit breaker ejecting pods?
istioctl x describe pod <game-service-pod> -n sequence-prod

# Check Envoy cluster outlier detection stats
kubectl exec -n sequence-prod <game-service-pod> -c istio-proxy -- \
  curl localhost:15000/clusters | grep outlier
```

---

## Step 5: Check Recent Deployments

```bash
# Was there a recent deployment?
argocd app history game-service

# What changed in the last deploy?
argocd app diff game-service

# Check if the new image has issues
kubectl get deploy game-service -n sequence-prod \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Remediation Procedures

### Scenario A: Bad Deployment

```bash
# Rollback to previous ArgoCD revision
argocd app rollback game-service <previous-revision-number>

# Verify rollback completed
argocd app wait game-service --timeout 120

# Confirm error rate recovering (wait 3-5 minutes)
# Check Grafana dashboard
```

### Scenario B: Redis Connection Issues

```bash
# Scale up game-service (more pods = more connection retry attempts)
kubectl scale deploy game-service -n sequence-prod --replicas=6

# If Redis is down entirely, check Azure Portal for Redis health
# Azure Portal → sequence-prod Redis → Overview → Status

# Enable in-memory fallback (if implemented)
kubectl set env deploy/game-service -n sequence-prod REDIS_FALLBACK_ENABLED=true
```

### Scenario C: PostgreSQL Connection Exhaustion

```bash
# Check current connection count
kubectl exec -n sequence-prod deploy/game-service -- \
  psql "postgresql://gameuser@psql-sequence-prod.postgres.database.azure.com/game_db" \
  -c "SELECT count(*) FROM pg_stat_activity WHERE datname='game_db';"

# If approaching max_connections (100 default), enable read replica routing
kubectl set env deploy/game-service -n sequence-prod DB_READ_REPLICA_ENABLED=true

# Restart some pods to release connections
kubectl rollout restart deploy/game-service -n sequence-prod
```

### Scenario D: Memory OOM (pods being OOMKilled)

```bash
# Confirm OOM kills
kubectl describe pod <pod-name> -n sequence-prod | grep -A5 "OOMKilled"

# Temporarily increase memory limit (emergency patch)
kubectl set resources deploy/game-service -n sequence-prod \
  --limits=memory=1Gi

# Long-term: update kubernetes/base/game-service/deployment.yaml
# and commit to Git for ArgoCD to manage
```

---

## Escalation

| Time | Action |
|---|---|
| T+0 | On-call engineer investigates |
| T+15m | If unresolved, notify tech lead |
| T+30m | If unresolved, activate incident commander |
| T+60m | Stakeholder communication if player impact confirmed |

---

## Post-Incident

After resolution:
1. Update this runbook with any new findings
2. Create post-mortem ticket if P1
3. Add missing alert if detection was slow
4. Assess error budget impact and update SLO dashboard
