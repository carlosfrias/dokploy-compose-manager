# compose-manager — Phase 3 Launch Prompt (v2)

> **Resume from session 2026-11-12.** §1–§3 complete. §4 partial (authentik ✅). §5–§6 open. §7 in progress.

**CWD:** `/Users/friasc/Cloud/carlos-desktop/Efforts/Infrastructure/dokploy/compose-manager/`
**Owner:** compose-manager Tier 2 operator
**Phase:** 3 of 3

---

## What was done this session

### §1 — Registry ✅
- Compose `composeId: KeS-CUyaef2OchjHitcRR` deployed on fnet2
- Domain `registry.svc.friasc.com` → HTTPS → HTTP → registry container
- Mac can push/pull: `docker push registry.svc.friasc.com/carlosfrias/backup-runner:alpine` ✅

### §2 — backup-jobs compose ✅
- 7 containers: authentik/semaphore/windmill/nextcloud/supabase/expenseflow/open-notebook
- Image: `localhost:5000/carlosfrias/backup-runner:v10` (Alpine 3.20, ~628MB)
- Image pushed to both local registry (`localhost:5000`) and remote registry (`registry.svc.friasc.com`)
- composeId: `adWaqiMliwUqOf_MX5POF`
- **Critical fix:** `docker-compose.yml` runs containers with `command: ["idle"]` which maps to `tail -f /dev/null` via startup.sh

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

### §4 — Backup testing ✅ (authentik) / ⏳ (6 remaining)
- **authentik:** ✅ pg_dump → gzip → rclone → Wasabi `wasabi:friasc-backups/authentik/`
  - Latest: `authentik-db-20261010T201039.sql.gz` (11MB, 2026-10-10 20:10 UTC)
  - All tasks: dump → save → upload → cleanup, 0 failures
- **6 remaining:** nextcloud, semaphore, windmill, supabase, expenseflow, open-notebook

---

## Remaining work

### §4 cont — Test the other 6 backups

Run each backup manually and verify Wasabi upload:

```bash
# On fnet2:
docker exec nextcloud-backup /startup.sh nextcloud
docker exec semaphore-backup /startup.sh semaphore
docker exec windmill-backup /startup.sh windmill
docker exec supabase-backup /startup.sh supabase
docker exec expenseflow-backup /startup.sh expenseflow
docker exec open-notebook-backup /startup.sh open-notebook

# Then verify:
ssh fnet2 "rclone ls wasabi:friasc-backups/<service>/ --max-age 1h"
```

**Expected patterns:**
| Service | File pattern | Verify |
|---------|------------|--------|
| authentik | `authentik-db-*.sql.gz` | ✅ done |
| nextcloud | `nextcloud-db-*.sql.gz` or `nextcloud-*.tar.gz` | — |
| semaphore | `semaphore-db-*.sql.gz` | — |
| windmill | `windmill-db-*.sql.gz` | — |
| supabase | `supabase-db-*.sql.gz` | — |
| expenseflow | `expenseflow-db-*.sql.gz` | — |
| open-notebook | `open-notebook-db-*.json.gz` | — |

**Known issues per service:**
- **supabase:** playbook likely uses wrong DB password — check `infrastructure/presswork-pod/supabase/postgres-password` in pass
- **expenseflow:** container name may differ — check `docker exec expenseflow-backup docker ps --format '{{.Names}}'`
- **open-notebook:** SurrealDB backup command may differ from PostgreSQL
- **nextcloud:** may need `occ` command instead of direct mysqldump

### §5 — Supabase password in pass

The playbook uses `infrastructure/presswork-pod/supabase/postgres-password`. Check if it exists:

```bash
ssh fnet2 "pass show infrastructure/presswork-pod/supabase/postgres-password" 2>&1
```

If missing, find it from the running container:
```bash
ssh fnet3 "docker exec supabase-db psql -U postgres -c 'SELECT rolname FROM pg_authid;'"
# Or check the .env file:
ssh fnet3 "cat /etc/dokploy/compose/.../supabase/.env | grep POSTGRES_PASSWORD"
```

Then add to pass:
```bash
pass insert -m infrastructure/presswork-pod/supabase/postgres-password
# paste password, Ctrl+D
```

### §6 — Update SOT

Update `fleet-orchestration/fleet-control/config/playbook-index.json`:

```json
"backup-jobs": {
  "composeId": "adWaqiMliwUqOf_MX5POF",
  "composeName": "backup-jobs",
  "composeBackupId": "<from backup-create>",
  "image": "localhost:5000/carlosfrias/backup-runner:v10",
  "schedules": [
    { "service": "authentik",     "scheduleId": "Egw9m7GOvNZE1ClVnQElz", "cron": "0 3 * * *" },
    { "service": "nextcloud",     "scheduleId": "UUqaTJP9SaykMwvS4aUch", "cron": "30 3 * * *" },
    { "service": "semaphore",     "scheduleId": "41Membt0XGd3Hc0rUHtfZ", "cron": "15 3 * * *" },
    { "service": "windmill",      "scheduleId": "Izgxdzxjad5TX42fLtnJv", "cron": "45 3 * * *" },
    { "service": "supabase",      "scheduleId": "YVz2KiW333AUjKaK2L9jb", "cron": "0 4 * * *" },
    { "service": "expenseflow",   "scheduleId": "-mpk8FbzoiDvQCj8q5i3n", "cron": "15 4 * * *" },
    { "service": "open-notebook", "scheduleId": "2ZJ2qyYuzIdCJfOLzPijV", "cron": "30 4 * * *" }
  ]
}
```

### §7 — Commit and graduate

```bash
cd /Users/friasc/Cloud/carlos-desktop/Efforts/Infrastructure/dokploy/compose-manager/

# ChromaDB record
memory_store({
  collection: "infrastructure",
  text: "compose-manager Phase 3 complete. backup-jobs compose deployed (v10 Alpine). Registry deployed. 7 schedules registered. Authentik backup tested ✅. composeId: adWaqiMliwUqOf_MX5POF, registryId: KeS-CUyaef2OchjHitcRR",
  metadata: { effort: "compose-manager", phase: 3, tier: 2 }
})

# Push compose-manager
git add -A
git commit -m "feat: Phase 3 complete — backup-jobs v10, registry, all 7 schedules"
git push origin main
```

---

## Current state of things

### backup-runner image (v10)
| Item | Value |
|------|-------|
| Registry | `registry.svc.friasc.com/carlosfrias/backup-runner:v10` |
| Base | Alpine 3.20 |
| Size | ~628MB |
| Local tag | `localhost:5000/carlosfrias/backup-runner:v10` |
| Startup | `startup.sh` → `idle` / `--diagnose` / `<service>` |
| Build | On fnet2 (linux/amd64) |
| Git | `dokploy-config/backup-jobs/` |

### backup-jobs compose (on disk)
`/etc/dokploy/compose/compose-index-cross-platform-capacitor-vwykix/code/backup-jobs/`

Files:
- `docker-compose.yml` — 7 containers, v10 image, GNUPGHOME env, all volumes
- `startup.sh` — idle/diagnose/backup modes (not in use — volume mount is :ro)
- `Dockerfile` — for rebuilding
- `ansible.cfg` — UTF-8 relaxed
- `playbooks/` — 7 backup playbooks, all fixed

### Volumes mounted per container
```yaml
- /var/run/docker.sock:/var/run/docker.sock       # docker exec
- /home/friasc/.ssh:/root/.ssh:ro                # SSH
- /home/friasc/.password-store:/root/.password-store:ro  # pass
- /home/friasc/.gnupg:/root/.gnupg:rw           # GPG (needs write for temp files)
- /home/friasc/.config/rclone:/root/.config/rclone:ro  # rclone config
- /etc/dokploy/compose/.../playbooks:/runner/playbooks:ro  # playbooks
```

### Playbook fixes applied
1. `pg_dump | gzip` → `sh -c "pg_dump ... | gzip"` (docker_container_exec needs shell for pipe)
2. `ansible.builtin.include_role: friasc.fleet_control_backup.*` → removed (role doesn't exist)
3. `rclone config dir creation` → removed (config mounted from host)
4. Verify plays → removed (role missing)

### Remaining playbook issues
- **friasc.fleet_control_backup.verify_backup role** — doesn't exist; verify steps removed from all playbooks
- **friasc.fleet_control_backup.backup_wasabi role** — doesn't exist; replaced with direct `rclone copy` shell call
- These roles need to be created (or the verify/upload steps need to be rewritten without them)

---

## Success criteria

- [ ] §4: 6 remaining backups tested (nextcloud, semaphore, windmill, supabase, expenseflow, open-notebook)
- [ ] §5: Supabase password in pass at `infrastructure/presswork-pod/supabase/postgres-password`
- [ ] §6: SOT updated with all composeIds, scheduleIds
- [ ] §7: ChromaDB record stored, commits pushed

---

*Last updated: 2026-11-12 · Authentik backup verified · 6 services remaining*
