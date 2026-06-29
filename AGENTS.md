# AGENTS.md

Guidance for AI agents working in this repo. This is a personal machine-setup config
(Windows Terminal, VS Code, fonts, shell profile, winget packages).

## Git identity & commits

- Commits must use the active `gh` account identity. A `.githooks/pre-commit` hook enforces
  this: it sets `user.name`/`user.email` from `gh api user` and aborts on mismatch (re-run to apply).
- Do NOT set a hardcoded git identity. Never use auto-detected `name@hostname` identities.
- Git operations authenticate via `gh auth setup-git` (GitHub CLI is the credential helper).

## Hooks (required after clone)

- Hooks live in `.githooks/` and are activated by local config: `git config core.hooksPath .githooks`.
- `winget-base.ps1` sets this automatically; otherwise run it manually after cloning.

## Setup scripts

- `run-all.ps1` orchestrates: `winget-base.ps1`, `Copy-config.ps1`, `install-fonts.ps1`, `set-defaults.ps1`.
- Scripts are Windows-only and exit early on non-Windows.
- `set-defaults.ps1` deep-merges JSON; `schemes`/`themes` must stay arrays — use `System.Text.Json`,
  not `ConvertTo-Json` (it collapses 1-element arrays into objects).
- `install-fonts.ps1` installs system-wide (HKLM + C:\Windows\Fonts), self-elevates via `gsudo`.

## Conventions

- Keep changes minimal and scoped; don't add unrequested files or refactors.
- Don't create markdown docs unless asked.
