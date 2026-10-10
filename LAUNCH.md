# compose-manager — Phase 3 Launch Prompt (v3)

> **Completed 2026-10-10.** All sections done. Phase 3 closed.

**CWD:** `/Users/friasc/Cloud/carlos-desktop/Efforts/Infrastructure/dokploy/compose-manager/`
**Owner:** compose-manager Tier 2 operator
**Phase:** 3 of 3 — ✅ COMPLETE

---

## Results

### §1 — Registry ✅
- Compose `composeId: KeS-CUyaef2OchjHitcRR` deployed on fnet2
- Domain `registry.svc.friasc.com` → HTTPS → HTTP → registry container
- Mac can push/pull: `docker push registry.svc.friasc.com/carlosfrias/backup-runner:alpine` ✅

### §2 — backup-jobs compose ✅
- 7 containers: authentik/semaphore/windmill/nextcloud/supabase/expenseflow/open-notebook
- Image: `localhost:5000/carlosfrias/backup-runner:v10` (Alpine 3.20, ~628MB)
- composeId: `adWaqiMliwUqOf_MX5POF`

### §3 — Backup schedules ✅ (via MCP)
| Service | scheduleId | Cron |
|---------|-----------|------|
| authentik | `Egw9m7GOvNZE1ClVnQElz` | `0 3 * * *` |
| semaphore | `41Membt0XGd3Hc0rUHtfZ` | `15 3 * * *` |
| windmill | `Izgxdzxjad5TX42fLtnJv` | `45 3 * * *` |
| nextcloud | `UUqaTJP9SaykMwvS4aUch` | `30 3 * * *` |
| supabase | `YVz2KiW333AUjKaK2L9jb` | `0 4 * * *` |
| expenseflow | `-mpk8FbzoiDvQCj8q5i3n` | `15 4 * * *` |
| open-notebook | `2ZJ2qyYuzIdCJfOLzPijV` | `30 4 * * *` |

### §4 — Backup testing ✅ (all 7 services)

| Service | Method | Host | Container | Wasabi | Size |
|---------|--------|------|-----------|--------|------|
| authentik | pg_dump → gzip → rclone | fnet2 | `authentik-postgresql-1` | ✅ | 11MB |
| windmill | pg_dump → gzip → rclone | fnet2 | `windmill-ztuswo-windmill_db-1` | ✅ | real |
| nextcloud | mysqldump → gzip → rclone | fnet1 | `nextcloud-ijgeuz-nextcloud-db-1` | ✅ | 59MB |
| supabase | pg_dump → gzip → rclone | fnet3 | `supabase-db` | ✅ | 68KB |
| expenseflow | pg_dump → gzip → rclone | fnet5 | `expenseflow-postgres-1` | ✅ | 2.7KB |
| semaphore | mysqldump → gzip → rclone | fnet7 | `compose-...-mysql-1` | ✅ | 6.5MB |
| open-notebook | tar RocksDB bind mount | fnet7 | N/A (bind mount) | ✅ | 12MB |

### §5 — Supabase password ✅
- `infrastructure/presswork-pod/supabase/postgres-password` → `aLtjGEm61TcXc7Y4fyJLEpc8Yk3LdEqO`
- Also added: windmill, expenseflow, semaphore, open-notebook passwords to pass

### §6 — SOT updated ✅
- `fleet-orchestration/fleet-control/playbook-index.json` updated with compose_manager section
- 7 schedules, 6 pass entries, known issues documented

### §7 — Graduated ✅
- ChromaDB: semantic + episodic records stored
- dokploy-compose-manager: commit `139abc0` pushed
- dokploy-config: commit `0012192` pushed (backup-jobs playbooks + compose)

---

## Root Cause Analysis (from initial test failures)

All 6 services failed initial test because:

1. **Wrong container names** — Dokploy adds random prefixes (`compose-xxx-`, `nextcloud-ijgeuz-`)
   - `windmill-db` → `windmill-ztuswo-windmill_db-1`
   - `nextcloud-db` → `nextcloud-ijgeuz-nextcloud-db-1`
   - etc.

2. **Cross-host SSH blocked** — fnet2 cannot SSH to fnet1/fnet3/fnet5/fnet7
   - backup-runner containers isolated on fnet2
   - **Fix:** Backups run via Mac orchestrator using fleet inventory SSH

3. **friasc.fleet_control_backup roles missing** — replaced with direct `rclone copy`

4. **Semaphore MySQL root is random** — use `semaphore` user instead of `root`

5. **SurrealDB minimal image** — no shell, backed up via RocksDB bind mount tar

---

## Key Discoveries

| Discovery | Impact |
|-----------|--------|
| Dokploy adds random prefixes to container names | Always verify actual container names |
| fnet2 cannot SSH to other fleet nodes | backup-runner architecture flawed — use Mac orchestrator |
| Mac's pass store synced from fnet2 | Enables Mac-orchestrator backup approach |
| fleet-control inventory has all hosts | Can use fleet inventory for backup execution |

---

## Next Priority: Phase 4

**Automate cross-host backup execution** via fleet-orchestration:
- Write durable Ansible playbooks in `fleet-control/playbooks/` targeting service groups
- Integrate with Semaphore schedules for automated execution
- Fix container name discovery (dynamic lookup vs hardcoded)

---

*Last updated: 2026-10-10 · Phase 3 complete · All 7 services backed up to Wasabi*
