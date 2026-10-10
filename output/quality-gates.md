# Quality Gates — Phase 1 Artifacts

Phase 1 scaffold applies these gates to all Markdown and YAML artifacts.

## Applied Gates

### MD-1: No Hardcoded Paths
**What:** Markdown docs must not contain absolute workspace paths like `$CWD/...`.
**Why:** Paths are environment-specific and break portability.
**How:** Use relative paths or variable references.
**Violation:** Any hardcoded absolute path in a doc → BLOCK.

### MD-2: No AI Slop Callouts
**What:** Markdown docs must not contain reflexive praise, hype, or padding.
**Why:** "Certainly!", "Let me help you", "Here's the comprehensive guide" are filler.
**How:** Direct technical content, no opening or closing flattery.
**Violation:** Phrases like "Certainly!", "Great question!" → WARN.

## Planned Gates (Phase 2)

| Gate | Applies To | When |
|------|-----------|------|
| BQ-1 (set -euo pipefail) | `entrypoint.sh` | Phase 2 |
| BQ-2 (trap EXIT) | `entrypoint.sh` | Phase 2 |
| DCQ-1 (no :latest) | `Dockerfile` | Phase 2 |
| DCQ-2 (healthcheck) | `Dockerfile` | Phase 2 |
| DCQ-3 (no hardcoded secrets) | `Dockerfile` | Phase 2 |
| AQ-1 (ansible-lint) | Playbook library | Phase 2 |
| APIQ-1 (idempotency first) | SKILL.md MCP calls | Applied |

## Phase 1 Result

- Artifacts: 6 (AGENTS.md, README.md, agents/dokploy-compose-manager.md, skills/dokploy-compose-manager/SKILL.md, QUALITY-METRICS.md, output/quality-gates.md)
- Quality gates applied: MD-1, MD-2
- Violations found: 0
- Phase 2 TODOs: backup-runner Dockerfile, Ansible playbook library, rclone credential injection
