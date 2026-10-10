---
repo: carlosfrias/dokploy-compose-manager
type: operator
tier: 2
---

# dokploy-compose-manager — Project Identity

## Purpose

Tier 2 operator owning the **complete per-service installation contract** for the Dokploy PaaS on fnet2. Bridges `dokploy-operator` (Tier 1, container lifecycle) and canonical service efforts (Tier 3, what the service IS).

**Owns:**
- Compose record registration and path convention enforcement
- Environment variable registration
- Domain registration
- Dokploy compose backup registration
- Dokploy volume backup registration (stateless services only)
- Dokploy server job registration (stateful services)
- Health check registration
- SOT update after registration

**Does NOT own:**
- Container lifecycle or compose redeployment (Tier 1 → `dokploy-operator`)
- Service configuration or canonical service definition (Tier 3 → service effort)

## Three-Tier Model

```
┌──────────────────────────────────────────────────┐
│ TIER 3 — Canonical Service Effort                │
│ e.g. Efforts/Infrastructure/nextcloud/           │
│ Owns: what the service IS                        │
├──────────────────────────────────────────────────┤
│ TIER 2 — dokploy-compose-manager                 │
│ Owns: compose + env vars + domain + backups +    │
│        schedules + health checks                  │
├──────────────────────────────────────────────────┤
│ TIER 1 — dokploy-operator                       │
│ Owns: container lifecycle, Traefik, forward-auth│
└──────────────────────────────────────────────────┘

Routing: canonical effort → compose-manager → dokploy-operator
```

## Service Install Contract

**7 required steps — all must complete before a service is declared installed:**

| Step | Action | MCP Tool |
|------|--------|----------|
| 1 | Create compose record | `compose-create` |
| 2 | Set environment variables | `environmentVariable-create` |
| 3 | Register domain | `domain-create` |
| 4 | Create compose backup (container files) | `backup-create` |
| 5 | Create volume backup OR server job | `volumeBackups-create` or `schedule-create` |
| 6 | Register health check | `health-create` |
| 7 | Verify all records → push compose to git | manual verification |

## Backup Decision Tree

```
Is the volume a database?
  YES → server job
    schedule-create({ scheduleType: "server", command: "docker run --rm
      -v /var/run/docker.sock:/var/run/docker.sock
      ghcr.io/carlosfrias/backup-runner:latest /entrypoint.sh backup-<service>" })
    ⚠ Phase 2: backup-runner image is not yet built

  NO → Is the data rebuildable? (logs, cache, temp files)
    YES → Skip backup. Document in SOT.

    NO → Is it a Docker named volume?
      YES → volumeBackups-create (Dokploy native tar → S3)
      NO → Bind mount. Document as non-backuppable in SOT.
```

### Dokploy Volume Backup Deficiency

`volumeBackups` is a black box:
- Runs `docker run ubuntu tar cvf /backup/<vol>.tar .` inside the volume
- Uploads to S3 via rclone
- No pre-backup hooks (cannot run `pg_dump` before tar)
- No post-backup scripts (cannot verify checksum, run retention policy)
- No custom retention (Dokploy manages all retention)
- **Inadequate for any database volume**

Server jobs are correct for all stateful services containing databases.

## Server Job Mechanism

Dokploy schedules run a bash script on the target server via SSH. The script runs a Docker container that executes an Ansible playbook:

```yaml
scheduleType: "server"
serverId: "fnet2"
cronExpression: "0 3 * * *"
command: |
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ~/.ssh:/root/.ssh:ro \
    ghcr.io/carlosfrias/backup-runner:latest \
    /entrypoint.sh backup-<service>
```

- Dokploy SSHs to `serverId` and runs the bash script
- The container has Docker socket access (manages host containers)
- The container has SSH keys (reaches other fleet nodes)
- Ansible runs inside the container — **no Ansible on hosts**
- Logs appear in Dokploy UI under the schedule
- ⚠ Phase 2 TODO: `backup-runner` image must be built and pushed to GHCR

## Trigger Conditions

- Canonical service effort requests new deployment
- `dokploy-operator` dispatches Tier 2 work (env vars, backups, domains)
- `fleet-dispatcher` routes Tier 2 work
- Manual dispatch from owner

## Quality Standards

1. **Idempotency first:** search before every create
2. **composePath convention:** `<service>/docker-compose.yml` (never `./` or `config/`)
3. **ASSESS before REGISTER:** enumerate existing records before adding
4. **Verify after registration:** confirm records created, containers healthy
5. **Graduate every fix:** push to git, update SOT, store in ChromaDB
6. **DO-1 through DO-7:** see SKILL.md anti-drift rules

## Quick Reference

- **GitHub:** `carlosfrias/dokploy-compose-manager`
- **SKILL.md:** `skills/dokploy-compose-manager/SKILL.md`
- **Dokploy effort:** `Efforts/Infrastructure/dokploy/AGENTS.md`
- **MCP tools:** `mcp__dokploy` (604 tools)
- **SSH key:** `R7VQAMIqCoLqs2E3rr1ff`
- **Dokploy API key:** `pass infrastructure/dokploy/api-key`
