# insane-rblx-skills-i-made

Turn Claude Code into a Roblox Studio specialist.

A drop-in kit of 20 skills plus a faster Studio MCP, built while shipping real Roblox games with Claude Code. Install it once and your Claude edits scripts with verified writes, builds UI in a consistent style, sculpts terrain from a spec, audits remotes for exploits, and checks its own work before it says "done".

## Install (the easy way)

Open Claude Code and paste this:

> Install https://github.com/superdooperschool/insane-rblx-skills-i-made for me. Clone it, read INSTALL.md, and follow it.

Claude clones the repo, runs the installer, and tells you what to do next.

## Install (by hand)

```
git clone https://github.com/superdooperschool/insane-rblx-skills-i-made
cd insane-rblx-skills-i-made
node install.mjs
```

Then restart Claude Code, open Roblox Studio with a place, and ask Claude: `run rbx health`. You should see the port, the Studio, and your open place.

**You need:** Node 18+, Claude Code (the `claude` CLI), and for the `rbx` MCP: Windows with Roblox Studio (its built-in MCP server lives at `%LOCALAPPDATA%\Roblox\mcp.bat`). On macOS or Linux you can still install the skills and rules with `node install.mjs --no-mcp`.

To update later: `git pull` and `node install.mjs` again.

## What you get

### `rbx`: a faster Studio MCP

Roblox's Studio MCP exposes 28 tools. Their schemas cost about 15,660 tokens on every request. `rbx` puts all 28 behind one `studio` tool (`op` plus `args`) for about 773 tokens, roughly a 95% cut, and nothing is lost: `op:"help"` returns any tool's schema on demand.

It also fixes real failures of the raw tools:

- `script_grep` treats the query as a Luau pattern, so `game:GetService("Players")` matches nothing. `rbx find` is a literal, comment-blind search with exact line numbers.
- Setting `script.Source` from Luau writes a detached copy that never syncs. `rbx write` uses `UpdateSourceAsync` and verifies a hash of the read-back.
- `multi_edit` edits the first substring match with no uniqueness check. `rbx edit` refuses an ambiguous anchor.
- Stale `require` caches, reverting property writes, and lost responses between parallel sessions are handled too.

There is also a CLI for bursts of calls: about 104 ms per Studio call, so ten calls cost one model turn instead of ten.

### The skills

| Skill | What it does |
|---|---|
| `studio` | The everyday loop: preflight, recon, verified edits, static proof, report format |
| `rbx` | The MCP and CLI transport, plus the Luau helpers |
| `luau` | Which APIs exist in which runtime, a readability contract, an error-to-cause index |
| `ui` | A complete GUI house style (Sky Checker), a panel builder, an audit lint |
| `advanced-ui` | Premium motion and canvas patterns: camera, effects, space, layout modules |
| `rbx-terrain` | Smooth Terrain toolkit: analyse, build, smooth, paint, with reversible builds verified by numbers |
| `rbx-map` | A generated map of a place (scripts, remotes, channels) so a session starts with one grep |
| `rbx-verify` | Proof before "done": probes for scripts, UI and behaviour |
| `rbx-net` | Remote audit and the one safe pattern for adding a client-to-server action |
| `rbx-data` | Persistence patterns: DataStore, attributes, MemoryStore |
| `rbx-economy` | Tune XP curves, prices and odds with tables instead of feelings |
| `rbx-perf` | Measure fps, join stalls and stutter |
| `rbx-release` | One-script pre-publish audit |
| `rbx-assets` | Mesh, texture and sound pipeline |
| `rbx-mobile` | Phone, tablet and console layout checks |
| `rbx-handoff` | STATUS, HANDOFF and PLAN files for work that spans sessions |
| `bulletproof` | Fire-and-forget mode: plan, verify in Studio, self-review, surface blockers |
| `token-minimizer` | Keep context cost down and see where tokens go |
| `repomap` | A compact symbol index for any repo |
| `retention-engine` | Score a game on 15 retention questions and find the missing piece |

## Built for Roblox

The installer also adds a Roblox block to `~/.claude/CLAUDE.md` (from [`CLAUDE.roblox.md`](CLAUDE.roblox.md)): a skill routing table, the hard rules (prove it before "done", server decides, one root `UIScale`, surgical diffs, confirm irreversible actions), and a report format. Claude then knows which skill to load for which job without being told. The block sits between `insane-rblx` markers, so re-running the installer updates it in place and your own notes stay untouched.

The rules are opinionated (for example, zero comments in Luau). Edit `CLAUDE.roblox.md` before installing, or the block in your `CLAUDE.md` afterwards.

## Good to know

- **Windows only for the MCP.** It finds Studio through `tasklist` and `netstat`. The skills themselves are plain Markdown and scripts.
- **It replaces the stock `Roblox_Studio` MCP** with `rbx` in Claude Code (and Codex, if you use it). `node ~/.claude/skills/rbx/setup.mjs --check` shows the state and `--uninstall` puts the stock server back.
- **The `ui` and `advanced-ui` skills reference the author's Roblox asset IDs** (the Sky Checker textures and glow sprites). Roblox may not load them in your experience, so images can render blank. Upload your own and swap the IDs in `skills/ui/scripts/sky.lua` and `skills/advanced-ui/scripts/Fx.lua`.
- Existing skills with the same names are moved to `~/.claude/skills-backup/`, never deleted. Your `CLAUDE.md` is copied to `CLAUDE.md.bak-<time>` before the first edit.
- Windows usernames with spaces can break the shell helper scripts.

## Uninstall

```
node install.mjs --uninstall
```

Restores the stock Studio MCP, removes the skills this repo installed, and removes the Roblox block from `CLAUDE.md`.

## License

MIT. Not affiliated with Roblox Corporation.
