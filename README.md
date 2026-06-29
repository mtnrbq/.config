# .config

Personal machine setup: Windows Terminal, VS Code, fonts, shell profile, winget packages.

## Setup

Run everything:

```powershell
./run-all.ps1
```

Or individual scripts: `winget-base.ps1`, `Copy-config.ps1`, `install-fonts.ps1`, `set-defaults.ps1`.

## Enable git hooks (required after clone)

Git hooks are not cloned. Hooks live in `.githooks/` and are activated by local config:

```powershell
git config core.hooksPath .githooks
```

`winget-base.ps1` sets this automatically. The `pre-commit` hook forces `user.name`/`user.email`
to match the active `gh` account, and aborts the commit if they don't match (re-run to apply).
