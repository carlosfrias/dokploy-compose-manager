# backup-runner

> Ansible runner Docker image for Dokploy server job backups.
> Pushed to private registry. Runs inside the Dokploy schedule execution context.

## Registry

| Field | Value |
|-------|-------|
| Registry | `registry.svc.friasc.com` |
| Image | `registry.svc.friasc.com/carlosfrias/backup-runner` |
| Tags | `1.0.0`, `latest` |

## Push

```bash
# Build and push multi-arch (amd64 + arm64) from Mac
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0 \
  -t registry.svc.friasc.com/carlosfrias/backup-runner:latest \
  --push \
  ./backup-runner
```

`docker --context=fnet2` pushes directly from the Mac to the registry on fnet2, via the existing Docker context.

## Build (local test)

```bash
# Local build and test (no push)
docker build -t registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0-test ./backup-runner

# Test healthcheck
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0-test \
  healthcheck
```

## Usage

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/playbooks:/runner/playbooks:ro \
  registry.svc.friasc.com/carlosfrias/backup-runner:latest authentik
```

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `ANSIBLE_HOST_KEY_CHECKING` | `no` | Skip SSH host key verification |
| `ANSIBLE_PRIVATE_KEY_FILE` | `/root/.ssh/id_rsa` | SSH key for fleet nodes |
| `ANSIBLE_SCP_IF_SSH` | `y` | Use SCP for file transfers |

## Healthcheck

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  registry.svc.friasc.com/carlosfrias/backup-runner:latest \
  healthcheck
```

Verifies: all tools present, ansible-playbook functional, SSH connectivity.

## Image

| Field | Value |
|-------|-------|
| Base | `ubuntu:24.04` |
| Ansible | `ansible-core==2.17.*`, `ansible-runner==2.3.*` |
| Tools | `openssh-client`, `rclone`, `curl`, `jq`, `postgresql-client`, `mariadb-client` |
| Architecture | `amd64` (fleet nodes are Intel/AMD) |

## Quality Gates

| Gate | Standard | Status |
|------|----------|--------|
| DCQ-1 | No `:latest` | ✅ `ubuntu:24.04` base + `1.0.0` tag |
| DCQ-2 | Healthcheck | ✅ `HEALTHCHECK --interval=60s CMD /entrypoint.sh healthcheck` |
| DCQ-3 | No hardcoded secrets | ✅ All credentials via mount or env injection |
| BQ-1 | `set -euo pipefail` | ✅ entrypoint.sh line 1 |
| BQ-2 | `trap EXIT` | ✅ `on_exit` function with exit code reporting |
