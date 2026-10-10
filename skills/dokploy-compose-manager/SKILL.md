---
name: dokploy-compose-manager
description: |
  Dokploy Compose Manager — Tier 2 operator owning the complete per-service installation contract.
  Registers: compose record, env vars, domain, compose backup, volume backup (stateless),
  server job (stateful), health check. Uses Dokploy MCP exclusively.
  Dispatches Tier 3 to service operators.
metadata:
  version: "0.1.0"
  author: "Carlos Frias"
  phase: 1
---

# dokploy-compose-manager — Operator Skill

**Size:** single-file skill (~15KB). **Phase 1 scaffold.** Load when you need to register a new service on Dokploy or audit an existing service's installation completeness.

---

## §1 Identity

**Tier 2 only.** Owns the complete per-service installation contract. Does NOT own container lifecycle (Tier 1 → `dokploy-operator`) or service configuration (Tier 3 → canonical service effort).

**Owns:**
- Compose record creation and `composePath` convention enforcement
- Environment variable registration
- Domain registration
- Dokploy compose backup registration
- Dokploy volume backup registration (stateless services)
- Dokploy server job registration (stateful services)
- Health check registration
- SOT update after registration

**Does NOT own:**
- `compose-redeploy`, `compose-update`, container restart
- Service configuration files (docker-compose.yml, .env templates)
- Fleet-wide scheduling (Semaphore owns this)
- Backup-runner Docker image (Phase 2)

---

## §2 Three-Tier Model

```
Tier 3: Canonical service effort
  Owns: service definition, docker-compose.yml content, environment variables (values)
  Route TO: when service config needs changes

Tier 2: dokploy-compose-manager
  Owns: registration of the service into the Dokploy platform
  Route TO: dokploy-operator for container lifecycle

Tier 1: dokploy-operator
  Owns: container lifecycle, Traefik routing, forward-auth, Docker Swarm
  Route FROM: compose-manager for Tier 1 issues

Routing: canonical effort → compose-manager → dokploy-operator
```

---

## §3 Service Install Contract (7 Steps)

Every new service on Dokploy requires all 7 steps. Skipping steps leaves the service partially managed — incomplete backup coverage, missing health checks, no domain registration.

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

## §4 Backup Decision Tree

```
Is the volume a database?
│
├── YES → Server Job (schedule-create, scheduleType: "server")
│         Command: docker run ghcr.io/carlosfrias/backup-runner:latest
│                   /entrypoint.sh backup-<service>
│         Phase 2: backup-runner image not yet built
│
└── NO
    │
    ├── Is the data rebuildable? (logs, cache, temp files)
    │   ├── YES → Skip backup
    │   │         Document in SOT: "<volume> skipped — rebuildable"
    │   │
    │   └── NO
    │       │
    │       ├── Is it a Docker named volume?
    │       │   ├── YES → volumeBackups-create (Dokploy native tar+S3)
    │       │   │
    │       │   └── NO → Bind mount
    │       │             Document in SOT: "<mount> non-backuppable — bind mount"
    │       │
    │       └── Is the data critical?
    │           └── YES → Consider rclone-based backup via Ansible (Phase 2)
```

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
| windmill | `windmill_db_data` (PostgreSQL) | Server job |

---

## §5 Dokploy Volume Backup Deficiency

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

---

## §6 Server Job Mechanism

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

**⚠ Phase 2 TODO:** Build and push `ghcr.io/carlosfrias/backup-runner:latest` to GHCR. Until then, server jobs are stubbed. All Phase 1 registrations use `volumeBackups` for stateless services only.

---

## §7 MCP Tools Reference

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

## §8 Trigger Conditions

- **Canonical service effort requests new deployment:** The service effort sends a deployment request with compose config
- **dokploy-operator dispatches Tier 2 work:** Env vars missing, backup row missing, server job missing, domain missing, composePath drift
- **fleet-dispatcher routes Tier 2 work:** After determining a service needs registration
- **Manual dispatch:** Owner or other agent calls this operator directly
- **Trigger keywords:** "deploy <service>", "register <service>", "compose-manager install", "setup <service> on Dokploy"

---

## §9 Assess → Register → Verify Loop

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
# (e.g., new backup strategy, new volume type)
```

---

## §10 Idempotency Rules

1. **Every create MUST be preceded by a search/list.** Check before you create.
2. **composePath enforcement:** Every compose record must have `composePath` matching `<service>/docker-compose.yml`. If wrong, fix via `compose-update`.
3. **Duplicate domain:** Skip and log: `[idempotency] domain <fqdn> already exists — skipping`
4. **Duplicate backup:** Skip and log: `[idempotency] backup row already exists for compose <id> — skipping`
5. **Duplicate schedule:** Skip and log: `[idempotency] schedule <name> already exists — skipping`
6. **Duplicate env var:** Skip and log: `[idempotency] env var <name> already set — skipping`
7. **Always log skips** with timestamp, operation attempted, and reason.

---

## §11 Graduation Protocol

Every ad-hoc fix must be graduated:

1. **Git push:** Push the fix to `carlosfrias/dokploy-config`
2. **SOT update:** Update `fleet-orchestration/fleet-control/config/playbook-index.json` if the change affects topology, volumes, or backup schedules
3. **ChromaDB:** Store the durable fact: what was fixed, when, by whom, root cause
4. **Commit to compose-manager repo:** If the fix reveals a new pattern or gap in the install contract, update SKILL.md and commit here

**Graduation is non-negotiable.** A fix that stays in memory is a future incident waiting to happen.

---

## §12 Anti-Drift Rules

- **DO-1:** Run ASSESS before any REGISTER. No exceptions.
- **DO-2:** Use MCP exclusively for all Dokploy operations. SSH only as last resort (IR-12).
- **DO-3:** Graduate every fix to git + SOT + ChromaDB. No exceptions.
- **DO-4:** Never touch Tier 1 (container lifecycle) or Tier 3 (service configs) directly.
- **DO-5:** Write to FRM ledger for every action.
- **DO-6:** Commit and push after every registration.
- **DO-7:** Escalate data loss risk to human immediately.

---

## §13 Authority Matrix

### Autonomous (no approval needed)

- Create compose records (after canonical effort authorization)
- Register backups (compose, volume, server job)
- Register domains, environment variables, health checks
- Verify registrations
- Graduate fixes to git + SOT + ChromaDB
- Push compose to dokploy-config git

### Requires Human Approval

- New service approval (canonical effort must authorize first)
- Service deletion
- SOT structural changes (new fields, schema changes)
- Swarm or network topology changes
- Disaster recovery runbooks

---

## Phase 2 Work (Not Yet Started)

| Item | Owner | Status |
|------|-------|--------|
| `ghcr.io/carlosfrias/backup-runner` Dockerfile | compose-manager | TODO |
| Ansible playbook library | compose-manager | TODO |
| `rclone` credential injection (Wasabi S3) | compose-manager | TODO |
| Per-service backup playbooks (Authentik, NextCloud, Semaphore, etc.) | compose-manager | TODO |
| Backup verification playbooks | compose-manager | TODO |

---

*Version 0.1.0 · Phase 1 scaffold — SKILL.md v1*
