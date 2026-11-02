# Antes de darle permisos a Claude Code: checklist de seguridad (Ctrl+IA)

Diez comprobaciones para hacer antes de darle más permisos a Claude Code o de abrirlo en un repositorio que no es tuyo: modos, quién gana entre deny, ask y allow, qué aplica un proyecto antes de que confíes en la carpeta, sandbox y cómo cerrarte la puerta del modo bypass.

Página completa: https://ctrlia.dev/recetas/checklist-permisos-claude-code.html (English: https://ctrlia.dev/en/recetas/checklist-permisos-claude-code.html)

English version: [README.en.md](README.en.md) (archivos en `en/`).

## Qué trae
| Archivo | Para qué |
| --- | --- |
| `checklist.md` / `en/checklist.md` | La lista para imprimir o marcar, con el porqué y cómo comprobar cada punto |
| `revisar-repo-ajeno.sh` | Muestra la configuración de Claude que trae un repo (hooks, env, allow, skills con allowed-tools, `.mcp.json`) **sin ejecutar nada** |
| `ejemplos/settings-usuario.json` | Candados personales para `~/.claude/settings.json`: sin bypass, sin escrituras fuera de la carpeta, deny a `~/.ssh`, `~/.aws` y `~/.config/gh` |
| `ejemplos/sandbox-red-cerrada.json` | Sandbox con la red cerrada salvo GitHub y npm |

## Cómo usarlo
```bash
./revisar-repo-ajeno.sh ~/ruta/al/repo-clonado
```
Para los JSON de ejemplo, copia las claves que quieras en tu `~/.claude/settings.json` (no lo sobrescribas entero) y valídalo con `python3 -m json.tool ~/.claude/settings.json`. El sandbox necesita en Linux `bubblewrap` y `socat`.

Si vas a usar `claude -p` en un repo ajeno, añade `--setting-sources user`, `--bare` o `--settings '{"disableAllHooks": true}'`: sin eso sus hooks se ejecutan aunque nunca hayas confiado en la carpeta.

## Probado
Con Claude Code 2.1.316 en Linux, con configuración aislada: el aviso de reglas allow sin confianza, un hook de proyecto que se ejecuta con `claude -p` sin confianza y las tres opciones que lo evitan, y `revisar-repo-ajeno.sh` sobre un repo de prueba, una carpeta vacía y un JSON roto. El sandbox de red y los ajustes `disableBypassPermissionsMode` y `blockWritesOutsideWorkingDirectories` en una sesión real no se probaron (ver la página).

## Licencia
MIT. Copyright (c) 2026 Ctrl+IA (Carlos P.).
