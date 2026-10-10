# Quality Metrics — dokploy-compose-manager Phase 1

## Applied Gates

| Gate | Applied To | Status |
|------|-----------|--------|
| MD-1 (no hardcoded paths) | All Markdown artifacts | ✅ Pass |
| MD-2 (no AI slop callouts) | All Markdown artifacts | ✅ Pass |
| APIQ-1 (idempotency first) | SKILL.md §10, agent config | ✅ Pass |

## Violations Log

See `.quality-violations.jsonl` for the full violation log. Zero violations in Phase 1.

## Phase 2 Planned Gates

| Gate | Applies To | When |
|------|-----------|------|
| BQ-1 (set -euo pipefail) | `entrypoint.sh` | Phase 2 |
| BQ-2 (trap EXIT) | `entrypoint.sh` | Phase 2 |
| DCQ-1 (no :latest) | `Dockerfile` | Phase 2 |
| DCQ-2 (healthcheck) | `Dockerfile` | Phase 2 |
| DCQ-3 (no hardcoded secrets) | `Dockerfile` | Phase 2 |
| AQ-1 (ansible-lint) | Playbook library | Phase 2 |

## Artifacts

- Phase 1: 4 artifacts (AGENTS.md, README.md, agents/config, SKILL.md)
- Phase 2: backup-runner Dockerfile + entrypoint.sh + Ansible playbooks
- Phase 3: Actual service registrations via compose-manager

## Quality Contract

Phase 1 establishes the contract: every registration artifact must pass MD-1, MD-2, and APIQ-1 before being committed. Phase 2 adds BQ-1, BQ-2, DCQ-1, DCQ-2, DCQ-3, AQ-1.
