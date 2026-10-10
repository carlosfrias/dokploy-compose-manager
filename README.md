# dokploy-compose-manager

Tier 2 operator — owns the complete per-service installation contract for Dokploy PaaS.

## What It Does

Registers every component a service needs to run on Dokploy:

1. Create compose record
2. Set environment variables
3. Register domain
4. Create compose backup (container files)
5. Create volume backup (stateless) or server job (stateful)
6. Register health check
7. Verify all → push to git

## Trigger

- Canonical service effort deployment request
- `dokploy-operator` dispatch
- `fleet-dispatcher` routing
- Manual: `subagent({ agent: "dokploy-compose-manager" })`

## Quality Standard

Every registration must be **idempotent** and **verified** before declaring complete.

## Phase 2 TODO

The `backup-runner` Docker image (`registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0`) is built. Push it to the private registry before using it in Dokploy schedules.

## Quick Links

- [AGENTS.md](AGENTS.md) — project identity, tier model, install contract
- [SKILL.md](skills/dokploy-compose-manager/SKILL.md) — full operator skill
- [Dokploy effort](../Efforts/Infrastructure/dokploy/AGENTS.md) — parent context
