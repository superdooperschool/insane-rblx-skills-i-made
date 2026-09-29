---
name: repomap
description: Use at the start of work in any non-trivial codebase (roughly 20+ source files), and whenever answering "where is X", "how does Y work", "what calls Z", or making an edit that needs locating code first. Builds and reads a compact on-disk symbol index (.repomap/map.md) so a large codebase costs a few KB of context instead of loading whole files - persisted, so the next session reuses it instead of re-searching. Use when context is ballooning from reading source, or when a repo would otherwise pull 100k+ tokens.
---

# repomap

A codebase's whole source is 100k-400k tokens. Its **symbol map** is 1-6k, lives on disk, and is
enough to navigate. Read the map, then window into only the slice a task touches. This is the
difference between a 156k-token session and a 6k one - measured 27x on a real Next.js app.

`.repomap/map.md` is a file → `LNN symbol` index: every function, class, export, def, with its exact
line number. It persists, so a later session loads the map instead of re-reading the tree.

## The loop

1. **Map exists?** `.repomap/map.md` at the repo root. If yes and the repo has not changed much,
   read it (it is small). If no and the repo is non-trivial, build it:
   ```
   node $HOME/.claude/skills/repomap/repomap.mjs "<repo root>"
   ```
   One rg pass, sub-second, honours `.gitignore` and hard-excludes `node_modules`/build/minified.
   Prints the token cost so you see what you saved.
2. **Locate, never scan.** To find something, `Grep` the map for the symbol → get `path` + `LNN`.
   Do NOT `Grep` the whole tree and do NOT read whole files to find a definition.
3. **Window in.** `Read` that file with `offset`/`limit` around the line. A function is 20-60 lines;
   read those, not the 800-line file.
4. **Whole-file read only when justified:** a file under ~200 lines, or a final self-review of
   something you just wrote. Never as a way to "find" code.
5. **After edits that add/rename/remove symbols,** regenerate the map (same command). Stale line
   numbers send the next read to the wrong place.

## Why this beats loading files

- **Persisted.** The map is on disk. Session 2 reads a 6k map; it does not re-explore. That is the
  "retained knowledge" - it is a file, not conversation history.
- **Cheap to rebuild.** rg over thousands of files is under a second, and it runs in the shell, so
  the cost lands on local compute, never on context.
- **The map is the plan.** Grepping symbol names across the map answers "where is auth handled",
  "what touches the cart", "which files define a component" without a single file read.

## Relationship to other tools

- **graphify** (if `graphify-out/graph.json` exists) is the heavier, LLM-built relationship graph -
  prefer it for "what connects A to B" and architectural questions. repomap is the cheap always-on
  layer for "where is X and what is its signature". Use the graph when present; the map otherwise.
- **rbx / studio** already apply this discipline inside Roblox (`outline`, `find`, windowed `read`).
  repomap is the same idea for every other codebase.

## Limits

- It is a navigation index, not a compiler. The regex catches the common declaration forms across
  ~20 languages; an exotic macro or a metaprogrammed export may be missed. When the map has no hit
  for something you know exists, `Grep` the source directly for that one symbol - do not read files.
- A file capped at `+N more, likely generated` is minified or generated. Do not read it to
  understand the app.
- Line numbers drift as the file is edited. Regenerate after structural edits; trust `Grep` over a
  stale `LNN`.
