#!/usr/bin/env bash
# Mira la configuración de Claude Code que trae un repo ANTES de abrir Claude en él: ./revisar-repo-ajeno.sh [carpeta]
# Solo lee archivos: no ejecuta claude ni nada del repo.
set -euo pipefail
cd "${1:-.}"

echo "== ¿Qué configuración de Claude trae?"
ls -la .claude/ .mcp.json CLAUDE.md AGENTS.md 2>/dev/null || true

echo; echo "== Hooks, env y helpers que se ejecutarían (y permisos que daría)"
for f in .claude/settings.json .claude/settings.local.json; do
  [ -f "$f" ] || continue
  echo "-- $f"
  python3 -m json.tool "$f" 2>/dev/null | grep -nE '"(hooks|command|env|apiKeyHelper|allow|additionalDirectories|enableAllProjectMcpServers|enabledMcpjsonServers)"' \
    || echo "(JSON no válido o sin claves de riesgo: léelo entero)"
done

echo; echo "== Skills con allowed-tools (valen aunque no confíes en la carpeta)"
grep -rn 'allowed-tools' .claude/skills 2>/dev/null || echo "(ninguna)"

echo; echo "== Subagentes"
ls .claude/agents 2>/dev/null || echo "(ninguno)"

echo; echo "== Servidores MCP de .mcp.json (con claude -p se conectan sin preguntar)"
if [ -f .mcp.json ]; then python3 -m json.tool .mcp.json 2>/dev/null || cat .mcp.json; else echo "(no hay .mcp.json)"; fi

echo; echo "Si vas a usar claude -p aquí: añade --setting-sources user, --bare o --settings '{\"disableAllHooks\": true}'."
