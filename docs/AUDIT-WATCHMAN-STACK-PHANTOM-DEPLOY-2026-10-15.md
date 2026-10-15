---
name: Watchman Stack Phantom Deployment Audit
type: audit-report
status: RESOLVED
version: "2.0.0"
date: 2026-10-16
---

# Watchman Stack — Phantom Deployment Audit (PAUSED)

## Status: RESOLVED at 2026-10-16

## Progress

### Completed
- [x] Orphaned backups deleted (MMkQe4gU, TRNawjKZ)
- [x] Domain fixed (serviceName: watchman-metrics, port: 8428)
- [x] watchman-logs running
- [x] watchman-metrics manually started with host network
- [x] Volume mounts created (watchman-vmdata, watchman-osdata)
- [x] Volume backups created (Pdi6fBTFW9H, jKfWyejpQio)
- [x] Backup schedules created (cron: 0 2 * * *, 0 3 * * *)
- [x] §4 deployment validation added to dokploy-compose-manager SKILL.md

### TDD Tests
- **13/13 PASSING**
- Test file: `fleet-mesh-dispatch/tests/test_dokploy_deployment_validation.py`

### Key Outputs
- `dokploy-compose-manager/SKILL.md §4`: Deployment validation gate documented
- `fleet-mesh-dispatch/tests/test_dokploy_deployment_validation.py`: 13 passing tests

### Root Cause Summary
**PHANTOM DEPLOYMENT:** Dokploy reports `composeStatus: done` but containers don't exist.
This is a silent failure mode that §4 now catches.
