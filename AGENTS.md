---
repo: carlosfrias/dokploy-compose-manager
submodule: true
type: operator
tier: 2
status: validated
validated_at: 2026-11-12
version: "2.2.0"
---

# dokploy-compose-manager — Project Identity

> Tier 2 operator owning the **complete per-service installation contract** for the Dokploy PaaS on fnet2.
> Bridges `dokploy-operator` (Tier 1, container lifecycle) and canonical service efforts (Tier 3, what the service IS).

## §1 Identity & Purpose

**Owns:**
- Compose record registration and `composePath` convention enforcement
- Environment variable registration
- Domain registration
- Dokploy compose backup registration
- Dokploy volume backup registration (stateless services only)
- Dokploy server job registration (stateful services)
- Health check registration
- SOT update after registration

**Does NOT own:**
- Container lifecycle (`compose-redeploy`, `compose-update`) → Tier 1 (`dokploy-operator`)
- Service configuration (docker-compose.yml, .env values) → Tier 3 (canonical service effort)

## §2 Three-Tier Model

```
┌──────────────────────────────────────────────────────┐
│ TIER 3 — Canonical Service Effort                    │
│ e.g. Efforts/Infrastructure/nextcloud/               │
│ Owns: what the service IS (compose config, .env)   │
├──────────────────────────────────────────────────────┤
│ TIER 2 — dokploy-compose-manager                    │
│ Owns: compose + env vars + domain + backups +       │
│        schedules + health checks                    │
├──────────────────────────────────────────────────────┤
│ TIER 1 — dokploy-operator                          │
│ Owns: container lifecycle, Traefik, forward-auth   │
└──────────────────────────────────────────────────────┘

Routing: canonical effort → compose-manager → dokploy-operator
```

## §3 Service Install Contract (7 Steps)

All 7 steps must complete before a service is declared installed.

| Step | Action | MCP Tool |
|------|--------|----------|
| 1 | Create compose record | `compose-create` |
| 2 | Set environment variables | `environmentVariable-create` |
| 3 | Register domain | `domain-create` |
| 4 | Create compose backup (container files) | `backup-create` |
| 5 | Create volume backup OR server job | `volumeBackups-create` or `schedule-create` |
| 6 | Register health check | `health-create` |
| 7 | Verify all records → push compose to git | manual verification |

## §4 Backup Decision Tree

```
Is the volume a database?
├── YES → server job (schedule-create, scheduleType: "server")
│         ⚠ Dokploy bug: scheduleType: "server" returns HTTP 500 (v0.30.8)
│         Workaround: Use compose-type schedules with backup-runner container
└── NO
    ├── Is the data rebuildable? (logs, cache, temp)
    │   └── YES → Skip. Document in SOT.
    └── NO
        ├── Is it a Docker named volume?
        │   ├── YES → volumeBackups-create (Dokploy native tar → S3)
        │   └── NO → Bind mount. Document as non-backuppable in SOT.
        └── Is it critical?
            └── YES → Consider rclone-based Ansible backup (Phase 2)
```

**Dokploy volumeBackup deficiency:** `volumeBackups` is a black box. No pre-backup hooks, no pg_dump, no custom tar flags. **Only use for truly static volumes** (Grafana dashboards, Loki segments, Homer config). For databases: server job (Phase 2).

**Dokploy scheduleType bug:** `scheduleType: "server"` returns HTTP 500 in Dokploy v0.30.8. Workaround: use compose-type schedules with a dedicated backup container in each compose. See `output/server-job-migration.md` for implementation details.

## §5 Conventions

### composePath Convention (CRITICAL)

Every compose record must use:
```
composePath: <service>/docker-compose.yml
```

| Service | Correct | Incorrect |
|---------|---------|-----------|
| Authentik | `authentik/docker-compose.yml` | `./`, `config/authentik/`, bare `docker-compose.yml` |
| NextCloud | `nextcloud/docker-compose.yml` | `./nextcloud/`, `config/nextcloud/` |
| Windmill | `windmill/docker-compose.yml` | `windmill/`, `windmill/docker-compose.yml` |

Dokploy resolves paths relative to the git clone root. Wrong `composePath` causes "Compose file not found" errors.

### Credential Convention

- Use `pass show <path>` to retrieve secrets — never hardcode values
- Naming: `<domain>/<service>/<purpose>` (IR-7, e.g., `infrastructure/windmill/db-password`)
- Short-lived tokens belong in the service's environment — mint from refresh tokens in `pass`

### Backup Runner Conventions (Phase 4 — execution model)

**Cross-host backup architecture (Phase 4):**
```
Semaphore schedule → fnet2 backup-runner container
  → su friasc (uses friasc SSH keys)
  → SSH to remote host → docker exec → pg_dump/mysqldump → stream stdout → gzip
  → rclone copy to Wasabi → rclone delete --min-age 90d
```

**Container security model:** `user: "1000:1000"` in docker-compose.yml so Ansible reads pass as friasc.
`STARTUP_USER=friasc` env var causes startup.sh to `su -c` into friasc before running Ansible, so SSH uses friasc's authorized_keys (not root's). Volumes map host paths under `/home/friasc/` (not `/root/`).

**Dynamic container discovery (no hardcoded names):**

| Service | Host | Discovery pattern | Backup method |
|---------|------|-----------------|---------------|
| authentik | fnet2 | `docker ps \| grep authentik-postgresql` | Docker socket exec |
| windmill | fnet2 | `docker ps \| grep windmill_db` | Docker socket exec |
| nextcloud | fnet1 | SSH → `docker ps \| grep nextcloud_db` | SSH stream |
| supabase | fnet3 | SSH → `docker ps \| grep supabase-db` | SSH stream |
| expenseflow | fnet5 | SSH → `docker ps \| grep expenseflow.*postgres` | SSH stream |
| semaphore | fnet7 | SSH → `docker ps \| grep semaphore.*mysql` | SSH stream |
| open-notebook | fnet7 | SSH → docker inspect bind mount | SSH tar stream |

**Semaphore MySQL:** MySQL root has random password — use `semaphore` user instead.

## §6 Quality Standards

1. **Idempotency first:** search before every create. Log every skip with timestamp and reason.
2. **ASSESS before REGISTER:** enumerate existing records before adding anything.
3. **Verify after registration:** confirm records created, containers healthy.
4. **Graduate every fix:** push to git, update SOT, store in ChromaDB.
5. **composePath enforcement:** reject any record not matching `<service>/docker-compose.yml`.

### Anti-Drift Rules (DO-1 through DO-7)

| Rule | Requirement |
|------|-------------|
| **DO-1** | Run ASSESS before any REGISTER. No exceptions. |
| **DO-2** | Use MCP exclusively. SSH only as last resort (IR-12). |
| **DO-3** | Graduate every fix to git + SOT + ChromaDB. No exceptions. |
| **DO-4** | Never touch Tier 1 or Tier 3 directly. |
| **DO-5** | Write to FRM ledger for every action. |
| **DO-6** | Commit and push after every registration. |
| **DO-7** | Escalate data loss risk to human immediately. |

## §7 Current State

### Repository

- **GitHub:** `carlosfrias/dokploy-compose-manager`
- **Type:** Proper git submodule under `carlos-desktop` (`.git/` exists, `.gitmodules` entry correct)
- **SKILL.md:** `skills/dokploy-compose-manager/SKILL.md` (v0.1.0, Phase 1 scaffold)
- **Agent config:** `agents/dokploy-compose-manager.md` (model: `glm-5.1:cloud`)

### Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1 | ✅ Complete | SKILL.md scaffold, agent config, quality gates |
| Phase 2 | ✅ Complete | Backup containers deployed + tested ✅ |
| Phase 3 | ✅ Complete | All 7 services backed up to Wasabi. Registry deployed. |
| Phase 4 | ✅ Complete | SSH auth fix (user 1000:1000, dynamic container discovery, 90d retention). |
| Phase 5 | ✅ Complete | backup-runner v25: Alpine `sleep infinity`, writable `/tmp/ssh_config`, `ANSIBLE_SSH_ARGS`. All 7 containers running v25. dokploy-config commit d1faf05. |

### Phase 5 Completed (2026-11-12)

**Problem solved:** Phase 4 compose drifted to v22 (missing user:1000:1000, SSH mounts). Three runtime bugs in startup.sh.

**Root cause:** Disk clone of `dokploy-config` edited manually without git. v22 compose lost Phase 4 changes. startup.sh had two bugs: `tail -f /dev/null` exits immediately in Alpine (no `tail` binary), and SSH config append failed on read-only filesystem (playbooks mounted `:ro`).

**Fixes applied:**
1. `sleep infinity` — Alpine has no `tail`, `tail -f /dev/null` exits immediately
2. SSH config written to `/tmp/ssh_config` — playbooks mounted :ro, `/runner/` not writable
3. `ANSIBLE_SSH_ARGS=-F /tmp/ssh_config` in `run-ansible.sh` — Ansible picks up writable config
4. Restored Phase 4 compose from git commit `7496771`
5. Bumped to v25 and rebuilt on fnet2 (Docker Desktop can't push to HTTP registry)

**Files changed (dokploy-config):**
- `backup-jobs/docker-compose.yml` — bumped to v25
- `backup-jobs/startup.sh` — sleep infinity, /tmp/ssh_config
- `backup-jobs/run-ansible.sh` — ANSIBLE_SSH_ARGS=-F /tmp/ssh_config
- `backup-jobs/install_python_deps.py` — restored from git

**Registry cleanup:** v7–v22, 1.0.x, alpine, latest deleted. `v14` (previous) + `v25` (current) remain.

**Deployment:** All 7 containers (`authentik/semaphore/windmill/nextcloud/supabase/expenseflow/open-notebook-backup`) running v25 on fnet2 with `user: 1000:1000`.

## §8 Boundaries & Constraints

### Authority Matrix

**Autonomous (no approval needed):**
- Create compose records (after canonical effort authorization)
- Register backups, domains, schedules, env vars, health checks
- Verify registrations
- Graduate fixes to git + SOT + ChromaDB
- Push compose to `carlosfrias/dokploy-config`

**Requires Human Approval:**
- New service approval (canonical effort must authorize first)
- Service deletion
- SOT structural changes (schema, new fields)
- Swarm or network topology changes

### Trigger Conditions

- Canonical service effort requests new deployment
- `dokploy-operator` dispatches Tier 2 work (missing env vars, backup rows, domains)
- `fleet-dispatcher` routes Tier 2 work
- Manual dispatch from owner

**Keywords:** "deploy `<service>`", "register `<service>`", "compose-manager install", "setup `<service>` on Dokploy"

## §9 Quick Reference

| What | Where |
|------|-------|
| Full skill (MCP tables, Assess/Register/Verify loop) | `AGENTS-DEEP.md` |
| Architecture diagrams | `ARCHITECTURE.md` |
| Phase 4 execution model | `AGENTS.md` § Backup Runner Conventions |
| Dokploy effort | `Efforts/Infrastructure/dokploy/AGENTS.md` |
| MCP tools | `mcp__dokploy` (604 tools) |
| SSH key | `R7VQAMIqCoLqs2E3rr1ff` (Dokploy deploy key) |
| API key | `pass infrastructure/dokploy/api-key` |
| SOT | `fleet-orchestration/fleet-control/playbook-index.json` |
| Backup playbooks | `dokploy-config/backup-jobs/playbooks/` (canonical) |

## §10 Self-Improvement

**Improve this effort:** Say "apply AGENT-SPEC to dokploy-compose-manager" or "improve compose-manager"

**Process:** IKA skill → FRP LEVELS → AGENT-SPEC (loaded on demand from `frp/agent-spec/CORE.md`)

**Staleness triggers:**
- Sections unchanged >30d → On effort → needs review
- Sections unchanged >90d → Ongoing effort → needs improvement
- Sections unchanged >365d → Simmering effort → major refresh

**Next improvement priorities:**
1. ~~Phase 2 completion: per-service backup playbooks + server job workaround~~ ✅
2. ~~Phase 3: service registrations via compose-manager~~ ✅
3. ~~Phase 4: automate cross-host backup execution~~ ✅
4. ~~Phase 5: backup-runner v25 — Alpine fix, writable SSH config~~ ✅

---

*Part of the Dokploy tier system. Tier 1 = `dokploy-operator`. Tier 3 = canonical service efforts.*
