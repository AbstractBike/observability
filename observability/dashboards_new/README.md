# dashboards_new — Auto-provisioned Drop Zone

Any `.jsonnet` or `.json` file placed here is **automatically** compiled/copied into the
Grafana folder **"New"** during the Nix build (`nix build` / `nixos-rebuild switch`).

No manual edits to `nix/dashboards.nix` required.

## Usage

1. Drop your dashboard file here:
   - `.jsonnet` → compiled by `go-jsonnet` using the standard JPATH (grafonnet + xtd + docsonnet)
   - `.json` → copied as-is (Grafana export format)
2. Rebuild: `nixos-rebuild switch --flake ~/git/nixos#homelab` (or just `nix build`)
3. Dashboard appears in Grafana under folder **"New"**

## Naming convention

| File | Grafana dashboard title |
|------|------------------------|
| `my-service.jsonnet` | whatever `title:` is set inside the jsonnet |
| `my-service.json` | whatever `"title"` key is in the JSON |

The output file name (uid) is the basename without extension.

## Promoting a dashboard

Once a dashboard graduates from the drop zone, move it into the appropriate
`observability/dashboards-src/<category>/` subdirectory and add a loop in
`nix/dashboards.nix` if the category is new.

## Notes

- `.gitkeep` keeps this directory tracked in git when empty — do not delete it.
- The `new/` Grafana folder is created automatically if any file exists here.
- `shopt -s nullglob` ensures the loops are skipped silently when the directory is empty.
