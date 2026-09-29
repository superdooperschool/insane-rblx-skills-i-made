---
name: rbx-map
description: Use at the start of any Roblox Studio session on a place with more than ~50 scripts, before any find/read/tree exploration, whenever asked "where is X / what owns Y / what fires Z", and after a session that added or moved scripts. Also use when a place has no MAP.md yet.
---

# rbx-map

**Read the map, not the place.** One generated `MAP.md` per game answers "where is X, what does it
require, which Net channels and remotes and attributes does it touch" for every script, so a session
starts with one grep instead of forty `find`/`read` calls (measured: 843 unranged script reads across
114 sessions, the same module re-read 65 times).

## Files

| Game | Map | Regenerate |
|---|---|---|
| any place | `<project>/MAP.md` | `bash ~/.claude/skills/rbx-map/scripts/build.sh <Game>` |

## Protocol

1. **Session open**: `grep -n "<term>" <project>/MAP.md` for every name in the task. Never `cat` the
   map (a big place: ~150k chars). `head -40` for the summary block only.
2. Map line format: `` - `path` [class lines] header | fn: ... | req: ... | net: h:chan f:chan o:chan r:chan | remotes: fire:X on:Y | attr: A B | async: SetAsync ``
   `h`=handles (server), `f`=fires (client), `o`=on (client listens), `r`=reply/broadcast (server sends).
3. Go live only for what the map cannot answer: a function body (`$R read --from/--to` at the outline
   line), a value, a runtime state.
4. **Regenerate** when the map gives a wrong answer or at the end of a session that created, moved,
   renamed or deleted scripts. Not on a schedule. ~90 s for 400 scripts. Read-only on the place.

## What build.sh emits

- Summary: scripts per service, live/archived counts, remotes, big scripts (>20k chars: outline
  before read), ScreenGuis with DisplayOrder, Frames panels.
- Net channel table from rbx-net (handler, firers, validation marks).
- One section per service, one line per live script. `_Parked*`, `_Removed*`, `_Archive*`, `_Backup*`
  folders are counted and skipped.

## Limits (say so instead of guessing)

- Channels registered through a variable (`Net.handle(CH.order, ...)`) do not appear in `net:`.
- `header` shows the first block comment or first 3 comment lines of a script, 160 chars. Scripts without one show nothing, which is fine: never add comments to fill it.
- The map is a snapshot; a peer session editing live can make it stale within the hour.

## Red flags

- `$R find` for a module name before grepping the map
- `$R tree` of a service without `--depth`/`--kw`
- Reading the map whole "to get an overview"
