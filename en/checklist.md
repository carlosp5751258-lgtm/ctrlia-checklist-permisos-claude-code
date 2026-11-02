# Before you give Claude Code permissions: a security checklist


- [ ] **1. Know which mode you start in.**
  - Why: the mode decides what gets approved without asking you. Since version 2.1.283, if your account and model support it, interactive sessions in the terminal and in VS Code start in **auto**: a separate classifier reviews commands and network requests in the background and blocks what it considers dangerous. It's convenient, but it isn't "risk-free": the classifier decides for you. In **Manual** mode (`default`), Claude Code asks for permission the first time it uses each tool, except for a fixed set of read-only commands (`ls`, `cat`, `git status`…).
  - How to check it: look at the mode indicator at the bottom of the terminal and change it with `Shift+Tab`. To set a different starting mode, put `permissions.defaultMode` in `~/.claude/settings.json`, or start with `claude --permission-mode default`. In a project you don't know, start in `plan` or Manual.
  - The order: the starting mode comes from the `--permission-mode` option (or `--dangerously-skip-permissions`), then from `defaultMode` in a settings file and finally from the factory default. The VS Code extension has its own setting, `claudeCode.initialPermissionMode`, and never reads the mode from project settings.
- [ ] **2. Know the four files and which one wins.**
  - Why: the same rule can live in four places and they add up. From highest to lowest priority: your organization's **managed** settings (can't be overridden), **command-line** options, **local** (`.claude/settings.local.json`, just you in this project, out of git), **project** (`.claude/settings.json`, the whole team) and **user** (`~/.claude/settings.json`, you in every project). The allow, ask and deny lists don't overwrite each other across files: they merge.
  - The golden rule: rules are evaluated in the order **deny → ask → allow** and the first match wins, even if another rule is more specific. A deny in any scope blocks even if another scope allows it: a deny in your user file beats a project allow, and vice versa. An allow can't carve an exception out of a deny: with `deny: Bash(aws *)`, `allow: Bash(aws s3 ls)` does nothing. And an ask asks even if there's a more specific allow.
  - How to check it: in the session, `/permissions` shows each rule with the file it comes from, and `/status` shows which settings files were loaded. Put the denies you want everywhere (your `~/.ssh`, `~/.aws`) in your user file: that way no repo can take them away from you.
- [ ] **3. Before you trust a folder, read its .claude/.**
  - Why: when you open `claude` in a new folder, the trust dialog appears. Until you accept it, the **allow** rules and **additionalDirectories** in the project's `.claude/settings.json` don't apply (they grant permissions); deny and ask rules do, because they only restrict. The dialog lists what the folder would grant you. Accept it only after reading it.
  - What almost nobody knows: according to the official table "What runs before you trust a folder", with `claude -p` or the SDK, in a folder you never trusted, Claude Code **does use** the hooks in the project settings, the `env` block, helpers like `apiKeyHelper` and the `allowed-tools` of project skills, and it **connects without asking** to the servers in `.mcp.json`. We checked it on this PC: a SessionStart hook in a test repo created a file with `claude -p` before the CLI even said "Not logged in".
  - How to check it: before launching anything in someone else's repo, look at `.claude/settings.json`, `.claude/settings.local.json`, `.claude/skills/`, `.claude/agents/` and `.mcp.json` (the repository's `revisar-repo-ajeno.sh` script does this without running anything). If you're going to use `claude -p` there, add `--setting-sources user` (doesn't read the project settings or `.mcp.json`), `--bare` (doesn't read the project's hooks, skills, commands, subagents, plugins or servers; the project's `env` still applies) or `--settings '{"disableAllHooks": true}'`. All three prevented the hook in our test. Putting it only in your user settings isn't enough: the project has higher priority.

```bash
# Real test: someone else's repo runs its hook with claude -p (Nov 1, 2026, Claude Code 2.1.316)
# Test repo with a SessionStart hook in .claude/settings.json that touches a file
$ claude -p "say hello" < /dev/null
Ignoring 2 permissions.allow entries from .claude/settings.json: this workspace has not been trusted. ...
Not logged in · Please run /login
$ ls ../HOOK-RAN
../HOOK-RAN          # the hook ran: no trust and no logged-in session

# The three ways to prevent it (the hook did NOT run in any of them):
$ claude -p "say hello" --setting-sources user
$ claude -p "say hello" --bare
$ claude -p "say hello" --settings '{"disableAllHooks": true}'
```

- [ ] **4. If your allow doesn't work, check trust.**
  - Why: it's the most common cause of "Claude keeps asking even though I allowed it in the project". Trust is stored per git repository root (it covers the whole repo except nested repos, such as submodules, which ask for their own). If you start Claude in your home folder, trust lasts only for that session and isn't saved. A `claude -p` never shows the dialog.
  - How to check it: run `claude -p "hello"` or `claude doctor` in the folder. If you see `Ignoring 2 permissions.allow entries from .claude/settings.json: this workspace has not been trusted. Run Claude Code interactively here once and accept the trust dialog, or set projects["…"].hasTrustDialogAccepted: true in …/.claude.json.` on stderr, your project allow rules are on hold.
  - Fix: open `claude` interactively once and accept. Editing `hasTrustDialogAccepted` by hand in `~/.claude.json` is an alternative the docs mention, but only use it on folders you've already reviewed.
  - One more detail: `.claude/settings.local.json` normally applies without trust because it's yours; but if it's tracked in git or `.claude` is a symlink, Claude Code treats it as part of the repository and holds back its rules.
- [ ] **5. Don't put auto or bypass in project settings.**
  - Why: so that a repo can't decide for you how much gets approved automatically, Claude Code ignores `defaultMode: "auto"` and `"bypassPermissions"` when they're in `.claude/settings.json` or `.claude/settings.local.json`. With auto, the factory default is used (not the `defaultMode` in your user file); with bypass, the session starts in Manual. The other modes (`default`, `acceptEdits`, `plan`, `dontAsk`) do apply from the project in the terminal. Cloud sessions also ignore bypass and dontAsk from the files.
  - How to check it: if you set auto in the project and the session starts in Manual with no error, this is why. Move the setting to `~/.claude/settings.json` or use `--permission-mode auto`.
  - And bypass mode: `bypassPermissions` (same as `--dangerously-skip-permissions`) skips the prompts, including writes to protected paths like `.git` and `.claude`. The docs limit it to containers or virtual machines where it can't do harm, and on Linux they recommend not running it as root. Not even in that mode are ask rules, rm deletions of critical paths or `AskUserQuestion` approved automatically.
- [ ] **6. Close the door on bypass (and on auto, if you want).**
  - Why: the most common way to end up in bypass is habit or a copied alias. You can prevent it yourself: `permissions.disableBypassPermissionsMode: "disable"` works from any scope, not only managed settings, and a user can put it in their own file so they can't enter bypass. The same goes for `permissions.disableAutoMode: "disable"` if you'd rather not delegate to the classifier; with it, `auto` disappears from the `Shift+Tab` cycle and a session launched with `--permission-mode auto` starts in Manual.
  - How to check it: add the key to `~/.claude/settings.json`, validate the JSON with `python3 -m json.tool ~/.claude/settings.json` and start `claude --dangerously-skip-permissions`: according to the docs it should no longer enter bypass (we couldn't see it without a logged-in session). In an organization, put it in managed settings, where nobody can remove it.

```json
{
  "permissions": {
    "disableBypassPermissionsMode": "disable"
  }
}
```

- [ ] **7. Blocking curl isn't cutting off the network.**
  - Why: the official docs are clear: `curl` and `wget` aren't auto-approved by default (in Manual they ask like any non-read-only command), and you can put them in `permissions.deny`. But a deny rule matches the command **as written**: `deny: Bash(curl *)` stops `curl https://…` and doesn't stop `/usr/bin/curl https://…`, `sh -c 'curl …'` or a Python script that opens a connection. And allowing only `WebFetch(domain:github.com)` isn't enough either: if Bash is allowed, Claude can use any other network tool.
  - The real barrier is the sandbox: with `/sandbox` (or `sandbox.enabled: true`), Bash commands and their child processes run isolated; on Linux, in a separate network namespace with no way out, reaching only the domains in `sandbox.network.allowedDomains` through a proxy. On Linux and WSL2 it needs `bubblewrap` and `socat` (`sudo apt-get install bubblewrap socat`); on Ubuntu 24.04 or later, AppArmor can stop bubblewrap from starting, and `/sandbox` tells you how to fix it.
  - How to check it: open `/sandbox`; if you only see the Dependencies tab, something is missing. Watch out: if the sandbox can't start, commands run without it by default; set `sandbox.failIfUnavailable: true` if you want Claude Code to refuse to start.
- [ ] **8. Know what stays outside the sandbox.**
  - Why: the sandbox wraps shell commands, not everything else. According to the [sandbox docs](https://code.claude.com/docs/en/sandboxing), these stay outside: the Read, Edit, Write, WebFetch and WebSearch tools (they follow your permission rules: a sandbox `denyRead` doesn't stop Read, and `allowedDomains` doesn't limit WebFetch), **hooks**, **local MCP servers**, plugin monitors, the statusline and `apiKeyHelper` (they run with all your permissions), what you type yourself with `!`, the commands in `excludedCommands` and the unsandboxed retries Claude asks for after a failure.
  - Also: by default the sandbox **can read almost the whole machine**, including `~/.ssh` and `~/.aws/credentials`, and it inherits your environment variables, secrets included.
  - How to check and close it: add `sandbox.filesystem.denyRead` for your credentials and `permissions.deny` with `Read(~/.ssh/**)` and `Read(~/.aws/**)` for the file tools. To stop Claude from asking to run outside, `sandbox.allowUnsandboxedCommands: false` ("Strict sandbox mode" in the Overrides tab). To put everything behind a single barrier, run Claude Code inside a container, a virtual machine or a dev container.

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "network": {
      "allowedDomains": ["github.com", "*.github.com", "registry.npmjs.org"]
    },
    "filesystem": {
      "denyRead": ["~/.ssh", "~/.aws"]
    }
  }
}
```

- [ ] **9. Limit where it can write.**
  - Why: in Manual, Claude Code asks before its file tools read or write outside the folder where you opened it, but a Bash command you approve can write anywhere your user can reach. Since version 2.1.314 there's `permissions.blockWritesOutsideWorkingDirectories`: Write, Edit and NotebookEdit refuse to write outside the working directories **in every mode** (we covered it in [this news item](https://ctrlia.dev/en/novedades/2026-10-30-bloquear-escrituras-fuera.html)). There's also `permissions.blockReadsOutsideWorkingDirectories` (since 2.1.257) for reads, which makes Claude ask even in auto and bypass.
  - How to check it: add it to `~/.claude/settings.json` and ask Claude to edit a file in another folder: according to the docs it should refuse. If you need it to read another repo, add it with `/add-dir` or `--add-dir` instead of loosening everything. Remember that allow rules don't approve writes to protected paths (`.git`, `.claude`…): in Manual and acceptEdits they always ask.
  - For Bash: the barrier is the sandbox again, which by default only allows writes in the working directory, a temp folder and the folders you add.
- [ ] **10. Review what you approved and don't rely on CLAUDE.md for security.**
  - Why: every "Yes, and don't ask again" is saved as an allow rule in `.claude/settings.local.json`. Over time you pile up broad permissions without noticing, and some are equivalent to running anything: `Bash(python3 *)`, `Bash(node *)`, `Bash(bash *)`, `Bash(npx *)` or `Bash(git *)` (the last one includes `git -c core.fsmonitor=…`).
  - How to check it: once a month open `/permissions`, review the rules tab and the auto mode recent denials tab, and delete what you don't need. Replace wildcards with exact commands (`Bash(python3 -m pytest *)` instead of `Bash(python3 *)`).
  - And remember who's in charge: Claude Code enforces the rules, not the model. What you write in CLAUDE.md or in the prompt guides what Claude tries, but it doesn't change what's allowed. If something must always hold, it goes in a deny rule, a [PreToolUse hook](https://ctrlia.dev/en/recetas/hooks-seguridad.html) (a hook that exits with code 2 blocks even with an allow; and an allow returned by the hook doesn't override a deny) or managed settings. Be careful with the **mods** you install: without managed settings or a Team or Enterprise session, a mod can approve a call that a deny rule rejects.

Your personal locks, in a single file that applies to all your projects (`~/.claude/settings.json`):

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "blockWritesOutsideWorkingDirectories": true,
    "deny": [
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/.config/gh/**)"
    ]
  }
}
```

And the review of someone else's repo before opening Claude in it:

```bash
# What Claude configuration does it bring?
ls -la .claude/ .mcp.json CLAUDE.md AGENTS.md 2>/dev/null
# Hooks, env and helpers that would run
python3 -m json.tool .claude/settings.json 2>/dev/null | grep -nE '"(hooks|env|apiKeyHelper|allow|additionalDirectories|enableAllProjectMcpServers)"'
# Skills with allowed-tools (they don't depend on trust)
grep -rn 'allowed-tools' .claude/skills 2>/dev/null
# MCP servers it would ask to connect
claude mcp list   # the ones in .mcp.json show "⏸ Pending approval" until you approve them
```

The repository includes this review as `revisar-repo-ajeno.sh` (it only reads files: instead of `claude mcp list` it prints the `.mcp.json`) plus the two sample JSON files. If you're starting a project from scratch, the [project template](https://ctrlia.dev/en/recetas/plantilla-claude-code.html) already has these permissions in place.

---
Full version, with common mistakes and FAQ: https://ctrlia.dev/en/recetas/checklist-permisos-claude-code.html · Tested with Claude Code 2.1.316 · MIT
