# dokploy-compose-manager — Deep Context

> **How to read this file:** This is a reference document, not a protocol. Read sections on demand. AGENTS.md has the lean operational view. This file has the dense procedural content.

---

## §1 MCP Tools Reference

### Compose

| Tool | Use | Notes |
|------|-----|-------|
| `compose-search({ offset?, limit? })` | Enumerate all compose records | Default 20/page |
| `compose-one({ composeId })` | Get single compose record | Check `composeStatus`, `composePath` |
| `compose-getConvertedCompose({ composeId })` | Get stored YAML | May return NULL (known bug) |
| `compose-create({ name, composePath, customGitSSHKeyId, customGitUrl, customGitBranch, serverId, autoDeploy, sourceType })` | Create compose record | Idempotent: check first |
| `compose-update({ composeId, composePath?, composeFile? })` | Update compose record | `composeFile` does not persist |
| `compose-deploy({ composeId })` | Deploy from DB YAML | Use after `compose-update` |
| `compose-redeploy({ composeId })` | Force redeploy | ⚠ Resets `composePath` — fix after |

### Environment Variables

| Tool | Use |
|------|-----|
| `environmentVariable-list({ composeId })` | List vars for compose |
| `environmentVariable-create({ name, value, composeId, isRequired })` | Add var |

### Domain

| Tool | Use |
|------|-----|
| `domain-list({ composeId })` | List domains for compose |
| `domain-create({ forceSsl, domain, path, composeId })` | Register domain |
| `domain-delete({ domainId })` | Remove domain |

### Backup

| Tool | Use | Notes |
|------|-----|-------|
| `backup-list({ composeId })` | List compose backups | |
| `backup-create({ destinationId, composeId, cronjob })` | Create compose backup | Idempotent: check first |
| `volumeBackups-create({ destinationId, composeId, volumeName, cronjob, enabled })` | Create volume backup | Stateless only |
| `volumeBackups-delete({ volumeBackupId })` | Remove volume backup | |

### Schedule

| Tool | Use | Notes |
|------|-----|-------|
| `schedule-list({ composeId })` | List schedules for compose | |
| `schedule-one({ scheduleId })` | Get single schedule | |
| `schedule-create({ name, cronExpression, scheduleType, command, serverId })` | Create schedule | `scheduleType: "server"` for backups |
| `schedule-update({ scheduleId, ... })` | Update schedule | |
| `schedule-delete({ scheduleId })` | Remove schedule | |
| `schedule-runManually({ scheduleId })` | Trigger immediate run | For testing |

### Health

| Tool | Use |
|------|-----|
| `health-list({ composeId })` | List health checks |
| `health-create({ composeId, monitorId, name, path, domain, enabled })` | Register health check |
| `health-delete({ healthId })` | Remove health check |

---

## §2 Assess → Register → Verify Loop

### ASSESS Phase

```bash
# 1. Load canonical service effort context (if provided)
# Read compose config from git:
cat $CWD/config/<service>/docker-compose.yml

# 2. Enumerate existing Dokploy records
mcp__dokploy compose-search({ offset: 0, limit: 50 })
# Find composeId for this service

mcp__dokploy schedule-list({ composeId: "<composeId>" })
mcp__dokploy backup-list({ composeId: "<composeId>" })
mcp__dokploy domain-list({ composeId: "<composeId>" })
mcp__dokploy environmentVariable-list({ composeId: "<composeId>" })
mcp__dokploy health-list({ composeId: "<composeId>" })

# 3. Determine what is missing vs 7-step contract
# Log each finding:
#   ✓ Step 1: compose record exists
#   ✗ Step 2: env var PG_PASS missing
#   ✓ Step 3: domain nextcloud.svc.friasc.com exists
#   ✗ Step 5: server job missing (database volume)
```

### REGISTER Phase

Execute only the missing steps from the 7-step contract.

For each step:
1. Check if record already exists (idempotency)
2. Create the record via MCP
3. Log the creation with timestamp and record ID
4. Continue to next step

### VERIFY Phase

```bash
# After all registrations complete:
mcp__dokploy compose-one({ composeId: "<composeId>" })
# Check: composeStatus should be "done" or containers should be healthy

mcp__dokploy domain-list({ composeId: "<composeId>" })
# Count: should match expected domain count

mcp__dokploy backup-list({ composeId: "<composeId>" })
# Check: compose backup row present

mcp__dokploy schedule-list({ composeId: "<composeId>" })
# Check: server job present (if stateful)

# Test the server job manually:
mcp__dokploy schedule-runManually({ scheduleId: "<scheduleId>" })
# Wait for execution → check logs for success/failure
```

### GRADUATE Phase

```bash
# Push compose to git
cd $CWD
git add config/<service>/
git commit -m "deploy: <service> complete registration"
git push origin main

# Update SOT
# Edit: fleet-orchestration/fleet-control/config/playbook-index.json
# Add: { service, composeId, serverId, volumes, backup-schedule, health-check-url }

# Store in ChromaDB
memory_store({
  collection: "infrastructure",
  text: "Service <service> registered on Dokploy at <ISO8601>. composeId: <id>. Backup: <schedule-id>. Health: <health-id>",
  metadata: { service: "<service>", composeId: "<id>", tier: 2, type: "registration" }
})

# Commit to this repo if new patterns were discovered
```

---

## §3 Dokploy Volume Backup Deficiency (Detail)

Dokploy `volumeBackups` is a black box:

```typescript
// What volumeBackups actually does (from source):
backupCommand = `docker run --rm \
  -v ${volumeName}:/volume_data \
  -v ${volumeBackupPath}:/backup \
  ubuntu \
  bash -c "cd /volume_data && tar cvf /backup/${backupFileName} ."`

uploadCommand = `rclone copyto ${rcloneFlags} \
  "${volumeBackupPath}/${backupFileName}" \
  ":s3:${destination.bucket}/${bucketDestination}"`
```

**What it cannot do:**
- No pre-backup hooks (cannot run `pg_dump` before tar)
- No post-backup scripts (cannot verify checksum, run retention policy)
- No custom tar flags (cannot exclude temp files)
- No database consistency mode (tar while DB writes = corrupted backup)
- No incremental backup (always full tar)

**The risk:** Backing up a PostgreSQL volume with `tar` while the database is writing produces an inconsistent snapshot. At restore time, the DB may refuse to start or may silently corrupt data.

**Correct approach for databases:** Server job running `pg_dump` / `mysqldump` with:
1. `ALTER DATABASE db SET READ ONLY` (or equivalent)
2. `pg_dump --format=custom`
3. Upload to S3
4. `ALTER DATABASE db SET READ WRITE`
5. Healthcheck ping

This is what the Phase 2 `backup-runner` image will do.

**`volumeBackups` is only acceptable for:**
- Truly static named volumes (Grafana dashboards, Loki segments, Homer config)
- Non-database volumes where tar inconsistency is acceptable

### Decision Examples

| Service | Volume | Decision |
|---------|--------|---------|
| Authentik | `authentik-pg-data` (PostgreSQL) | Server job |
| NextCloud | `nextcloud-data` (files) | volumeBackups |
| NextCloud | `nextcloud_db` (MariaDB) | Server job |
| Grafana | `grafana_data` (dashboards) | volumeBackups |
| Loki | `loki_data` (log segments) | volumeBackups |
| SurrealDB | `surrealdb` (notebooks) | Server job |
| Semaphore | `semaphore-mysql` (MySQL) | Server job |
| Windmill | `windmill_db_data` (PostgreSQL) | Server job |

---

## §4 Server Job Mechanism (Detail)

Dokploy schedules run on the Dokploy server itself via SSH:

```yaml
scheduleType: "server"
serverId: "fRlHDuz4klcgQ05yX-y8J"  # fnet2 Dokploy
cronExpression: "0 3 * * *"
command: |
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ~/.ssh:/root/.ssh:ro \
    ghcr.io/carlosfrias/backup-runner:latest \
    /entrypoint.sh backup-authentik
```

**Execution flow:**
1. Dokploy reads the schedule cron expression
2. At the scheduled time, Dokploy SSHs to `serverId`
3. Dokploy runs `bash -c ./script.sh` where `script.sh` is stored at `/etc/dokploy/schedules/<appName>/script.sh`
4. The `script.sh` contains the `docker run` command
5. The Docker container starts, executes the entrypoint
6. Logs stream back to Dokploy and appear in the schedule execution log

**The container (backup-runner):**
- Runs inside the Dokploy container's Docker socket context
- Has access to host Docker API via `/var/run/docker.sock`
- Has SSH keys mounted read-only via `~/.ssh`
- Can reach all fleet nodes via SSH
- Ansible runs inside the container — **no Ansible on hosts**

---

## §5 7-Step Detailed Commands

### Step 1 — Create Compose Record

```bash
# Enumerate existing compose records first (idempotency check)
mcp__dokploy compose-search({ offset: 0, limit: 50 })
# Find record where name = "<service-name>"
# If found → skip, log "compose record already exists"

# Create if missing:
mcp__dokploy compose-create({
  name: "<service-name>",
  composePath: "<service>/docker-compose.yml",
  customGitSSHKeyId: "R7VQAMIqCoLqs2E3rr1ff",
  customGitUrl: "git@github.com:carlosfrias/dokploy-config.git",
  customGitBranch: "main",
  serverId: "<serverId>",
  autoDeploy: true,
  sourceType: "git"
})
```

**composePath convention (CRITICAL):**
- Format: `<service>/docker-compose.yml`
- Examples: `nextcloud/docker-compose.yml`, `authentik/docker-compose.yml`
- **Never:** `./nextcloud/`, `config/nextcloud/`, bare `docker-compose.yml`
- Dokploy resolves paths relative to the git clone root

### Step 2 — Set Environment Variables

```bash
# List existing env vars for this compose
mcp__dokploy environmentVariable-list({ composeId: "<composeId>" })
# Identify which required vars are missing

# Create each missing var:
mcp__dokploy environmentVariable-create({
  name: "<VAR_NAME>",
  value: "$(pass services/<path>)",
  composeId: "<composeId>",
  isRequired: true
})
```

- Use `pass show <path>` to retrieve secrets — never hardcode values
- Common vars: `POSTGRES_PASSWORD`, `AUTHENTIK_SECRET_KEY`, `NEXTCLOUD_ADMIN_PASSWORD`
- Group related vars (DB creds, API keys, S3 config)

### Step 3 — Register Domain

```bash
# List existing domains for this compose
mcp__dokploy domain-list({ composeId: "<composeId>" })
# Identify which domains are missing

# Create each missing domain:
mcp__dokploy domain-create({
  forceSsl: true,
  domain: "<fqdn>",
  path: "/",
  composeId: "<composeId>"
})
```

- `forceSsl: true` always for production
- Common domains: `<service>.svc.friasc.com`, `<user>.<service>.svc.friasc.com`
- Register base domain before subdomains

### Step 4 — Create Compose Backup

```bash
# List existing backups for this compose
mcp__dokploy backup-list({ composeId: "<composeId>" })
# If none → create:

mcp__dokploy backup-create({
  destinationId: "wasabi-s3-east-2",
  composeId: "<composeId>",
  cronjob: {
    enabled: true,
    scheduled: "0 3 * * *"
  }
})
```

- `destinationId` must be a registered S3 destination in Dokploy
- Schedule `0 3 * * *` = daily at 03:00 UTC
- Covers container filesystem (not named volumes)

### Step 5 — Create Volume Backup or Server Job

**Use the backup decision tree (§4).**

For stateless services with named volumes:
```bash
mcp__dokploy volumeBackups-create({
  destinationId: "wasabi-s3-east-2",
  composeId: "<composeId>",
  volumeName: "<volume-name>",
  cronjob: {
    enabled: true,
    scheduled: "0 4 * * *"
  },
  enabled: true
})
```

For stateful services (databases):
```bash
# ⚠ Phase 2: backup-runner image not yet built
# Stub the command until Phase 2 completes
mcp__dokploy schedule-create({
  name: "Daily <service> Backup",
  cronExpression: "0 3 * * *",
  scheduleType: "server",
  serverId: "<serverId>",
  command: "docker run --rm \\\n  -v /var/run/docker.sock:/var/run/docker.sock \\\n  ghcr.io/carlosfrias/backup-runner:latest \\\n  /entrypoint.sh backup-<service>"
})
```

### Step 6 — Register Health Check

```bash
mcp__dokploy health-create({
  composeId: "<composeId>",
  monitorId: "uptime-kuma-01",
  name: "<service> Health",
  path: "/",
  domain: "<fqdn>",
  enabled: true
})
```

- `monitorId` must be a registered Uptime Kuma instance
- `domain` is the FQDN without protocol
- Use the same FQDN registered in Step 3

### Step 7 — Verify and Graduate

```bash
# Verify all records
mcp__dokploy compose-one({ composeId: "<composeId>" })
  # → composeStatus should be "done" or "running"
mcp__dokploy domain-list({ composeId: "<composeId>" })
  # → should list all registered domains
mcp__dokploy backup-list({ composeId: "<composeId>" })
  # → should list compose backup
mcp__dokploy schedule-list({ composeId: "<composeId>" })
  # → should list server job (if stateful)
mcp__dokploy health-list({ composeId: "<composeId>" })
  # → should list health check

# Graduate to git
cd $CWD
git add config/<service>/docker-compose.yml config/<service>/.env.example
git commit -m "deploy: <service> initial registration"
git push origin main

# Update SOT
# Add entry to fleet-orchestration/fleet-control/config/playbook-index.json
# Fields: service, composeId, serverId, volumes, backup-schedule, health-check

# Store in ChromaDB
# Record: service registered, date, composeId, all backup/schedule IDs
```

---

## §6 Phase 2 Work

### Phase 2 Open Items

| Item | Owner | Blocker | Priority |
|------|-------|---------|---------|
| `ghcr.io/carlosfrias/backup-runner` Dockerfile | compose-manager | None | 🔴 High |
| `backup-runner` entrypoint.sh | compose-manager | Dockerfile | 🔴 High |
| Per-service backup playbooks (Authentik, NextCloud, Semaphore, etc.) | compose-manager | Image | 🟡 Medium |
| `rclone` credential injection (Wasabi S3) | compose-manager | None | 🟡 Medium |
| Backup verification playbooks | compose-manager | Playbook library | 🟡 Medium |

### Dockerfile Requirements (DCQ gates)

```dockerfile
FROM ubuntu:24.04

# Pin image tags — no :latest in production
# Add healthcheck
# No hardcoded secrets — inject via env or mount
```

### entrypoint.sh Requirements (BQ gates)

```bash
#!/bin/bash
set -euo pipefail
trap 'EXIT=$?; echo "Exit code: $EXIT" >&2' EXIT
```

### Quality Gates for Phase 2

| Gate | Applies To | Standard |
|------|-----------|---------|
| BQ-1 | `entrypoint.sh` | `set -euo pipefail` |
| BQ-2 | `entrypoint.sh` | `trap EXIT` |
| DCQ-1 | `Dockerfile` | No `:latest` |
| DCQ-2 | `Dockerfile` | Healthcheck present |
| DCQ-3 | `Dockerfile` | No hardcoded secrets |
| AQ-1 | Playbook library | `ansible-lint` pass |

---

## §7 Idempotency Rules

1. **Every create MUST be preceded by a search/list.** Check before you create.
2. **composePath enforcement:** Every compose record must have `composePath` matching `<service>/docker-compose.yml`. If wrong, fix via `compose-update`.
3. **Duplicate domain:** Skip and log: `[idempotency] domain <fqdn> already exists — skipping`
4. **Duplicate backup:** Skip and log: `[idempotency] backup row already exists for compose <id> — skipping`
5. **Duplicate schedule:** Skip and log: `[idempotency] schedule <name> already exists — skipping`
6. **Duplicate env var:** Skip and log: `[idempotency] env var <name> already set — skipping`
7. **Always log skips** with timestamp, operation attempted, and reason.

---

## §8 Graduation Protocol

Every ad-hoc fix must be graduated:

1. **Git push:** Push the fix to `carlosfrias/dokploy-config`
2. **SOT update:** Update `fleet-orchestration/fleet-control/config/playbook-index.json` if the change affects topology, volumes, or backup schedules
3. **ChromaDB:** Store the durable fact: what was fixed, when, by whom, root cause
4. **Commit to compose-manager repo:** If the fix reveals a new pattern or gap in the install contract, update SKILL.md and commit here

**Graduation is non-negotiable.** A fix that stays in memory is a future incident waiting to happen.
