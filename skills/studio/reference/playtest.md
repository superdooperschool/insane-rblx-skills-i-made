# playtest, debugging and runtime

## Default: do not enter Play

the user is usually building in the same Studio session and Play takes the session over. Prove
what you can statically (`reference/probes.md`). If a check genuinely cannot be done in Edit, ask
first.

## Console first

`get_console_output` is the primary error channel and costs nothing. Read it:

- before assuming a failure is your edit,
- immediately after any Play run,
- whenever a system "does nothing" with no visible error.

Most "it silently does not work" reports are a stack trace nobody read.

## Play mode rules

- `multi_edit` FAILS during Play. Stop Play first.
- `script_read` and `script_grep` see only the CLIENT datamodel while playing, so server scripts
  read as "not found". This is not a missing script.
- `get_studio_state` tells you which datamodels are live. Check it instead of guessing whether
  `Server` is reachable.
- Play can auto-stop within seconds in a backgrounded run. Do setup, assert and return in ONE
  `execute_luau` call. Do not split a runtime check across round trips.
- Land Edit-mode writes in the tight window right after `start_stop_play(false)`.

## Driving the game like a player

In the `Client` datamodel during Play:

- `character_navigation` walks the character to a position or an instance path, with a
  `speed_multiplier`. Use it to reach a shop pad, a zone gate, or a trigger part.
- `user_mouse_input` sends an ordered list of `moveTo` / `mouseButtonClick` / `scroll` / `wait`
  steps. It accepts an `instance_path` (`LocalPlayer.PlayerGui.Shop.BuyButton`) instead of screen
  coordinates, which is far more robust than pixel hunting.
- `user_keyboard_input` sends `keyPress` / `keyDown` / `keyUp` / `textInput` / `wait` steps.

A real end-to-end check is: navigate to the pad, click the button, read the console, screenshot
the result. That is worth far more than asserting on internal state.

## Deeper tools, when static is not enough

| Need | Use |
|---|---|
| Step through logic, inspect locals and threads | `skill(rbx-debug)` — programmatic breakpoints |
| Frame spikes, CPU/GPU split, memory by subsystem | `skill(rbx-perf-profiling)` — MicroProfiler via LibMP |
| Render cost, instance composition, unparented junk | `skill(rbx-scene-analysis)` |
| Assert on module behaviour repeatedly | `skill(rbx-unit-test)` |
| UI across form factors | `skill(rbx-device-simulator-lua)` |

**Studio FPS lies.** The viewport is vsync-locked, so 60 in Studio means nothing about a real
client. Profile, do not read the corner counter.

## Data safety

Live player data is irreversible. Before touching a DataStore path:

- Confirm with the user, always.
- Read before write, and never write from a probe you are still iterating on.
- Test against a scratch key, not a real user id.
- A migration needs an answer for players who already have data. "It will just default" is an
  answer only if the user has said so.
