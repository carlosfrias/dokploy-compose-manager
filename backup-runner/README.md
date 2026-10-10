# backup-runner

> Alpine-based Ansible runner for Dokploy schedule backups. Iterative build: tools
> added via `docker exec` during sessions, then committed and baked into the next image.

## Registry

| Field | Value |
|-------|-------|
| Registry | `registry.svc.friasc.com` |
| Image | `registry.svc.friasc.com/carlosfrias/backup-runner` |
| Latest tag | `v10` (Alpine 3.20) |

## Build & Push

```bash
# 1. Build on fnet2 (Linux/amd64 — Mac can't cross-build cleanly)
ssh fnet2 "docker build --platform linux/amd64 -t localhost:5000/carlosfrias/backup-runner:<tag> ./backup-runner/"

# 2. Push to local registry
ssh fnet2 "docker push localhost:5000/carlosfrias/backup-runner:<tag>"

# 3. Push to remote registry (for Mac pulls)
ssh fnet2 "docker tag localhost:5000/carlosfrias/backup-runner:<tag> \\
    registry.svc.friasc.com/carlosfrias/backup-runner:<tag> && \\
    docker push registry.svc.friasc.com/carlosfrias/backup-runner:<tag>"
```

## Image Size

| Tag | Size | Notes |
|-----|------|-------|
| Ubuntu 1.0.x | ~700MB | Old, deprecated |
| Alpine v10 | ~628MB | Current: Alpine 3.20 + all tools |

## Toolset

- **OS:** Alpine 3.20 (minimal)
- **Shell:** bash (installed), /bin/sh (built-in ash)
- **DB clients:** postgresql-client, mariadb-client
- **Ansible:** ansible + ansible-core (Alpine package) + community.docker v5.4.0 (galaxy)
- **Python deps:** docker SDK, requests, urllib3, PyMySQL (PyPI wheels)
- **Secrets:** pass, gnupg
- **Network:** openssh-client, rsync, curl
- **Backup:** rclone, tar, gzip, jq

## Modes

| Mode | Command | What happens |
|------|---------|-------------|
| Idle | (no args) | `tail -f /dev/null` — keeps container alive |
| Diagnose | `--diagnose` | Check all tools present, exit 0/1 |
| Backup | `<service>` | Run `playbooks/backup-<service>.yml` |

## Usage

```bash
# Diagnose
docker exec <container> /startup.sh --diagnose

# Idle
docker exec <container> /startup.sh idle

# Run backup
docker exec <container> /startup.sh authentik
```

## Iterative Tool Addition Workflow

1. Containers run in idle mode (`tail -f /dev/null`)
2. `docker exec <container> /startup.sh --diagnose` → see what's missing
3. `docker exec <container> apk add <tool>` (or `python3 /tmp/fix_docker.py` for pip packages)
4. Test: `docker exec <container> /startup.sh <service>`
5. At session end: `docker commit <container> localhost:5000/carlosfrias/backup-runner:<newtag>`
6. Push: see Build & Push above
7. Update compose to `<newtag>`, redeploy

## Required Volumes

```yaml
- /var/run/docker.sock:/var/run/docker.sock   # docker exec on host
- /home/friasc/.ssh:/root/.ssh:ro             # SSH to fleet nodes
- /home/friasc/.password-store:/root/.password-store:ro  # pass lookups
- /home/friasc/.gnupg:/root/.gnupg:rw        # GPG for pass
- /home/friasc/.config/rclone:/root/.config/rclone:ro  # rclone config
- /path/to/playbooks:/runner/playbooks:ro     # Ansible playbooks
```

## Environment

| Variable | Value | Purpose |
|----------|-------|---------|
| `GNUPGHOME` | `/root/.gnupg` | GPG keyring for pass |
| `ANSIBLE_HOST_KEY_CHECKING` | `False` | Skip SSH host key verification |

## Quality Gates

| Gate | Standard | Status |
|------|----------|--------|
| BQ-1 | `set -euo pipefail` | ✅ startup.sh |
| BQ-2 | `trap EXIT` | ✅ exit reporting |
| DCQ-1 | No `:latest` | ✅ `v10` tag |
| DCQ-3 | No hardcoded secrets | ✅ All via mounts |
| Startup | diagnose/idle/backup modes | ✅ |
| SSH | `-F /dev/null -o StrictHostKeyChecking=no` | ✅ in playbooks |
