# Before you give Claude Code permissions: a security checklist (Ctrl+IA)

Ten checks to run before giving Claude Code more permissions or opening it in a repository that isn't yours: modes, which wins between deny, ask and allow, what a project applies before you trust the folder, the sandbox and how to lock yourself out of bypass mode. Scripts and messages are in Spanish.

Full page: https://ctrlia.dev/en/recetas/checklist-permisos-claude-code.html (Español: https://ctrlia.dev/recetas/checklist-permisos-claude-code.html)

## What's inside
| File | What for |
| --- | --- |
| `checklist.en.md` / `checklist.md` | The list to print or tick, with the why and how to check each item |
| `revisar-repo-ajeno.sh` | Shows the Claude configuration a repo brings (hooks, env, allow, skills with allowed-tools, `.mcp.json`) **without running anything** |
| `ejemplos/settings-usuario.json` | Personal locks for `~/.claude/settings.json`: no bypass, no writes outside the folder, deny for `~/.ssh`, `~/.aws` and `~/.config/gh` |
| `ejemplos/sandbox-red-cerrada.json` | Sandbox with the network closed except GitHub and npm |

## How to use it
```bash
./revisar-repo-ajeno.sh ~/path/to/cloned-repo
```
For the sample JSON files, copy the keys you want into your `~/.claude/settings.json` (don't overwrite the whole file) and validate it with `python3 -m json.tool ~/.claude/settings.json`. On Linux the sandbox needs `bubblewrap` and `socat`.

If you're going to use `claude -p` in someone else's repo, add `--setting-sources user`, `--bare` or `--settings '{"disableAllHooks": true}'`: without that, its hooks run even if you never trusted the folder.

## Tested
With Claude Code 2.1.316 on Linux, with an isolated configuration: the untrusted allow rules warning, a project hook that runs with `claude -p` without trust and the three options that prevent it, and `revisar-repo-ajeno.sh` on a test repo, an empty folder and broken JSON. The network sandbox and the `disableBypassPermissionsMode` and `blockWritesOutsideWorkingDirectories` settings in a real session weren't tested (see the page).

## License
MIT. Copyright (c) 2026 Ctrl+IA (Carlos P.).
