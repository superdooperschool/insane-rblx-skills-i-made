# INSTALL (written for Claude Code)

You are installing this repo for the user. Follow these steps in order. Stop and report on the first failure. Do not change anything outside `~/.claude` and the Claude Code MCP config.

## 1. Prerequisites

Run these and report any that fail:

```
node --version
claude --version
```

- Node must be 18 or newer. If it is missing or older, tell the user to install the current Node LTS from nodejs.org, then stop.
- On Windows, check that Roblox Studio's MCP launcher exists: `%LOCALAPPDATA%\Roblox\mcp.bat`. If it does not, tell the user to update Roblox Studio and open it once. The skills still install without it, but the `rbx` MCP will not connect.
- Not on Windows: the `rbx` MCP is Windows-only. Use `node install.mjs --no-mcp` in step 2.

## 2. Run the installer

From the root of this repo:

```
node install.mjs
```

It does three things and prints a line for each:

1. Copies the 20 skills in `skills/` to `~/.claude/skills/`. A skill with the same name that this repo did not install is moved to `~/.claude/skills-backup/`, never deleted.
2. Writes the Roblox rules from `CLAUDE.roblox.md` into `~/.claude/CLAUDE.md` between `insane-rblx` markers (a `CLAUDE.md.bak-<time>` copy is made first).
3. Runs `skills/rbx/setup.mjs`, which registers the `rbx` MCP and removes Roblox's stock `Roblox_Studio` server.

## 3. Read the output

Lines starting `ok` or `->` are fine. Lines starting `!!` need attention: show them to the user with what you think is wrong. The last line should say `All good.`

## 4. Verify

Tell the user to restart Claude Code, open Roblox Studio with a place, and then run:

```
node ~/.claude/skills/rbx/rbx.mjs health
```

It prints the port, the number of Studios, and the open place. `(NO PLACE OPEN)` means Studio is running with no place active. `StudioMCP.exe is not running` means Studio is closed.

## 5. Finish

- Keep the cloned repo. Updating is `git pull` then `node install.mjs`.
- Uninstalling is `node install.mjs --uninstall`.
- Tell the user, in two lines, what changed: skills added, rules block added to `CLAUDE.md`, `rbx` MCP registered in place of the stock one.
