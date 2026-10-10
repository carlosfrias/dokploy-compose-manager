# dokploy-compose-manager — Deep Context

> **How to read this file:** Dense procedural reference. AGENTS.md has the lean operational view. This file has details too voluminous for operational truth.

---

## §1 MCP Tools Reference

> **Canonical source:** `skills/dokploy-compose-manager/SKILL.md` — MCP table there is the authority. This section is historical.

| Tool | Use |
|------|-----|
| `compose-search` | Enumerate compose records |
| `compose-one` | Get single compose record |
| `compose-create` | Create compose record |
| `compose-update` | Update compose record |
| `compose-deploy` | Deploy from DB YAML |
| `compose-redeploy` | Force redeploy |
| `environmentVariable-create` | Register env var |
| `domain-create` | Register domain |
| `backup-create` | Create compose backup |
| `volumeBackups-create` | Create volume backup (stateless only) |
| `schedule-create` | Create schedule |
| `schedule-runManually` | Trigger immediate run |
| `health-create` | Register health check |

> ⚠️ **scheduleType Bug:** `schedule-create` with `scheduleType: "server"` returns HTTP 500 in Dokploy v0.30.8. Workaround: compose-type schedules.

---

## §2 Assess → Register → Verify Loop

### ASSESS

```bash
# Enumerate existing Dokploy records
mcp__dokploy compose-search({ offset: 0, limit: 50 })
mcp__dokploy schedule-list({ composeId: "<id>" })
mcp__dokploy backup-list({ composeId: "<id>" })
mcp__dokploy domain-list({ composeId: "<id>" })
mcp__dokploy environmentVariable-list({ composeId: "<id>" })
mcp__dokploy health-list({ composeId: "<id>" })
```

### REGISTER

Execute missing steps from the 7-step contract. Check before every create (idempotency).

### VERIFY

```bash
mcp__dokploy compose-one({ composeId: "<id>" })
# composeStatus should be "done" or containers healthy
```

### GRADUATE

```bash
# Push to git
git add config/<service>/ && git commit -m "deploy: <service>"
git push origin main

# Update SOT
# fleet-orchestration/fleet-control/playbook-index.json

# ChromaDB
memory_store_semantic({ text: "...", metadata: { type: "registration" }})
```

---

## §3 Dokploy Volume Backup Deficiency

`volumeBackups` is a black box with no hooks. **Correct approach for databases:** Direct SSH dump via Mac orchestrator.

| Service | Volume | Decision |
|---------|--------|---------|
| Authentik | `authentik-pg-data` | Direct dump |
| NextCloud | `nextcloud-data` | volumeBackups OK (static files) |
| NextCloud | `nextcloud_db` | Direct dump |
| Grafana | `grafana_data` | volumeBackups OK |
| Loki | `loki_data` | volumeBackups OK |
| SurrealDB | bind mount | Direct tar |
| Semaphore | `semaphore-mysql` | Direct dump |
| Windmill | `windmill_db_data` | Direct dump |

---

## §4 Server Job Mechanism

> ⚠️ **Updated:** Phase 3 revealed fnet2 cannot SSH to other hosts. The backup-runner container approach failed. Correct execution model: **Mac orchestrator via fleet-control inventory SSH**.

**Dokploy scheduleType Bug:** `scheduleType: "server"` returns HTTP 500 in v0.30.8.

---

## §5 Phase 3 Corrected Execution Model

**Problem:** fnet2 cannot SSH to fnet1/fnet3/fnet5/fnet7. backup-runner containers on fnet2 are network-isolated.

**Solution:** Mac orchestrator executes backups via fleet-control inventory SSH.

```
Mac (fleet-control/) ──SSH──► fnet1/fnet3/fnet5/fnet7
                         docker exec <container> pg_dump | gzip
                         fetch dump to Mac
                         rclone to Wasabi
```

**Prerequisites:**
1. Pass store synced to Mac: `pass insert -m <path> <<< "$(ssh fnet2 'pass <path>')"`
2. Fleet inventory reachable: `ansible fnet1,fnet3,fnet5,fnet7 -m ping`
3. rclone configured on Mac with `wasabi` remote

**All 7 services verified 2026-10-10:**

| Service | Host | Container | Size |
|---------|------|---------|------|
| authentik | fnet2 | `authentik-postgresql-1` | 11MB |
| windmill | fnet2 | `windmill-ztuswo-windmill_db-1` | 4.4MB |
| nextcloud | fnet1 | `nextcloud-ijgeuz-nextcloud-db-1` | 59MB |
| supabase | fnet3 | `supabase-db` | 68KB |
| expenseflow | fnet5 | `expenseflow-postgres-1` | 2.7KB |
| semaphore | fnet7 | `compose-...-mysql-1` | 6.5MB |
| open-notebook | fnet7 | bind mount | 12MB |

**Playbooks:** `dokploy-config/backup-jobs/playbooks/` — run via fleet-control inventory.

**SurrealDB exception:** Minimal image (no shell). Backed up via `tar -C /home/friasc/open-notebook surreal_data/` from host.

---

## §6 Graduation Protocol

Every ad-hoc fix must be graduated:

1. **Git push** to `carlosfrias/dokploy-config`
2. **SOT update** in `fleet-orchestration/fleet-control/playbook-index.json`
3. **ChromaDB** record
4. **Commit here** if new patterns discovered

**Phase 3 corrections that required graduation:**
- Container names corrected (Dokploy random prefixes)
- Pass paths updated (correct DB users and hosts)
- Execution model changed (Mac orchestrator, not backup-runner SSH)
- Semaphore MySQL uses `semaphore` user not `root`
- SurrealDB backed up via bind mount tar (minimal image)

---

## §7 Idempotency Rules

1. Every create MUST be preceded by a search/list. Check before you create.
2. `composePath` must match `<service>/docker-compose.yml`.
3. Duplicate domain: skip and log.
4. Duplicate backup: skip and log.
5. Duplicate schedule: skip and log.
6. Duplicate env var: skip and log.
7. Always log skips with timestamp and reason.

---

## §8 Phase 2 Work (Historical)

| Item | Status |
|------|--------|
| backup-runner Dockerfile | ✅ Built (Alpine v10) |
| entrypoint.sh | ✅ BQ-1/BQ-2 compliant |
| Per-service backup playbooks | ✅ All 7 created |
| Server job mechanism | ✅ Documented (Dokploy bug workaround) |
| Private registry | ✅ Deployed |
| open-notebook fragment | ✅ Verified |
