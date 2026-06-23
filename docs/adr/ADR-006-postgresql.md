# ADR-006: Azure Database for PostgreSQL Flexible Server

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

The system requires ACID-compliant relational storage for users, game history, leaderboards, and analytics. Options include self-managed PostgreSQL in Kubernetes, Azure Database for PostgreSQL (Flexible or Single Server), or Azure SQL.

## Decision

Use Azure Database for PostgreSQL Flexible Server with zone-redundant HA.

## Rationale

**Self-managed PostgreSQL in Kubernetes:**
Running PostgreSQL as a StatefulSet requires managing: PersistentVolumes, backups (pgBackRest/Barman), HA (Patroni), connection pooling (PgBouncer), certificate rotation, and major version upgrades. This is valuable learning but not the focus of this project.

**PostgreSQL Flexible Server advantages:**
- Zone-redundant HA: synchronous standby in a different AZ, automatic failover in ~60 seconds
- Point-in-time restore: up to 35 days, any 5-minute granularity
- Private endpoint: database not exposed to the internet
- PgBouncer: built-in connection pooling addon
- Managed backups: automated, no operational overhead
- Maintenance window: configurable, can avoid peak game hours

**Why not Single Server:**
Azure Database for PostgreSQL Single Server is deprecated and will be retired. Flexible Server is the strategic path forward.

**Why not Azure SQL:**
PostgreSQL is preferred for:
- Open-source (no vendor lock-in concerns)
- JSON/JSONB support for game state queries
- Extensions ecosystem (uuid-ossp, pg_trgm, PostGIS future)
- More widely used in the industry for this use case

## Database Per Service Strategy

Each microservice that needs a database gets its own database (not schema) within the same Flexible Server instance for cost efficiency:

```
psql-sequence-prod
  ├── auth_db      (auth-service)
  ├── game_db      (game-service)
  ├── leaderboard_db (leaderboard-service)
  └── analytics_db (analytics-service)
```

In a true production system at scale, each service would have its own Flexible Server instance for complete isolation. For this project, database-per-service within one instance balances the microservices principle with cost.

## Consequences

**Positive:**
- Zero PostgreSQL operational overhead (backups, HA, patches managed by Azure)
- Zone-redundant HA with automatic failover
- Private endpoint ensures no public internet exposure
- PITR enables recovery from accidental data deletion

**Negative:**
- Higher cost than self-managed (~$385/month for production tier)
- Less control over PostgreSQL configuration parameters
- Azure-managed upgrade schedule (though maintenance windows configurable)

## Interview Guidance

**Question:** "How do pods connect to PostgreSQL without storing credentials?"

Answer: "The connection string (host, database, username, password) is stored as a secret in Azure Key Vault. The CSI Secret Store Driver, configured with Workload Identity, mounts the secret as a file in the pod at startup. The application reads the connection string from the file. No credentials appear in environment variables, pod specs, or Kubernetes Secrets. Key Vault rotation of the secret is automatically reflected in the pod within 2 minutes (configured rotation interval). This means credential rotation requires zero pod restarts and zero deployments."
