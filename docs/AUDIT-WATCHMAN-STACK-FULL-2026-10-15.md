---
name: Watchman Stack Full Install Audit
type: audit-report
status: RESOLVED
version: "4.0.0"
date: 2026-10-15
standards_ref: dokploy-compose-manager/SKILL.md §3-§3.5 + dokploy-operator/SKILL.md Corollary
---

# Watchman Stack — Full Install Audit

## Architecture (Corrected)

```
Tier 1: dokploy-operator
  → Owns: compose lifecycle, container management, platform health
  → MUST dispatch to Tier 2 after compose deploy

Tier 2: dokploy-compose-manager  
  → Owns: 7-step install contract (§3) + Post-Deploy Hook (§3.5)
  → MUST dispatch to Tier 3 after Step 7 verification

Tier 3:
  → observability-operator: O1 Prometheus, O2 Alertmanager, O3 Grafana, O4 Healthchecks.io
  → traefik-operator: Domain routes, middleware
  → homer-operator: Dashboard entries
  → fleet-control-operator: Playbook execution
```

## REQUIRED Dispatch Chain

| When | Dispatch From | Dispatch To | Action |
|-------|-------------|------------|--------|
| Compose deployed | dokploy-operator (Tier 1) | dokploy-compose-manager (Tier 2) | Run §3 install contract |
| Step 7 complete | dokploy-compose-manager (Tier 2) | observability-operator (Tier 3) | O1-O5 post-deploy hooks |
| Step 7 complete | dokploy-compose-manager (Tier 2) | traefik-operator (Tier 3) | Domain routes |
| Step 7 complete | dokploy-compose-manager (Tier 2) | homer-operator (Tier 3) | Dashboard entry |
| Step 7 complete | dokploy-compose-manager (Tier 2) | fleet-control-operator (Tier 3) | SOT update + Semaphore playbook |

## Audit Summary

## Audit Summary

| Compose | Deploy | T1→T2 Dispatch | T2→T3 Dispatch | Domain | Backup | HC | O1-O5 | Homer | SOT |
|--------|--------|--------------|--------------|--------|--------|----|---------|-------|-----|
| watchman-backend | ✅ | ❌ **MISSING** | ❌ MISSING | ✅ | ✅ | ❌ | ❌ | N/A | ❌ |
| watchman-grafana | ✅ | ❌ **MISSING** | ❌ MISSING | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| watchman-edge-fnet1 | ✅ fixed | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |
| watchman-edge-fnet2 | ✅ | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |
| watchman-edge-fnet3 | ✅ | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |
| watchman-edge-fnet4 | ✅ | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |
| watchman-edge-fnet5 | ✅ | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |
| watchman-edge-fnet6 | ✅ | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |
| watchman-edge-fnet7 | ✅ | ❌ **MISSING** | ❌ MISSING | N/A | N/A | ❌ | ❌ | N/A | ❌ |

**CRITICAL FINDING:** dokploy-operator (Tier 1) deployed all 9 compose projects but NEVER dispatched to dokploy-compose-manager (Tier 2). Therefore:
- §3 install contract was NOT executed for any watchman compose
- §3.5 post-deploy hook was NOT executed for any watchman compose
- T3 operators (observability, traefik, homer, fleet-control) were NEVER notified

---

## §3 Service Install Contract — Step by Step

### Step 1: Create Compose Record
**Status: ✅ Complete**

| Compose | composeId | composePath | Status |
|---------|-----------|-------------|--------|
| watchman-backend | gyw3FCYm_ZUpS8tQ_1Lzb | compose/watchman-backend.yml | done |
| watchman-grafana | J3V8Gna1dh6R2e4wj7JSL | compose/watchman-grafana.yml | done |
| watchman-edge-fnet1 | 1xwosCvxiksNer4vUpjaq | compose/watchman-edge.yml | **error** |
| watchman-edge-fnet2 | jrmhha3GhWs7ir5RyWkiQ | compose/watchman-edge.yml | done |
| watchman-edge-fnet3 | cvxPy8aiYv_Qwu7F-Q1pU | compose/watchman-edge.yml | done |
| watchman-edge-fnet4 | fv36g52HcyDhAiZw6xLKp | compose/watchman-edge.yml | done |
| watchman-edge-fnet5 | 3s3lbSM-NPV6dCMcuQT53 | compose/watchman-edge.yml | done |
| watchman-edge-fnet6 | Gr96Fv5CKVf8EH9NZ_1ew | compose/watchman-edge.yml | done |
| watchman-edge-fnet7 | fbFAAtDrj8RXgmvQCmoj_ | compose/watchman-edge.yml | done |

### Step 2: Environment Variables
**Status: ⚠️ Unknown — need verification**

No verification done against §3 Step 2 requirements.

### Step 3: Register Domain
**Status: ⚠️ Partial**

| Compose | Required Domain | Status |
|---------|----------------|--------|
| watchman-backend | watchman-api.svc.friasc.com | ✅ Created |
| watchman-grafana | watchman.svc.friasc.com | ✅ Created |
| watchman-edge-fnet* | None documented | ✅ N/A |

### Step 4: Create Compose Backup
**Status: ⚠️ Partial**

| Compose | Backup | Status |
|---------|--------|--------|
| watchman-backend | volumeBackups | ✅ Created (vmdata + osdata) |
| watchman-grafana | volumeBackups | ✅ Created (grafana-data) |
| watchman-edge-fnet* | N/A (stateless) | ✅ N/A |

### Step 5: Volume Backup or Server Job
**Status: ⚠️ Partial**

Dokploy volumeBackups created. **Missing:** Ansible playbook for volume backup verification (per SOT backup-schedule).

### Step 6: Register Health Check
**Status: ❌ Missing**

No health checks registered for any watchman compose.

### Step 7: Verify and Graduate
**Status: ❌ Incomplete**

- No SOT update (watchman entries missing in services_sot for backend/edge)
- No ChromaDB record

---

## §3.5 Post-Deploy Observability Hook

### O1: Register Prometheus scrape target (blackbox)
**Status: ❌ Missing**

Required files:
- `config/observability/prometheus/scrape-targets/watchman-backend.yml`
- `config/observability/prometheus/scrape-targets/watchman-grafana.yml`
- `config/observability/prometheus/scrape-targets/watchman-edge.yml`

⚠️ **Also:** Add to Ansible template at `fleet_control_observability/.../prometheus.yml.j2`

### O2: Add Alertmanager rules
**Status: ❌ Missing**

Required files:
- `config/observability/alertmanager/rules/watchman-backend.yml`
- `config/observability/alertmanager/rules/watchman-grafana.yml`
- `config/observability/alertmanager/rules/watchman-edge.yml`

### O3: Provision Grafana dashboard
**Status: ⚠️ Partial**

Grafana provisioning files exist:
- `provisioning/grafana/watchman-dashboards.yaml`
- `provisioning/grafana/watchman-datasources.yaml`

**Need verification:** Are these deployed to the watchman Grafana instance? This is a **separate** Grafana instance (watchman.svc.friasc.com), not the main observability Grafana.

### O4: Register Healthchecks.io ping
**Status: ❌ Missing**

Required: POST to `https://healthchecks.svc.friasc.com/api/v1/checks/` for:
- watchman-backend
- watchman-grafana
- watchman-edge-* (per node)

### O5: Configure Promtail pipeline
**Status: ❌ Missing**

Required files:
- `config/observability/promtail/config.d/watchman-backend.yml`
- `config/observability/promtail/config.d/watchman-grafana.yml`
- `config/observability/promtail/config.d/watchman-edge.yml`

### O6: Git commit and push
**Status: ❌ Not done**

### O7: Notify fleet-control-operator
**Status: ❌ Not done**

---

## Homer Dashboard

### SOT Entry
**Status: ✅ Complete**

Entry exists in `services_sot/defaults/main.yml`:
```yaml
- name: "watchman-grafana"
  host: "watchman.svc.friasc.com"
  sso: "oidc"
  notes: "grafana dashboard + alerting for watchman-stack"
  homer:
    category: "infrastructure & monitoring"
    display_name: "watchman"
    subtitle: "grafana + victoria metrics + opensearch"
```

### Homer Config Regeneration
**Status: ❌ Not verified**

Need to run `generate-homer-config.yml` to regenerate config.yml.

---

## Failed Deployment: watchman-edge-fnet1

### Deployment Log Analysis
**Latest error:** "Rebuild deployment" — status: error
**Log path:** `/etc/dokploy/logs/compose-bypass-online-application-ic1wh9/compose-bypass-online-application-ic1wh9-2026-10-15:19:06:06.log`

**Issue:** No `errorMessage` in deployment record, but status is `error`. Container still not running.

### Root Cause: Network Configuration
The compose went through multiple network fixes:
1. `d2c8951` — removed conflicting networks block (done)
2. `b33ea99` — scribe network_mode host -> watchman-backend-net (done)
3. `df0d4db` — scribe uses bridge -> OpenSearch via 'watchman-logs' hostname (done)

**But the latest deployments are "Rebuild deployment" with no error message — likely Docker cannot pull images or network issue persists.**

---

## Remediation Plan

### Step R1: Dispatch from dokploy-operator → dokploy-compose-manager

**For each watchman compose, dokploy-operator MUST dispatch to dokploy-compose-manager:**

```
Load: dokploy-compose-manager skill
Task: Complete §3 install contract + §3.5 post-deploy hooks for:
  - watchman-backend (composeId: gyw3FCYm_ZUpS8tQ_1Lzb)
  - watchman-grafana (composeId: J3V8Gna1dh6R2e4wj7JSL)
  - watchman-edge-fnet1 through fnet7 (composeId: 1xwosCvxiksNer4vUpjaq, jrmhha3GhWs7ir5RyWkiQ, cvxPy8aiYv_Qwu7F-Q1pU, fv36g52HcyDhAiZw6xLKp, 3s3lbSM-NPV6dCMcuQT53, Gr96Fv5CKVf8EH9NZ_1ew, fbFAAtDrj8RXgmvQCmoj_)
```

### Step R2: dokploy-compose-manager executes §3 install contract

**Step 2:** Verify env vars for watchman-backend, watchman-grafana
**Step 6:** Create health checks via MCP
**Step 7:** Graduate to git + SOT + ChromaDB

### Step R3: dokploy-compose-manager dispatches to Tier 3 (mandatory fan-out)

**After Step 7 verification, dokploy-compose-manager MUST dispatch:**


```
# For watchman-backend:
subagent({ agent: "observability-operator", task: "O1-O5 post-deploy hooks for watchman-backend" })
subagent({ agent: "traefik-operator", task: "Domain routes for watchman-api.svc.friasc.com" })
subagent({ agent: "fleet-control-operator", task: "SOT update + verify playbook for watchman-backend" })

# For watchman-grafana:
subagent({ agent: "observability-operator", task: "O1-O5 post-deploy hooks for watchman-grafana" })
subagent({ agent: "traefik-operator", task: "Domain routes for watchman.svc.friasc.com" })
subagent({ agent: "homer-operator", task: "Verify Homer dashboard entry for watchman" })
subagent({ agent: "fleet-control-operator", task: "SOT update + verify playbook for watchman-grafana" })

# For watchman-edge-*:
subagent({ agent: "observability-operator", task: "O1-O5 post-deploy hooks for watchman-edge (7 nodes)" })
subagent({ agent: "fleet-control-operator", task: "SOT update + verify playbooks for watchman-edge (7 nodes)" })
```

### Step R4: Verify all dispatches complete

Each Tier 3 operator must report back:
- observability-operator: Prometheus targets added, Alertmanager rules created, Grafana dashboard provisioned, Healthchecks.io registered, Promtail pipeline configured
- traefik-operator: Routes created
- homer-operator: Dashboard entry verified
- fleet-control-operator: SOT updated, playbooks registered

---

## Open Items

| Item | Severity | Status | Owner |
|------|----------|--------|-------|
| fnet1 deployment failing | P0 | OPEN | dokploy-operator |
| Health checks not registered | P1 | OPEN | dokploy-compose-manager |
| Prometheus scrape targets missing | P1 | OPEN | observability-operator |
| Alertmanager rules missing | P1 | OPEN | observability-operator |
| Grafana provisioning not verified | P1 | OPEN | observability-operator |
| Healthchecks.io pings missing | P1 | OPEN | observability-operator |
| Promtail pipelines missing | P1 | OPEN | observability-operator |
| Env vars not verified | P1 | OPEN | dokploy-compose-manager |
| SOT incomplete | P2 | OPEN | dokploy-compose-manager |
| Homer config not regenerated | P2 | OPEN | homer-operator |
| A2A notify fleet-control-operator | P2 | OPEN | dokploy-compose-manager |

---

## Next Action

**Fix fnet1 deployment first** — dispatch to dokploy-operator to read deployment log and remediate.

