# Async Operations

Operations that run **in the background** — fire-and-forget, timers, or event-driven.
The caller continues without waiting for completion.

---

## nixos-upgrade (GitOps auto-apply)

**Module:** `modules/auto-upgrade.nix`

```nix
system.autoUpgrade = {
  enable  = true;
  flake   = "git+ssh://git@github.com/AbstractBike/nixos#homelab";
  dates   = "*:0/1";   # every 1 minute
};
```

- Runs as a systemd timer (`nixos-upgrade.timer`) every minute
- Fetches latest commit from GitHub (deploy key: `/root/.ssh/deploy_nixos`)
- If the flake hash changed → builds + activates the new generation
- If GitHub is unreachable → falls back to local nix cache (silent skip)
- Does NOT reboot (`allowReboot = false`)

## Alertmanager → Fanout (async notification dispatch)

After `group_wait` expires, Alertmanager dispatches notifications concurrently:

```
alert firing
  ├─ (async) telegram_configs → Telegram Bot API
  └─ (async) webhook_configs  → alertmanager-matrix-webhook:9095
                                   └─ (async) Matrix room send
```

Neither delivery is awaited by the other. Failures trigger retries independently.

## Vector Telemetry Pipeline

**Config:** `~/git/home/config/vector.toml`

All pipelines are async stream-processing:

| Source | Destination | Trigger |
|--------|-------------|---------|
| `claude_statusline` (port 9196) | VictoriaLogs | every prompt (push from statusline.sh) |
| `claude_statusline_metrics` | VictoriaMetrics | every prompt (log_to_metric) |
| `journald` | VictoriaLogs | continuous tail |
| `file_logs` | VictoriaLogs | inotify-based tail |
| `host_metrics` | VictoriaMetrics | every 15 s |
| `scrape_node` | VictoriaMetrics | every 30 s |
| `scrape_nvidia` | VictoriaMetrics | every 15 s |
| `scrape_processes` | VictoriaMetrics | every 30 s |
| `scrape_serena` | VictoriaMetrics | every 30 s |
| `scrape_intellij_jmx` | VictoriaMetrics | every 30 s |
| `internal_metrics` | VictoriaMetrics | continuous |

## statusline.sh Background Pushes

**File:** `~/.claude/config/scripts/statusline.sh`

Called on every Claude Code prompt. Two async curl calls fire in background subshells:

```bash
_vm_push_bg()  # rate-limited 60 s  → VictoriaMetrics :8428 (prometheus metrics)
_vl_push_bg()  # every prompt       → Vector :9196 (raw JSON → VictoriaLogs)
```

Both are `&`-backgrounded — the statusline renders immediately.

## VictoriaMetrics / VictoriaLogs (vmalert)

**Module:** `modules/vmalert.nix`

- vmalert evaluates MetricsQL rules on a continuous schedule (async loop)
- Alert state changes are pushed to Alertmanager asynchronously

## SkyWalking Rover (eBPF tracing)

**Module:** `modules/skywalking-rover.nix`

- Instruments ALL processes automatically via eBPF — zero app changes
- Spans are streamed asynchronously to SkyWalking OAP (192.168.0.4:11800)

## NixOS VM Tests (`tests/`)

```bash
nix build .#checks.x86_64-linux.<component>
```

Tests spin up QEMU VMs in the background and run assertions.
They are scheduled as Nix build jobs (async, parallelized by Nix).

## Git Post-Receive Hook (planned — MDD verification)

After a successful `nixos-rebuild switch` on `main`, a post-receive hook will:

1. Find marker files in `observability/pending-tests/`
2. Launch headless Claude Code agents per marker (async, one per service)
3. Each agent runs Playwright assertions against Grafana dashboards
4. On success → delete marker, commit `obs: verified <service>`
5. On failure → write `*-FAILED.json` → trigger Alertmanager alert
