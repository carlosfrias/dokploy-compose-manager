#!/bin/sh
# backup-runner startup — Alpine-based
# Modes:
#   (no args)        → idle: tail -f /dev/null
#   --diagnose       → exit 0 if all tools present, exit 1 + list missing
#   <service>        → run playbook for that service

set -euo pipefail

log()  { echo "[$(date -Iseconds)] [INFO] $*" ; }
warn() { echo "[$(date -Iseconds)] [WARN] $*" >&2; }
die()  { echo "[$(date -Iseconds)] [ERROR] $*" >&2; exit 1; }

# ── Tool manifest ────────────────────────────────────────────────────────────
TOOLS="ansible-playbook ssh rsync curl tar gzip pg_dump mysqldump pass gpg jq rclone ansible"

missing_tools() {
    missing=""
    for tool in $TOOLS; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing="$missing $tool"
        fi
    done
    echo "$missing"
}

# ── Diagnose ────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--diagnose" ]; then
    missing=$(missing_tools)
    if [ -n "$missing" ]; then
        echo "MISSING_TOOLS:$missing"
        for t in $missing; do echo "  - $t"; done
        exit 1
    fi
    echo "ALL_TOOLS_PRESENT"
    exit 0
fi

# ── Idle mode ──────────────────────────────────────────────────────────────
if [ $# -eq 0 ] || [ "$1" = "tail" ] || [ "$1" = "idle" ]; then
    log "idle"
    exec tail -f /dev/null
fi

# ── Backup mode ───────────────────────────────────────────────────────────
SERVICE="$1"
PLAYBOOK="/runner/playbooks/backup-${SERVICE}.yml"

missing=$(missing_tools)
if [ -n "$missing" ]; then
    die "missing tools:$missing  (run with --diagnose to see full list)"
fi

if [ ! -f "$PLAYBOOK" ]; then
    die "playbook not found: $PLAYBOOK"
fi

# Pre-import docker to register http+docker:// adapter before Ansible runs
python3 -c "import sys; sys.path.insert(0,'/usr/lib/python3.12/site-packages/'); import docker" 2>/dev/null || true

log "service=$SERVICE playbook=$PLAYBOOK"
exec ansible-playbook "$PLAYBOOK" -e "service=$SERVICE"
