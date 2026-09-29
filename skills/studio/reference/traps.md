# traps

Things that behave impossibly. Each one has cost somebody a day. Grouped by what you were doing
when it bit.

## Writing to the datamodel

**`script.Source = "..."` does not stick.** From `execute_luau` this writes a DETACHED in-VM copy.
`script_read` and Play both keep seeing the old source, and there is no error. For a full rewrite
use `ScriptEditorService:UpdateSourceAsync(inst, function() return newSrc end)`; for a partial
edit use `multi_edit`.

**A property reverts on the next call.** Property and attribute writes from `execute_luau` can be
rolled back by Studio's own change tracking. Wrap them in a `ChangeHistoryService` recording
(`TryBeginRecording` / `FinishRecording` with `Commit`) and read back in a *separate* call.

**A new Script/LocalScript/ModuleScript refuses to reparent, anywhere.** `Instance.new("Script")`
then `.Parent = <anything>` from `execute_luau` fails with `The current thread cannot reparent
'<name>' to '<path>' since '<path>' has additional values for the Capabilities property:
LoadUnownedAsset (and 3 more)`. Reproduced in ServerScriptService, ReplicatedStorage, StarterGui,
StarterPlayerScripts, and plain Workspace - the sandboxed `execute_luau` thread itself lacks
script-injection capability; it is not a per-service setting, and cloning an already-placed script
or using the two-arg `Instance.new(class, parent)` constructor does not help either. This is not a
reason to ask the user to insert the script by hand: the raw `multi_edit` tool creates scripts
fine, because it goes through `ScriptEditorService` instead of the sandboxed thread. Pass
`className` (`Script`/`LocalScript`/`ModuleScript`) and a first edit with `old_string: ""` to seed
the source; write/edit it normally after that.

**`_G` writes are invisible to game scripts.** `execute_luau` runs in a sandboxed global env, so
its `_G` is a different table. Drive live systems through Instance APIs instead:
`Remote:FireClient(plr, payload)`, attributes, BindableEvents.

**`require` is nil inside `execute_luau`.** Not a bug in your code. Use Probe 2 (execute the
module body with `setfenv`) to read a module's real exports.

**An edit landed inside the wrong function.** `multi_edit`'s `old_string` is a raw substring
search: first match wins, no uniqueness check. A short anchor like `return GameConfig` has
spliced an entire block into the middle of an unrelated one-liner, producing nested function
definitions that are valid Lua and only fail at runtime. Run Probe 8 first; the fix is a longer
anchor, not a retry.

**`script_grep` finds nothing that obviously exists.** The query is a Luau **pattern**, so
`( ) [ ] . - % + * ?` are special. `FindFirstChild("X")` matches nothing. Grep a plain literal
substring.

**`script_grep` line numbers do not line up with `script_read`.** They are offset on large
scripts. Match edits by content, never by line number.

## Running code

**The edited module still runs the old code.** `require` caches per ModuleScript *instance* in
the Edit datamodel. Clone the module, require the clone, destroy the clone (Probe 3).

**`require` errors about capabilities.** Check `Sandboxed` and `Capabilities` on BOTH the module
and the requiring script. Fixing one side only flips the error to the other side.

**A script exists, has no errors, and never runs.** Three causes, all silent:
`Disabled = true`; a `LocalScript` parented somewhere the client never loads (ServerScriptService,
ServerStorage, plain Workspace); a legacy `Script` under a replicated container (ReplicatedStorage,
StarterGui). The preflight catches all three. Setting `RunContext` fixes the third without moving
anything.

**Server scripts "do not exist" while reading.** You are in Play: `script_read` and `script_grep`
see the CLIENT datamodel only. Stop Play.

**`multi_edit` fails during Play.** It only works in the Edit datamodel. Stop Play first.

## State that lies

**The last attribute written vanishes, earlier ones are fine.** One instance holds 1024 bytes of
attributes total. Past the cap `SetAttribute` silently refuses. Move to a child `Configuration`,
which gets its own 1024 bytes. This bites hardest on the Player instance.

**Changing a value in the explorer does nothing.** The config module's in-file tuning table beats
the Value instance in the getter. Read the getter order before telling the user a number is live.

**`FindFirstChild` returns the wrong one.** Duplicate sibling names. The pick is not
deterministic, so it reproduces on one machine and not another.

**A quest, objective or unlock never completes and never errors.** The name is derived from an
attribute that was stripped or renamed, and unknown names are usually legal in these systems: the
code warns at most. Check that the objective NAME is the thing being counted, and that any scope
qualifier still resolves.

## The world

**The build resets every server restart.** It is being constructed at server boot instead of
existing in the Edit datamodel. World geometry belongs in Edit-callable builder modules that you
run once from `execute_luau`, so it saves with the place.

**Grey or missing meshes.** Either the place has never been published (`game.PlaceId == 0`), or
`StreamingEnabled` is showing placeholders. Neither is something you broke.

**A join stall with a huge Frame count.** A closed panel is building its entire tree on the join
frame. Build per tab or per board on first view.

**Sounds stop playing after a while.** Cloned Sounds on fixed `Debris:AddItem` timers pile up
into dozens of live instances and evict each other. Destroy on `Ended`, cap the pool, and keep
ambient sounds in a different pool from UI sounds.

## Measuring

**Studio FPS lies.** The viewport is vsync-locked. A place that reads 60 in Studio can be
anything in a real client. Use `skill(rbx-perf-profiling)` or `skill(rbx-scene-analysis)`.

**Stray Decals and Textures double draw calls.** Each one is its own draw. A mesh carrying two
leftover Decals costs three draws, and a few hundred strays is a measurable frame cost that no
script profile will show you.

**Unanchored parts that never move** still cost physics every frame. Probe 14 counts them.
