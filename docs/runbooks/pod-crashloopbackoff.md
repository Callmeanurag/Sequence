# Runbook: Pod CrashLoopBackOff

**Alert Name:** `PodCrashLoopBackOff`  
**Severity:** P2 (single pod) / P1 (all pods of a service)  
**Last Updated:** 2026-06-22

---

## What is CrashLoopBackOff?

CrashLoopBackOff means Kubernetes has tried to start a container multiple times, but it keeps crashing. The "BackOff" means Kubernetes is applying exponential backoff between restart attempts (10s, 20s, 40s, 80s... up to 5 minutes).

The container has exited with a non-zero exit code. Kubernetes will keep retrying but increasingly less frequently.

---

## Immediate Triage

```bash
# Identify affected pod(s)
kubectl get pods -n sequence-prod | grep CrashLoopBackOff

# How many restarts?
kubectl get pod <pod-name> -n sequence-prod \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Get the exit code (why did it crash?)
kubectl get pod <pod-name> -n sequence-prod \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'

# Get last crash logs (before the container exited)
kubectl logs <pod-name> -n sequence-prod --previous

# Describe for events (OOMKilled, liveness probe failure, etc.)
kubectl describe pod <pod-name> -n sequence-prod
```

---

## Exit Code Reference

| Exit Code | Meaning | Likely Cause |
|---|---|---|
| 0 | Exited cleanly | Application bug — main() returned unexpectedly |
| 1 | General error | Application panic, unhandled error |
| 137 | OOMKilled (128 + 9) | Memory limit exceeded — increase limit |
| 139 | Segfault (128 + 11) | Memory corruption — application bug |
| 143 | SIGTERM not handled | Application doesn't handle graceful shutdown |

---

## Scenario A: Application Panic (exit code 1)

```bash
# Read the last logs
kubectl logs <pod-name> -n sequence-prod --previous --tail=50

# Look for: panic, FATAL, error, failed to connect
# Common causes:
#   - Cannot connect to Redis/PostgreSQL on startup
#   - Missing environment variable or secret
#   - Bad configuration

# Check if secrets are mounted correctly
kubectl exec <pod-name> -n sequence-prod -- ls /mnt/secrets/

# Check if Key Vault secrets are accessible
kubectl describe secretproviderclass -n sequence-prod
```

**If missing secret:**
```bash
# Check the SecretProviderClass is configured correctly
kubectl get secretproviderclass -n sequence-prod -o yaml

# Check Workload Identity is set up correctly
kubectl describe pod <pod-name> -n sequence-prod | grep -A5 "AZURE_"

# Check the managed identity has access to Key Vault
az keyvault secret show --name db-connection-string --vault-name kv-sequence-prod
```

---

## Scenario B: OOMKilled (exit code 137)

```bash
# Confirm OOMKill
kubectl describe pod <pod-name> -n sequence-prod | grep -A3 "OOMKilled"

# Check current memory usage across pods
kubectl top pods -n sequence-prod -l app=<service-name>

# Emergency: increase memory limit
kubectl set resources deploy/<service-name> -n sequence-prod \
  --limits=memory=512Mi

# Note: This change will be reverted by ArgoCD unless also committed to Git
# Long-term fix: update kubernetes/base/<service>/deployment.yaml
```

---

## Scenario C: Liveness Probe Failure

```bash
# Check liveness probe configuration
kubectl describe pod <pod-name> -n sequence-prod | grep -A10 "Liveness"

# Is the health endpoint responding?
kubectl exec <pod-name> -n sequence-prod -- curl -s localhost:8080/healthz

# Common fixes:
# 1. Increase initialDelaySeconds if app takes long to start
# 2. Increase failureThreshold if transient failures are expected
# 3. Fix the actual health issue the probe is catching
```

---

## Scenario D: Bad Deployment

```bash
# Is this affecting only newly deployed pods?
kubectl get replicaset -n sequence-prod -l app=<service-name>

# What changed?
argocd app history <service-name>

# Rollback
argocd app rollback <service-name> <previous-revision>

# Verify rollback
kubectl get pods -n sequence-prod -l app=<service-name> -w
```

---

## Prevention

1. **Startup probe** for slow-starting applications (separate from liveness)
2. **Resource limits** set conservatively with room for growth
3. **Graceful shutdown** — handle SIGTERM, drain connections before exit
4. **Readiness probe** — don't send traffic until app is ready
5. **PodDisruptionBudget** — ensure at least 1 pod stays running during evictions
