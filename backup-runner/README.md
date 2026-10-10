# backup-runner

> Ansible runner Docker image for Dokploy server job backups.
> Runs inside the Dokploy schedule execution context. Calls Ansible playbooks from mounted playbooks directory.

## What it does

Dokploy server jobs SSH to a target host and run `bash /script.sh`. The script calls `docker run backup-runner` which executes Ansible playbooks for database dumps and volume backups.

```
Dokploy schedule (03:00 UTC)
  → SSH to fnet2
  → bash /etc/dokploy/schedules/<service>/script.sh
  → docker run ghcr.io/carlosfrias/backup-runner:latest backup-<service>
  → Ansible playbook runs pg_dump / mysqldump
  → rclone uploads to Wasabi S3
  → Logs stream back to Dokploy UI
```

## Build

```bash
# Local build (no push)
docker build -t ghcr.io/carlosfrias/backup-runner:1.0.0 ./backup-runner

# Local build with buildx (multi-arch)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/carlosfrias/backup-runner:1.0.0 \
  ./backup-runner

# Test healthcheck
docker run --rm ghcr.io/carlosfrias/backup-runner:latest healthcheck
```

## CI/CD

GitHub Actions (`.github/workflows/build.yml`):
- **Push to `main`:** builds and pushes architecture-specific tags (`1.0.0-amd64`, `1.0.0-arm64`)
- **Tag `v*`:** builds, pushes architecture-specific tags, creates and pushes multi-arch manifest
- **Pull request:** builds without pushing

## Image

| Field | Value |
|-------|-------|
| Registry | `ghcr.io` |
| Owner | `carlosfrias` |
| Image | `ghcr.io/carlosfrias/backup-runner` |
| Tags | `1.0.0`, `1.0.0-amd64`, `1.0.0-arm64`, `latest` (on release) |
| Base | `quay.io/ansible/ansible-runner:stable-2.12-latest` |
| Architectures | `amd64`, `arm64` |

## Usage

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/playbooks:/runner/playbooks:ro \
  ghcr.io/carlosfrias/backup-runner:latest authentik
```

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `ANSIBLE_HOST_KEY_CHECKING` | `no` | Skip SSH host key verification |
| `ANSIBLE_PRIVATE_KEY_FILE` | `/root/.ssh/id_rsa` | SSH key for fleet nodes |
| `ANSIBLE_SCP_IF_SSH` | `y` | Use SCP for file transfers |

## Healthcheck

```bash
docker run --rm ghcr.io/carlosfrias/backup-runner:latest healthcheck
```

Verifies: all tools present, ansible-playbook functional, SSH connectivity.

## Quality Gates

| Gate | Standard | Status |
|------|----------|--------|
| DCQ-1 | No `:latest` tag | ✅ `quay.io/ansible/ansible-runner:stable` + versioned ARG |
| DCQ-2 | Healthcheck | ✅ `HEALTHCHECK --interval=60s CMD /entrypoint.sh healthcheck` |
| DCQ-3 | No hardcoded secrets | ✅ All credentials via mount or env injection |
| BQ-1 | `set -euo pipefail` | ✅ entrypoint.sh line 1 |
| BQ-2 | `trap EXIT` | ✅ on_exit function with exit code reporting |
