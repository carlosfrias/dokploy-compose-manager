# backup-runner — Ansible runner image for Dokploy server jobs
#
# Purpose: Runs Ansible playbooks inside Dokploy's schedule execution context.
#   Called by: docker run --rm registry.svc.friasc.com/carlosfrias/backup-runner:latest /entrypoint.sh <service>
#   Execution: Dokploy server job SSHs to target → runs script.sh → docker run backup-runner
#   Docker socket mount gives access to host containers for db dumps.
#
# Quality gates: DCQ-1 (no :latest), DCQ-2 (healthcheck), DCQ-3 (no hardcoded secrets)
#
# Registry: registry.svc.friasc.com/carlosfrias/backup-runner
# Tags: 1.0.0, latest
# Push:  docker --context=fnet2 buildx build --platform linux/amd64 -t registry.svc.friasc.com/carlosfrias/backup-runner:1.0.0 --push ./backup-runner
#
# Dependencies:
#   - Base: Ubuntu 24.04 LTS (Noble)
#   - ansible-core 2.17, ansible-runner 2.3
#   - Tools: openssh-client, rclone, curl, jq, postgresql-client, mariadb-client
#
# Credentials: Injected at runtime via mount. Never hardcoded in this image.
#
# Architecture: amd64 only (fleet nodes are Intel/AMD)
#   To add arm64: append --platform linux/arm64 and tag with -arm64 suffix

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ── Install runtime dependencies ───────────────────────────────────────────────
# Combined into one layer for efficiency.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Python + build tools for Ansible
        python3 \
        python3-pip \
        python3-dev \
        build-essential \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
        libonig-dev \
        # SSH client for Ansible to connect to fleet nodes
        openssh-client \
        # S3 sync for Wasabi backups
        rclone \
        # HTTP client for healthcheck pings
        curl \
        # JSON processor
        jq \
        # Database CLIs for dumps
        postgresql-client \
        mariadb-client \
        # Archive tools
        bash \
        tar \
        gzip \
        findutils \
    && rm -rf /var/lib/apt/lists/*

# ── Install Ansible ──────────────────────────────────────────────────────────
# ansible-runner not in Ubuntu repos; install via pip.
# --break-system-packages: Ubuntu 24.04 PEP 668 externally-managed-environment
RUN pip3 install --break-system-packages --no-cache-dir --no-build-isolation \
        ansible-core==2.17.* \
        ansible-runner==2.3.* \
        ansible-lint==6.* \
        ansible-navigator==1.* \
    && rm -rf /root/.cache/pip/*

# ── Copy entrypoint ──────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Healthcheck ──────────────────────────────────────────────────────────────
# DCQ-2: Confirms container is functional before serving requests
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /entrypoint.sh healthcheck || exit 1

# ── Runtime configuration ───────────────────────────────────────────────────
WORKDIR /runner
ENTRYPOINT ["/entrypoint.sh"]

# ── Labels ───────────────────────────────────────────────────────────────────
LABEL org.opencontainers.image.title="fleet-control backup-runner"
LABEL org.opencontainers.image.description="Ansible runner for Dokploy server job backups"
LABEL org.opencontainers.image.source="https://github.com/carlosfrias/dokploy-compose-manager"
LABEL org.opencontainers.image.version="1.0.0"
