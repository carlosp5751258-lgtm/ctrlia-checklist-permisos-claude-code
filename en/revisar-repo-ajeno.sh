#!/usr/bin/env bash
# Look at the Claude Code configuration a repo brings BEFORE opening Claude in it: ./revisar-repo-ajeno.sh [folder]
# It only reads files: it doesn't run claude or anything from the repo.
set -euo pipefail
cd "${1:-.}"

echo "== What Claude configuration does it bring?"
ls -la .claude/ .mcp.json CLAUDE.md AGENTS.md 2>/dev/null || true

echo; echo "== Hooks, env and helpers that would run (and permissions it would grant)"
for f in .claude/settings.json .claude/settings.local.json; do
  [ -f "$f" ] || continue
  echo "-- $f"
  python3 -m json.tool "$f" 2>/dev/null | grep -nE '"(hooks|command|env|apiKeyHelper|allow|additionalDirectories|enableAllProjectMcpServers|enabledMcpjsonServers)"' \
    || echo "(invalid JSON or no risky keys: read the whole file)"
done

echo; echo "== Skills with allowed-tools (they apply even if you don't trust the folder)"
grep -rn 'allowed-tools' .claude/skills 2>/dev/null || echo "(none)"

echo; echo "== Subagents"
ls .claude/agents 2>/dev/null || echo "(none)"

echo; echo "== MCP servers in .mcp.json (with claude -p they connect without asking)"
if [ -f .mcp.json ]; then python3 -m json.tool .mcp.json 2>/dev/null || cat .mcp.json; else echo "(no .mcp.json)"; fi

echo; echo "If you're going to use claude -p here: add --setting-sources user, --bare or --settings '{\"disableAllHooks\": true}'."
