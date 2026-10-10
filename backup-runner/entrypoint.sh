#!/usr/bin/env bash
# backup-runner entrypoint — Ansible runner for Dokploy server jobs
#
# BQ-1: set -euo pipefail — strict error handling
# BQ-2: trap EXIT — cleanup and exit reporting
#
# Usage:
#   docker run --rm registry.svc.friasc.com/carlosfrias/backup-runner:latest /entrypoint.sh <service>
#   docker run --rm registry.svc.friasc.com/carlosfrias/backup-runner:latest /entrypoint.sh healthcheck
#
# Environment (injected by Dokploy server job):
#   ANSIBLE_HOST_KEY_CHECKING=no
#   ANSIBLE_PRIVATE_KEY_FILE=/root/.ssh/id_rsa
#   ANSIBLE_SCP_IF_SSH=y
#
# Mounts (provided by Dokploy server job):
#   -v /var/run/docker.sock:/var/run/docker.sock   # host Docker socket
#   -v ~/.ssh:/root/.ssh:ro                       # SSH keys for fleet access
#
# Arguments:
#   $1 = service name (authentik, nextcloud, semaphore, windmill, supabase, etc.)

set -euo pipefail

# ── Exit trap ────────────────────────────────────────────────────────────────
# Reports exit code on failure. Runs after any exit (error, SIGINT, etc.)
EXIT_CODE=0
trap 'EXIT_CODE=$?; on_exit' EXIT

on_exit() {
    if [[ "${EXIT_CODE}" -eq 0 ]]; then
        echo "✅ backup-runner completed successfully"
    else
        echo "❌ backup-runner failed with exit code: ${EXIT_CODE}" >&2
    fi
}

# ── Constants ───────────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="1.0.0"
readonly PLAYBOOKS_DIR="/runner/playbooks"
readonly INVENTORY_FILE="/runner/inventory.yml"

# ── Logging ────────────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [${level}] $*"
}

info()  { log "INFO" "$@"; }
error() { log "ERROR" "$@" >&2; }
fatal() { error "$@"; exit 1; }

# ── Healthcheck mode ───────────────────────────────────────────────────────
# Used by Docker HEALTHCHECK to verify the container is functional.
healthcheck() {
    # Verify key tools are available
    local missing=()
    for tool in ansible-playbook ssh rclone curl jq psql mysql tar gzip; do
        command -v "${tool}" >/dev/null 2>&1 || missing+=("${tool}")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing tools: ${missing[*]}"
        return 1
    fi

    # Verify ansible-playbook is functional
    if ! ansible-playbook --version >/dev/null 2>&1; then
        error "ansible-playbook not functional"
        return 1
    fi

    # Verify SSH can reach at least one fleet node
    # (fnet2 Dokploy primary — will fail auth without keys, but connection works)
    if timeout 5 ssh -F /dev/null -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        friasc@192.168.0.142 'echo pong' >/dev/null 2>&1; then
        info "SSH connectivity: OK"
    else
        info "SSH connectivity: no auth (expected without keys mounted)"
    fi

    info "healthcheck passed — container is functional"
    return 0
}

# ── Validate environment ────────────────────────────────────────────────────
validate_environment() {
    info "backup-runner v${SCRIPT_VERSION} starting"
    info "Service: ${SERVICE:-none}"
    info "Docker socket: $(test -S /var/run/docker.sock && echo 'accessible' || echo 'NOT FOUND')"

    # Verify Docker socket is mounted (needed for db dumps via docker exec)
    if [[ ! -S /var/run/docker.sock ]]; then
        fatal "Docker socket not mounted at /var/run/docker.sock"
    fi

    # Verify SSH keys are mounted
    if [[ ! -d /root/.ssh ]] || [[ -z "$(ls -A /root/.ssh/ 2>/dev/null)" ]]; then
        fatal "SSH keys not mounted at /root/.ssh"
    fi

    # Set Ansible defaults
    export ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING:-no}"
    export ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE:-/root/.ssh/id_rsa}"
    export ANSIBLE_SCP_IF_SSH="${ANSIBLE_SCP_IF_SSH:-y}"
    # Skip SSH config file to avoid permission/ownership issues when mounted from host
    export ANSIBLE_SSH_ARGS="${ANSIBLE_SSH_ARGS:--F /dev/null}"
    export PYTHONUNBUFFERED=1

    info "Environment validated"
}

# ── Run playbook ───────────────────────────────────────────────────────────
run_playbook() {
    local service="$1"
    local playbook="${PLAYBOOKS_DIR}/backup-${service}.yml"

    if [[ ! -f "${playbook}" ]]; then
        fatal "Playbook not found: ${playbook}"
    fi

    info "Running playbook: ${playbook}"

    # Build ansible-playbook command
    # Inventory is optional — playbooks may use constructed inventory or host patterns
    local cmd=(ansible-playbook "${playbook}")
    [[ -f "${INVENTORY_FILE}" ]] && cmd+=(-i "${INVENTORY_FILE}")

    # Run with verbose output on failure
    if ! "${cmd[@]}"; then
        error "Playbook failed: ${service}"
        return 1
    fi

    info "Playbook completed: ${service}"
    return 0
}

# ── Idle mode (sleep forever) ────────────────────────────────────────────────────
# Used by backup-jobs compose containers that wait for docker exec from Dokploy schedules.
idle() {
    info "Idle mode — sleeping forever until docker exec"
    # Block forever. docker exec <container> /entrypoint.sh <service>
    # will interrupt the sleep and invoke main with $1 = service name.
    sleep infinity
}

# ── Main ──────────────────────────────────────────────────────────────────
main() {
    local command="${1:-}"

    case "${command}" in
        healthcheck)
            healthcheck
            ;;
        infinity|sleep)
            idle
            ;;
        "")
            fatal "No command specified. Usage: /entrypoint.sh <service|healthcheck|infinity>"
            ;;
        *)
            SERVICE="${command}"
            validate_environment
            run_playbook "${command}"
            ;;
    esac
}

main "$@"
