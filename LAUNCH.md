# compose-manager — Phase 3 Launch Prompt

> **Resume Phase 2 → Phase 3.** Phase 2 automated infrastructure scaffold is complete. Phase 3 is execution: register the registry in Dokploy, implement the backup-job workaround, and test everything against live services.

**CWD:** `/Users/friasc/Cloud/carlos-desktop/Efforts/Infrastructure/dokploy/compose-manager/`
**Owner:** compose-manager Tier 2 operator
**Phase:** 3 (Phase 2: ✅ complete)

---

## Context

### What Phase 2 built

| Deliverable | Status | Location |
|-------------|--------|----------|
| backup-runner image | ✅ Built & pushed | `registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0` |
| backup-runner entrypoint.sh | ✅ BQ-1/BQ-2 compliant | `backup-runner/entrypoint.sh` |
| Per-service backup playbooks (7) | ✅ Created | `playbooks/backup/backup-*.yml` |
| Server job workaround | ✅ Documented | `output/server-job-migration.md` |
| Private registry compose | ✅ Created | `config/registry/docker-compose.yml` |
| open-notebook fragment | ✅ PASS | `output/notebook-fragment-verify.md` |
| AGENTS.md Phase 2 status | ✅ Updated | `AGENTS.md` §7 |

### Critical blocker from Phase 2

**Dokploy `scheduleType: "server"` returns HTTP 500** (v0.30.8). The recommended workaround is **compose-type schedules with dedicated backup containers**:

```yaml
# config/backup-jobs/docker-compose.yml pattern
services:
  authentik-backup:
    image: registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0
    container_name: authentik-backup
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.ssh:/root/.ssh:ro
    restart: unless-stopped
    command: ["sleep", "infinity"]
  # ... repeat for all 7 services
```

Schedules exec into these containers:
```json
{
  "name": "Daily Authentik DB Backup",
  "cronExpression": "0 3 * * *",
  "scheduleType": "compose",
  "command": "docker exec authentik-backup /entrypoint.sh backup-authentik",
  "composeId": "<backup-jobs-composeId>"
}
```

---

## Phase 3 Checklist

Execute in order. Each step is atomic — commit after completing each section.

### §1 — Register private registry in Dokploy

```bash
# 1. Push config/registry/ to git
cd config/registry/
git add docker-compose.yml .env.example
git commit -m "deploy: add registry compose"
git push origin main

# 2. Create compose record in Dokploy
# Check first: mcp__dokploy compose-search({ name: "registry" })
mcp__dokploy compose-create({
  name: "registry",
  composePath: "registry/docker-compose.yml",
  customGitSSHKeyId: "R7VQAMIqCoLqs2E3rr1ff",
  customGitUrl: "git@github.com:carlosfrias/dokploy-config.git",
  customGitBranch: "main",
  serverId: "fRlHDuz4klcgQ05yX-y8J",
  autoDeploy: false,
  sourceType: "git"
})
# → capture composeId

# 3. Register domain
mcp__dokploy domain-create({
  domain: "registry.svc.friasc.com",
  forceSsl: true,
  composeId: "<composeId>"
})

# 4. Create compose backup
mcp__dokploy backup-create({
  destinationId: "wasabi-s3-east-2",
  composeId: "<composeId>",
  cronjob: { enabled: true, scheduled: "0 3 * * *" }
})

# 5. Deploy
mcp__dokploy compose-deploy({ composeId: "<composeId>" })

# 6. Verify: curl https://registry.svc.friasc.com/v2/_catalog
```

### §2 — Create backup-jobs compose

Create `config/backup-jobs/docker-compose.yml` with one backup container per service:

| Service | Container | DB | Backup Cmd |
|---------|----------|----|-----------|
| authentik | `authentik-backup` | PostgreSQL | `/entrypoint.sh backup-authentik` |
| semaphore | `semaphore-backup` | MySQL | `/entrypoint.sh backup-semaphore` |
| windmill | `windmill-backup` | PostgreSQL | `/entrypoint.sh backup-windmill` |
| nextcloud | `nextcloud-backup` | MariaDB | `/entrypoint.sh backup-nextcloud` |
| supabase | `supabase-backup` | PostgreSQL | `/entrypoint.sh backup-supabase` |
| expenseflow | `expenseflow-backup` | PostgreSQL | `/entrypoint.sh backup-expenseflow` |
| open-notebook | `open-notebook-backup` | SurrealDB | `/entrypoint.sh backup-open-notebook` |

Each container:
```yaml
  authentik-backup:
    image: registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0
    container_name: authentik-backup
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.ssh:/root/.ssh:ro
    restart: unless-stopped
    command: ["sleep", "infinity"]
```

Push to git, then register in Dokploy (same MCP pattern as §1).

### §3 — Create compose-type backup schedules

For each service, create a `scheduleType: "compose"` schedule:

```bash
mcp__dokploy schedule-create({
  name: "Daily Authentik DB Backup",
  cronExpression: "0 3 * * *",
  scheduleType: "compose",
  command: "docker exec authentik-backup /entrypoint.sh backup-authentik",
  composeId: "<backup-jobs-composeId>"
})
```

Schedule order (avoid concurrent DB dumps):
```
0 3 * * *  authentik
15 3 * * *  windmill
30 3 * * *  nextcloud
45 3 * * *  semaphore
0 4 * * *  supabase
15 4 * * *  expenseflow
30 4 * * *  open-notebook
```

### §4 — Test backups against live databases

For each service, run the schedule manually and verify Wasabi:

```bash
# Find the scheduleId
mcp__dokploy schedule-list({ composeId: "<backup-jobs-composeId>" })

# Trigger manually
mcp__dokploy schedule-runManually({ scheduleId: "<scheduleId>" })

# Wait 60s, then check Wasabi
ssh fnet2 "rclone ls wasabi:friasc-backups/<service>/ --max-age 1h"
```

**Expected results:**

| Service | Wasabi Path | Verify |
|---------|------------|--------|
| authentik | `friasc-backups/authentik/` | `authentik-db-*.sql.gz` exists |
| semaphore | `friasc-backups/semaphore/` | `semaphore-db-*.sql.gz` exists |
| windmill | `friasc-backups/windmill/` | `windmill-db-*.sql.gz` exists |
| nextcloud | `friasc-backups/nextcloud/` | `nextcloud-db-*.sql.gz` exists |
| supabase | `friasc-backups/supabase/` | `supabase-db-*.sql.gz` exists |
| expenseflow | `friasc-backups/expenseflow/` | `expenseflow-db-*.sql.gz` exists |
| open-notebook | `friasc-backups/open-notebook/` | `open-notebook-db-*.json.gz` exists |

### §5 — Add Supabase password to pass

```bash
# First find the current password from the running container
ssh fnet3 "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT rolname FROM pg_authid WHERE rolinherit;'" 2>/dev/null || \
  mcp__dokploy dokploy_docker-exec... # or check compose logs

# Add to pass
pass insert -m infrastructure/presswork-pod/supabase/postgres-password
# Paste the password, save

# Verify
pass show infrastructure/presswork-pod/supabase/postgres-password
```

Then update `playbooks/backup/backup-supabase.yml` to use the correct path.

### §6 — Update SOT

After all registrations, update `fleet-orchestration/fleet-control/playbook-index.json`:

```json
"backup-jobs": {
  "composeId": "<backup-jobs-composeId>",
  "composeName": "backup-jobs",
  "composeBackupId": "<backup-compose-backup-id>",
  "schedules": [
    { "service": "authentik", "scheduleId": "...", "cron": "0 3 * * *" },
    { "service": "windmill", "scheduleId": "...", "cron": "15 3 * * *" },
    ...
  ]
}
```

### §7 — Commit and graduate

```bash
cd /Users/friasc/Cloud/carlos-desktop/Efforts/Infrastructure/dokploy/compose-manager/

# Commit all Phase 3 work
git add config/backup-jobs/ config/registry/
git commit -m "feat: Phase 3 complete — backup-jobs compose + registry registered

- config/registry/: registered in Dokploy (composeId, domain, backup)
- config/backup-jobs/: compose with 7 backup containers
- All 7 compose-type backup schedules created and tested
- Supabase password added to pass
- SOT updated with composeIds and scheduleIds

Phase 2: ✅ complete
Phase 3: ✅ complete"

git push origin main

# Store in ChromaDB
memory_store({
  collection: "infrastructure",
  text: "compose-manager Phase 3 complete at <ISO8601>. backup-jobs composeId: <id>. Registry composeId: <id>. All 7 backup schedules tested and uploading to Wasabi.",
  metadata: { effort: "compose-manager", phase: 3, tier: 2 }
})
```

---

## Key IDs and Paths

| Resource | ID/Path |
|----------|---------|
| fnet2 serverId | `fRlHDuz4klcgQ05yX-y8J` |
| fnet3 serverId | `pE5c_p7pL5-UXcuI4DSUm` |
| fnet7 serverId | `7865cebaee7549d4899c88` |
| backup-runner image | `registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0` |
| Git SSH key | `R7VQAMIqCoLqs2E3rr1ff` |
| Git URL | `git@github.com:carlosfrias/dokploy-config.git` |
| rclone remote | `wasabi` |
| Wasabi bucket | `friasc-backups` |
| Dokploy API key | `pass services/dokploy/fnet2/api-key` |
| backup-runner entrypoint | `/entrypoint.sh <service>` |
| Playbooks | `playbooks/backup/backup-{service}.yml` |

## Pass paths used by playbooks

| Service | Pass Path |
|---------|---------|
| authentik | `infrastructure/fleet/authentik/postgres-password` |
| semaphore | `infrastructure/fleet/semaphore/db-password` |
| windmill | `infrastructure/windmill/db-password` |
| nextcloud | `infrastructure/nextcloud/db-password` |
| supabase | `infrastructure/presswork-pod/supabase/postgres-password` ⚠️ add this |
| expenseflow | `infrastructure/fleet/expenseflow/db-password` |
| open-notebook | `root/root` (hardcoded, no pass) |

---

## Files to read on resume

| File | Why |
|------|-----|
| `AGENTS.md` | Phase 2 status, current open items |
| `AGENTS-DEEP.md §4` | Server job mechanism, backup decision tree |
| `output/server-job-migration.md` | HTTP 500 evidence, workaround design |
| `playbooks/backup/backup-*.yml` | All 7 playbooks |
| `config/registry/docker-compose.yml` | Registry compose (ready to deploy) |
| `fleet-orchestration/fleet-control/playbook-index.json` | SOT for updates |

---

## Phase 3 success criteria

- [ ] Registry compose deployed in Dokploy, `https://registry.svc.friasc.com/v2/_catalog` returns `{"repositories":[]}`
- [ ] backup-jobs compose deployed in Dokploy
- [ ] All 7 compose-type backup schedules created
- [ ] All 7 backups tested — files appear in `wasabi:friasc-backups/<service>/`
- [ ] Supabase password in pass at `infrastructure/presswork-pod/supabase/postgres-password`
- [ ] SOT updated with all composeIds, scheduleIds
- [ ] Commits pushed to `carlosfrias/dokploy-compose-manager`
- [ ] ChromaDB record stored

---

*Last updated: 2026-11-11 · Phase 2 complete · Phase 3 ready to execute*
