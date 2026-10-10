# backup-runner — Ansible runner image for Dokploy server jobs
#
# Purpose: Runs Ansible playbooks inside Dokploy's schedule execution context.
#   Called by: docker run --rm ghcr.io/carlosfrias/backup-runner:latest /entrypoint.sh <service>
#   Execution: Dokploy server job SSHs to target → runs script.sh → docker run backup-runner
#   Docker socket mount gives access to host containers for db dumps.
#
# Quality gates: DCQ-1 (no :latest), DCQ-2 (healthcheck), DCQ-3 (no hardcoded secrets)
#
# Image: ghcr.io/carlosfrias/backup-runner
# Tag: versioned (e.g., 1.0.0), NOT latest
#
# Dependencies:
#   - Base: Ubuntu 24.04 LTS (Noble) — clean, well-maintained repos
#   - Python + pip for ansible-runner
#   - Collections: ansible/ansible, ansible/posix, community/general, community/docker
#   - Tools: openssh-client, rclone, curl, jq, postgresql-client, mariadb-client
#
# Credentials: Injected at runtime via mounted pass store and rclone config.
#   Never hardcoded in this image.
#
# Architecture: amd64 (Intel/AMD), arm64 (Apple Silicon)
# Multi-arch: docker buildx (see .github/workflows/build.yml)

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG BACKUP_RUNNER_VERSION=1.0.0
ENV BACKUP_RUNNER_VERSION=${BACKUP_RUNNER_VERSION}

# ── Prevent interactive prompts ───────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# ── Install Python and Ansible Runner ────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        # Build tools for compiling Python C extensions
        build-essential \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
        libonig-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages --no-cache-dir --no-build-isolation \
        ansible-core==2.17.* \
        ansible-runner==2.3.* \
        ansible-lint==6.* \
        ansible-navigator==1.* \
    && rm -rf /root/.cache/pip/*

# ── Install runtime dependencies ───────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # SSH client for Ansible SSH connections to fleet nodes
        openssh-client \
        # S3 sync tool for Wasabi backups
        rclone \
        # HTTP client for healthcheck pings
        curl \
        # JSON processor for parsing backup output
        jq \
        # PostgreSQL CLI for pg_dump
        postgresql-client \
        # MySQL CLI for mysqldump
        mariadb-client \
        # bash for entrypoint script
        bash \
        # tar for volume archiving
        tar \
        # gzip for compression
        gzip \
        # findutils for xargs, find
        findutils \
    && rm -rf /var/lib/apt/lists/*

# ── Copy entrypoint ──────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Healthcheck ──────────────────────────────────────────────────────────────
# DCQ-2: Healthcheck confirms the container is functional
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /entrypoint.sh healthcheck || exit 1

# ── Runtime configuration ───────────────────────────────────────────────────
WORKDIR /runner
ENTRYPOINT ["/entrypoint.sh"]

# ── Labels ───────────────────────────────────────────────────────────────────
LABEL org.opencontainers.image.title="fleet-control backup-runner"
LABEL org.opencontainers.image.description="Ansible runner for Dokploy server job backups"
LABEL org.opencontainers.image.source="https://github.com/carlosfrias/dokploy-compose-manager"
LABEL org.opencontainers.image.version="${BACKUP_RUNNER_VERSION:-1.0.0}"
