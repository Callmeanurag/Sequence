# Runbook: Database Connection Exhaustion

**Alert Name:** `PostgreSQLConnectionsNearLimit`  
**Severity:** P1  
**Last Updated:** 2026-06-22  
**Owner:** Platform Team

---

## What is Connection Exhaustion?

PostgreSQL has a maximum connection limit (`max_connections`, default 100 on most managed tiers). Each application pod holds a pool of database connections. If the total connections across all pods exceeds `max_connections`, new connection attempts fail with:

```
FATAL: remaining connection slots are reserved for non-replication superuser connections
```

This causes service failures even when the database itself is healthy. It is an operational misconfiguration, not a hardware failure.

---

## Alert Definition

```yaml
alert: PostgreSQLConnectionsNearLimit
expr: |
  (
    pg_stat_database_numbackends{datname="game_db"}
    /
    pg_settings_max_connections
  ) > 0.80
for: 5m
labels:
  severity: critical
annotations:
  summary: "PostgreSQL game_db connections at {{ $value | humanizePercentage }} of limit"
  runbook_url: "..."
```

---

## Step 1: Confirm Connection Count

```bash
# From inside any service pod or a debug pod with psql
kubectl run psql-debug --rm -it --image=postgres:16 \
  --restart=Never -n sequence-prod -- \
  psql "postgresql://pgadmin@psql-sequence-prod.postgres.database.azure.com/game_db" \
  -c "SELECT count(*), state, wait_event_type, wait_event
      FROM pg_stat_activity
      GROUP BY state, wait_event_type, wait_event
      ORDER BY count DESC;"

# Check max_connections setting
psql ... -c "SHOW max_connections;"

# Check connections by application
psql ... -c "SELECT application_name, count(*)
             FROM pg_stat_activity
             GROUP BY application_name
             ORDER BY count DESC;"
```

---

## Step 2: Identify the Culprit

```bash
# Which pods have the most connections?
# (Each game-service pod should have ~10-20 connections max)
kubectl get pods -n sequence-prod -l app=game-service -o wide
# Then cross-reference with pg_stat_activity.client_addr
```

**Common causes:**

| Cause | Symptom | Fix |
|---|---|---|
| Too many pods × too many connections per pod | Total = pods × pool_size > max_connections | Reduce pool size or increase max_connections |
| Connection leak | Connections in idle state growing over time | Restart affected pods, fix leak in code |
| HPA scaled too aggressively | Sudden spike in pod count | Reduce max_connections per pool |
| Long-running transactions | Connections blocked, queue backing up | Kill idle transactions |

---

## Step 3: Immediate Remediation

### Option A: Kill idle connections (fastest)

```bash
psql ... -c "
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE state = 'idle'
    AND state_change < NOW() - INTERVAL '10 minutes'
    AND datname = 'game_db';
"
```

### Option B: Scale down pods to free connections

```bash
# Temporarily reduce replicas
kubectl scale deploy game-service -n sequence-prod --replicas=3
# Wait for connections to drop
# Scale back up gradually
kubectl scale deploy game-service -n sequence-prod --replicas=5
```

### Option C: Increase max_connections (requires restart)

```bash
# Via Azure CLI (requires server restart — causes brief downtime)
az postgres flexible-server parameter set \
  --resource-group rg-sequence-data-prod \
  --server-name psql-sequence-prod \
  --name max_connections \
  --value 200
```

**Warning:** Increasing max_connections also increases PostgreSQL memory usage (~10MB per connection). Monitor memory after this change.

### Option D: Enable PgBouncer (permanent fix)

PgBouncer is a connection pooler. Application pods connect to PgBouncer (which allows thousands of connections), and PgBouncer maintains a small pool of real PostgreSQL connections.

Azure PostgreSQL Flexible Server supports PgBouncer as a built-in addon:

```bash
az postgres flexible-server parameter set \
  --resource-group rg-sequence-data-prod \
  --server-name psql-sequence-prod \
  --name pgbouncer.enabled \
  --value true
```

Connect pods to port `6432` (PgBouncer) instead of `5432` (direct PostgreSQL).

---

## Post-Incident

1. Identify root cause: leak, over-scaling, or under-configured pool
2. Set `DB_MAX_POOL_SIZE` env var to a safe value: `max_connections / max_pods / services`
3. Example: `100 connections / 10 pods / 4 services = 2.5 → set to 2`
4. Add PgBouncer if not already enabled
5. Add Prometheus alert for individual service connection counts
