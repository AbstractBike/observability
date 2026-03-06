# Sync Operations

Operations that **block the caller** until completion.
These run in the foreground and must succeed before the next step.

---

## NixOS Rebuild Pipeline

```
Edit .nix file
  → nix flake check           # validates all modules (blocks)
  → nix build .#homelab       # builds system closure (blocks)
  → git commit && git push    # version-controls the change
  → nixos-rebuild switch      # activates on host (blocks)
     └─ switch-to-configuration switch  # restarts affected services
```

## Service Boot Order (systemd `Before`/`After`)

These chains block service start until dependencies are ready:

| Service | Blocks | Waits for |
|---------|--------|-----------|
| `alertmanager-env-render` | `alertmanager.service` | SOPS secrets decrypted |
| `alertmanager-matrix-env-render` | `alertmanager-matrix-webhook` | SOPS secrets decrypted |
| `matrix-synapse-extra-config` | `matrix-synapse.service` | SOPS secrets decrypted |
| `alertmanager.service` | — | `alertmanager-env-render` |
| `alertmanager-matrix-webhook` | — | `alertmanager-matrix-env-render` |
| `matrix-synapse.service` | — | `matrix-synapse-extra-config` |
| `prometheus-elasticsearch-exporter` | — | `elasticsearch.service` |
| `temporal-setup.service` | `temporal.service` | schema migration done |

## Git Pre-Push Hook (`scripts/pre-push`)

Runs `nix flake check --no-build` — **blocks push** if any module fails evaluation.

```bash
# Install it once:
cp scripts/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

## SOPS Secret Decryption

At NixOS activation time, `sops-nix` decrypts secrets synchronously.
Services that depend on those secrets are held via `After=` until done.

## Alert Routing (Alertmanager `group_wait`)

Alertmanager batches alerts for 30 s (`group_wait`) before dispatching —
the first notification is *synchronously delayed* to allow grouping.

## Manual Steps (human-in-the-loop sync)

| Step | When |
|------|------|
| `sops --set '["key"] "value"'` | Adding a new secret |
| `register_new_matrix_user` | Creating a Matrix bot account |
| `nixos-rebuild switch --rollback` | Emergency rollback |
| `git revert && push` | GitOps rollback |
