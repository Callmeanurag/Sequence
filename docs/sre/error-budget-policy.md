# Error Budget Policy
## Sequence Platform

**Version:** 1.0  
**Effective Date:** 2026-06-22

---

## Purpose

This policy defines how the team responds to error budget consumption. Its goal is to align reliability investment with feature development pace. When the system is reliable (budget intact), teams move fast. When reliability degrades (budget burning), teams slow down and fix.

## Error Budget States

| Budget Remaining | State | Required Actions |
|---|---|---|
| 100% - 51% | Green | Normal operations — deploy freely |
| 50% - 26% | Yellow | Increased vigilance — review risky changes |
| 25% - 11% | Orange | Restricted — freeze non-critical deployments |
| 10% - 1% | Red | Critical — freeze all deployments |
| 0% burned | Exhausted | Emergency — post-mortem required within 48h |

---

## State: Green (> 50% remaining)

**Allowed actions:**
- All feature deployments
- Infrastructure changes
- Dependency upgrades
- Experimental features

**Required:**
- Continue normal monitoring cadence
- Deploy with standard review process

---

## State: Yellow (26-50% remaining)

**Allowed actions:**
- Feature deployments after review
- Infrastructure changes with change management process

**Restricted:**
- Large or high-risk changes require additional review
- Database schema migrations require staged rollout plan

**Required:**
- Review deployment in team standup before merging
- On-call engineer must be available during deployments

---

## State: Orange (11-25% remaining)

**Blocked:**
- Non-critical feature deployments
- Infrastructure experiments
- Dependency upgrades without security justification

**Allowed (with approval):**
- Critical bug fixes
- Security patches
- Infrastructure fixes that improve reliability

**Required:**
- Engineering lead must approve all deployments
- Post-deployment monitoring for 2 hours minimum
- Incident response plan documented before deployment

---

## State: Red (1-10% remaining)

**Blocked:**
- All non-emergency deployments
- Infrastructure changes

**Allowed (emergency only):**
- P0 incident fixes only
- Requires incident commander approval
- Requires rollback plan documented and rehearsed

**Required:**
- 24/7 on-call coverage activated
- Escalation to engineering leadership
- Daily error budget update in team channel

---

## State: Exhausted (0% remaining)

**Immediate actions:**
1. Freeze all deployments — no exceptions without VP approval
2. Incident commander assigned within 1 hour
3. Root cause analysis begins immediately
4. Post-mortem scheduled within 48 hours

**Recovery actions:**
1. Identify top 3 reliability improvement projects
2. Dedicate 100% of engineering capacity to reliability for 1 sprint
3. New SLO review after recovery (may need to adjust targets)
4. Gate future deployments behind SLO recovery

---

## Error Budget Burn Rate Alerts

Multi-window burn rate alerting (from Google SRE Book):

```
Fast burn (immediate page):
  Condition: burn rate > 14× over 1 hour
  Meaning: At this rate, the full 28-day budget burns in 48 hours
  Action: Page on-call immediately

Slow burn (ticket):
  Condition: burn rate > 5× over 6 hours
  Meaning: At this rate, full budget burns in ~5-6 days
  Action: Create P2 ticket, review in next standup
```

**Why multi-window?**
A single window has a problem: a 1-minute spike would trigger an alert but isn't catastrophic. A slow degradation over days would not trigger an alert until it's too late. Multi-window catches both.
