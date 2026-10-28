---
name: peon-ping-connect
description: Connect the agent you are running in (any harness - Claude Code, Codex, ChatGPT desktop Coding, Gemini CLI, Cursor, a local or custom agent) to an existing peon-ping install so its lifecycle events play sounds. Use when the user asks to hook up, wire, connect, or set up peon-ping sounds for this agent.
user-invocable: true
---

# peon-ping-connect

Wire the harness you are running in to an already-installed peon-ping. Work through the steps in order. Do not reinstall peon-ping unless step 1 finds nothing.

## 1. Find the install folder

Use the first that contains `peon.ps1` (Windows) or `peon.sh` (macOS, Linux, WSL):

1. `$CLAUDE_PEON_DIR` (set by a portable install, e.g. `install.ps1 -InstallDir <folder>`)
2. `~/.claude/hooks/peon-ping`
3. `~/.openpeon/hooks/peon-ping`

Call it `<PEON>` below and always write it as an absolute path in configs. If none exists, tell the user to run the installer first and stop.

## 2. Pick the connection method for this harness

Identify which harness you are (product name and its config folder, e.g. `~/.codex`, `~/.gemini`). Then use the first method that fits:

**A. Auto-registered harnesses** - Claude Code, OpenAI Codex (including the Codex hooks shown in the ChatGPT desktop app under Settings > Coding > Hooks), GitHub Copilot CLI, Grok Build, Cursor. Re-run the installer from the peon-ping repo; it detects these config folders and registers hooks:
- Windows: `powershell -File install.ps1 -InstallDir "<PEON>"` (omit `-InstallDir` for the default location)
- Unix: `bash install.sh`

**B. Harness with a bundled adapter** - look for `<PEON>/adapters/<harness>.ps1` (Windows) or `.sh` (Unix): amp, antigravity, deepagents, eca, gemini, iflow, kimi, kiro, kiro-ide, openclaw, opencode, kilo, qwen, trae, windsurf, rovodev, omp. Read the comment header of that adapter file: it says which events to hook and how. Register those hooks in the harness's own config with the command:
- Windows: `powershell -NoProfile -NonInteractive -File "<PEON>\adapters\<harness>.ps1"`
- Unix: `bash "<PEON>/adapters/<harness>.sh"`

**C. Any other harness that can run a command on lifecycle events** (custom agents, local LLM runners, scripts). Map its events to a category and register a command that calls the generic adapter:

| When the agent... | Category |
|---|---|
| starts a session | `session.start` |
| finishes a turn / task | `task.complete` |
| needs approval or input | `input.required` |
| hits a failed tool or command | `task.error` |
| is about to compact context / hits a limit | `resource.limit` |
| starts a subagent / acknowledges a task | `task.acknowledge` |

- Windows: `powershell -NoProfile -NonInteractive -File "<PEON>\adapters\emit.ps1" task.complete`
- Unix: `bash "<PEON>/adapters/emit.sh" task.complete`

Optional flags: `-SessionId` / `--session-id` (keeps per-session pack rotation), `-Message` / `--message` (shown in the desktop notification).

**D. Harness with MCP but no hooks** - register the MCP server so the agent can call `play_sound` itself. It needs Node.js 18+; run `npm install` once in `<PEON>/mcp`, then add a server entry with command `node` and argument `<PEON>/mcp/peon-mcp.js`.

**E. Neither hooks nor MCP** (for example a chat in a web browser) - it cannot trigger sounds. Tell the user so.

## 3. Edit configs safely

- Back up any config file before changing it (copy to `<file>.bak`).
- Merge into existing hook lists. Never replace other hooks the user already has.
- Keep the harness's own config format (JSON, TOML, YAML) valid.

## 4. Test

Run `emit` once for `task.complete` from a shell (method C command) and ask the user whether they heard it. Then trigger a real turn in the harness. If nothing plays, set `PEON_DEBUG=1` and check `<PEON>/logs`.

Tell the user which file you changed and how to undo it.
