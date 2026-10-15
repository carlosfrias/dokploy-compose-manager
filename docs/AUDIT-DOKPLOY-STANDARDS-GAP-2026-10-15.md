---
name: Dokploy Standards Gap Audit
type: audit-report
status: RESOLVED
version: 1.1.0
date: 2026-10-15
resolved_date: 2026-10-15
---

# Dokploy Standards Gap Audit — Watchman Stack

## Executive Summary

**Status: ✅ RESOLVED**

| Issue | Status | Fix Applied |
|-------|--------|-------------|
| Container name conflicts | ✅ Fixed | Removed `container_name` from `watchman-edge.yml` |
| Domain registration | ✅ Fixed | Added domains via MCP (watchman-api.svc.friasc.com, watchman.svc.friasc.com) |
| Volume backup (watchman-backend) | ✅ Fixed | Created 2 volume backups (watchman-vmdata, watchman-osdata) |
| Volume backup (watchman-grafana) | ✅ Fixed | Created 1 volume backup (watchman-grafana-data) |
| watchman-edge-fnet1 redeploy | 🔄 In Progress | Redeploy queued after container_name fix |

---

## Standards Defined in dokploy-compose-manager

### Service Install Contract (7 Steps)

Every new service on Dokploy requires ALL 7 steps:

| Step | Action | Purpose |
|------|---------|---------|
| **Step 1** | Create Compose Record | Register service in Dokploy |
| **Step 2** | Set Environment Variables | Configure secrets via `pass` |
| **Step 3** | Register Domain | Add Traefik route |
| **Step 4** | Create Compose Backup | Backup container configs |
| **Step 5** | Create Volume Backup (stateless) | Backup persistent data |
| **Step 6** | Create Server Job (stateful) | Schedule backups |
| **Step 7** | Health Check Registration | Monitor service health |

---

## Container Name Conflict

### Error
```
Conflict. The container name "/watchman-collector" is already in use by container "0d9d7c934029..."
```

### Root Cause
The `watchman-edge.yml` compose file uses fixed container names. When multiple compose projects reference the same container name, Docker rejects deployment.

### Fix Required
Remove `container_name` from compose files.

---

## Remediation Plan

### Phase 1: Fix Container Names
1. Remove `container_name` from `watchman-edge.yml`
2. Push to GitHub
3. Redeploy all watchman-edge-* compose projects

### Phase 2: Run Service Install Contract
For each watchman compose, run Steps 3-7 of the contract.

---

## Open Items

| Item | Status | Owner |
|------|--------|-------|
| Container name conflict | OPEN | fleet-infra-author |
| Domain registration | OPEN | dokploy-compose-manager |
| Compose backup | OPEN | dokploy-compose-manager |
| Volume backup | OPEN | dokploy-compose-manager |
| Server jobs | OPEN | dokploy-compose-manager |
| Health checks | OPEN | observability-operator |

---

*Generated: 2026-10-15*
