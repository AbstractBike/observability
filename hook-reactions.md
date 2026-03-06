# Hook Reactions

Automated reactions to events — what triggers what in the homelab.

---

## Git Hooks

### `pre-push` (homelab repo)

**File:** `scripts/pre-push` → install at `.git/hooks/pre-push`

| Trigger | Reaction |
|---------|----------|
| `git push` on homelab repo | Runs `nix flake check --no-build` |
| Flake check fails | Push **blocked**, error shown |
| Flake check passes | Push proceeds |

```bash
# Install:
cp scripts/pre-push .git/hooks/pre-push && chmod +x .git/hooks/pre-push
```

---

## systemd Service Reactions

### Secrets-before-service pattern

All secret-rendering services use `Before/WantedBy` to react to service start:

| Trigger | Reaction |
|---------|----------|
| `alertmanager.service` requested | `alertmanager-env-render` runs first (renders `/run/alertmanager-secrets.env`) |
| `alertmanager-matrix-webhook` requested | `alertmanager-matrix-env-render` runs first (renders `/run/alertmanager-matrix.env`) |
| `matrix-synapse.service` requested | `matrix-synapse-extra-config` runs first (renders `/run/matrix-synapse-extra.yaml`) |

### NixOS Activation (`nixos-rebuild switch`)

| Trigger | Reaction |
|---------|----------|
| New generation activated | `switch-to-configuration switch` diffs unit files |
| Unit changed | `systemctl daemon-reload` + service restart |
| Unit removed | Service stopped |
| New unit added | Service started for first time |
| SOPS secrets changed | Dependent services restarted (via `restartTriggers`) |

### Auto-Upgrade Timer

| Trigger | Reaction |
|---------|----------|
| Every 1 minute (`*:0/1`) | `nixos-upgrade-start` runs `nixos-rebuild switch --flake .#homelab` |
| Flake hash unchanged | No-op (nix build cache hit) |
| New commit on `main` + build success | `switch-to-configuration` activates new generation |
| Build or switch failure | System stays on current generation, error in journal |
| GitHub unreachable | Falls back to local nix cache, skips upgrade |

---

## Alertmanager Reactions

### Alert Routing

| Trigger | Reaction |
|---------|----------|
| Alert fires with `severity: none` | Routed to `blackhole` receiver (silenced) |
| Alert fires (any other severity) | Routed to `fanout` receiver |
| `fanout` triggered | **Concurrently:** Telegram bot message + Matrix room message |
| Alert resolves | `send_resolved: true` — both channels receive resolution |
| Telegram delivery fails | Alertmanager retries with exponential backoff |
| Matrix webhook `POST /` fails | Alertmanager retries, error logged in `alertmanager-matrix-webhook` journal |

### inhibit_rules

| Trigger | Reaction |
|---------|----------|
| `severity: critical` fires for `alertname: X` | Suppresses matching `severity: warning` for same `alertname` |

---

## Vector Pipeline Reactions

| Trigger | Reaction |
|---------|----------|
| `claude_statusline` receives POST on `:9196` | JSON parsed → logs branch → VictoriaLogs; metrics branch → VictoriaMetrics |
| New log line appended to `/var/log/*.log` | Tailed, shipped to VictoriaLogs |
| Journald entry written | Shipped to VictoriaLogs |
| prometheus `/metrics` endpoint scraped | Metrics forwarded to VictoriaMetrics |
| OTLP span received (`:4317`/`:4318`) | Metrics/logs forwarded; traces dropped (blackhole sink) |

---

## vmalert Reactions

| Trigger | Reaction |
|---------|----------|
| MetricsQL rule threshold breached | Alert sent to Alertmanager |
| Alert resolves (metric back to normal) | Resolution sent to Alertmanager |

---

## Claude Code Hooks (heater workstation)

**File:** `~/.claude/settings.json`

| Event | Hook | Reaction |
|-------|------|----------|
| Prompt submitted | `statusline.sh` | Renders 2-line ANSI status bar + async push to Vector `:9196` + VictoriaMetrics `:8428` |

**Planned (MDD verification system):**

| Event | Hook | Reaction |
|-------|------|----------|
| `git commit` (nixos/home repo) | `pre-commit` | Blocks commit if `[PENDING]` pattern found without `~/.rebuild-pending` sentinel |
| `nixos-rebuild switch` success | post-switch wrapper (`nrs`) | Creates `~/.rebuild-pending` sentinel; clears after successful rebuild |
| homelab repo `main` receives commit | `post-receive` | Scans `observability/pending-tests/*.json`; launches headless Claude agent per marker |
| Headless agent: Playwright assertions pass | agent script | Deletes marker file, commits `obs: verified <service>` |
| Headless agent: Playwright assertions fail | agent script | Writes `*-FAILED.json`, sends Alertmanager alert → Telegram + Matrix |

---

## Summary Diagram

```
git push (homelab)
  └─ pre-push hook
       └─ nix flake check  ──fail──► push blocked
                           ──pass──► push proceeds
                                       └─ nixos-upgrade.timer (every 1 min)
                                            └─ nixos-rebuild switch
                                                 └─ switch-to-configuration
                                                      ├─ matrix-synapse-extra-config (oneshot)
                                                      │    └─ matrix-synapse.service starts
                                                      ├─ alertmanager-env-render (oneshot)
                                                      │    └─ alertmanager.service starts
                                                      └─ alertmanager-matrix-env-render (oneshot)
                                                           └─ alertmanager-matrix-webhook starts

alert fires
  └─ vmalert or Alertmanager API POST
       └─ group_wait: 30s
            └─ fanout receiver (parallel)
                 ├─ telegram_configs ──► Telegram
                 └─ webhook_configs ──► alertmanager-matrix-webhook:9095
                                             └─ Matrix room message

Claude Code prompt
  └─ statusline.sh
       ├─ (bg) curl POST :9196  ──► Vector ──► VictoriaLogs
       └─ (bg, rate-limited 60s) prometheus push ──► VictoriaMetrics
```
