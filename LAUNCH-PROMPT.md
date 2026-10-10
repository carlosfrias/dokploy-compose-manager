# Launch Prompt: compose-manager Phase 4

**Effort:** `Efforts/Infrastructure/dokploy/compose-manager/`
**Session:** 2026-10-10
**Phase:** Phase 4 — Automate cross-host backup execution

---

## Context

Phase 3 is complete. All 7 database services have been manually backed up to Wasabi and the execution model is documented.

### Current State

**What works:**
- All 7 backup playbooks exist in `dokploy-config/backup-jobs/playbooks/` and have been tested manually
- All 7 services backed up successfully:
  - authentik (fnet2, pg_dump, 11MB)
  - windmill (fnet2, pg_dump, 4.4MB)
  - nextcloud (fnet1, mysqldump, 59MB)
  - supabase (fnet3, pg_dump, 68KB)
  - expenseflow (fnet5, pg_dump, 2.7KB)
  - semaphore (fnet7, mysqldump, user=semaphore, 6.5MB)
  - open-notebook (fnet7, SurrealDB RocksDB tar, 12MB)

**Known container names (verify before every backup — Dokploy adds random prefixes):**
| Service | Host | Container |
|---------|------|---------|
| authentik | fnet2 | `authentik-postgresql-1` |
| windmill | fnet2 | `windmill-ztuswo-windmill_db-1` |
| nextcloud | fnet1 | `nextcloud-ijgeuz-nextcloud-db-1` |
| supabase | fnet3 | `supabase-db` |
| expenseflow | fnet5 | `expenseflow-postgres-1` |
| semaphore | fnet7 | `compose-program-neural-circuit-hguc18-mysql-1` |

**Pass entries (all synced to Mac):**
- `infrastructure/windmill/db-password`
- `infrastructure/presswork-pod/supabase/postgres-password`
- `infrastructure/expenseflow/db-password`
- `infrastructure/semaphore/db-password`
- `infrastructure/open-notebook/surrealdb-password`
- `infrastructure/nextcloud/db-password`

**Cross-host SSH architecture:**
- fnet2 backup-runner containers cannot reach other hosts (network isolation)
- Backups execute via **Mac orchestrator** using fleet-control inventory SSH
- Pattern: `ssh <host> "docker exec <container> pg_dump | gzip" | rclone copy wasabi:bucket/`

**Wasabi buckets:**
- `wasabi:friasc-backups/{authentik,nextcloud,semaphore,windmill,supabase,expenseflow,open-notebook}/`

**Semaphore schedules already registered (via MCP):**
| Service | scheduleId |
|---------|------------|
| authentik | `Egw9m7GOvNZE1ClVnQElz` |
| semaphore | `41Membt0XGd3Hc0rUHtfZ` |
| windmill | `Izgxdzxjad5TX42fLtnJv` |
| nextcloud | `UUqaTJP9SaykMwvS4aUch` |
| supabase | `YVz2KiW333AUjKaK2L9jb` |
| expenseflow | `-mpk8FbzoiDvQCj8q5i3n` |
| open-notebook | `2ZJ2qyYuzIdCJfOLzPijV` |

---

## Phase 4 Goal

Automate the cross-host backup execution so it runs on the registered Semaphore schedules, not manually.

### Key Architecture Decision

The Mac orchestrator approach works but is fragile: the Mac must be online and the SSH connection must be reliable. Evaluate two options:

**Option A — Semaphore runs Ansible playbook via fleet-control inventory:**
- Semaphore schedule triggers an Ansible playbook
- Ansible connects from Semaphore container to target hosts via fleet-control inventory
- Semaphore has Docker socket + SSH keys + pass store
- Problem: Does the Semaphore container have network access to fnet1/fnet3/fnet5/fnet7?

**Option B — Fleet-control scheduled job:**
- Use fleet-control's existing schedule mechanism
- fleet-control has proper inventory and SSH access to all nodes
- Register backup jobs as fleet-control scheduled tasks
- Problem: fleet-control doesn't currently manage per-service backup schedules

**Option C — Dedicated backup runner per host:**
- Deploy `backup-runner` container on each host (fnet1, fnet3, fnet5, fnet7)
- Each runner can `docker exec` its local containers and `rclone` directly to Wasabi
- No cross-host SSH needed
- Dokploy schedules point to local runners
- Problem: More containers to manage, more complexity

### Sub-tasks

1. **Evaluate execution architecture** — test Option A first (lowest change, just register Ansible playbook in Semaphore)
2. **If Option A works** — wire up all 7 schedules to run via fleet-control Ansible playbooks
3. **If Option A fails** — implement Option B or C
4. **Dynamic container name discovery** — playbooks currently hardcode container names which break when Dokploy regenerates the compose prefix. Add `docker ps | grep` lookup step.
5. **Wasabi retention policy** — implement `rclone delete` with `--max-age 90d` for 90-day retention
6. **Update SOT** — register new backup execution mechanism in `fleet-orchestration/fleet-control/playbook-index.json`
7. **Test full schedule run** — trigger all 7 schedules manually and verify Wasabi uploads

---

## References

- `compose-manager/AGENTS.md` — Tier 2 operator identity
- `compose-manager/AGENTS-DEEP.md` — Corrected execution model (§5)
- `dokploy-config/backup-jobs/playbooks/` — Tested Ansible playbooks
- `fleet-orchestration/fleet-control/playbook-index.json` — SOT
- `Efforts/Infrastructure/dokploy/AGENTS.md` — Dokploy platform context

---

## Exit Criteria

- [ ] Semaphore schedules execute backups automatically (not manually)
- [ ] All 7 services have successful automated backup runs in Wasabi
- [ ] Dynamic container name discovery works (no hardcoded names)
- [ ] 90-day Wasabi retention configured
- [ ] SOT updated
- [ ] ChromaDB records stored
- [ ] Committed and graduated
