# Runtimes

Five places Luau runs. They share a language and almost nothing else. Pick one before writing.

## Matrix

| Runtime | Lives in | Has | Does NOT have |
|---|---|---|---|
| **Server** | `Script` in `ServerScriptService`, `ServerStorage`, `Workspace` | `DataStoreService`, `ServerStorage`, `MessagingService`, `Players:GetPlayers()`, `Remote.OnServerEvent`, `:SetNetworkOwner`, `HttpService:RequestAsync` | `LocalPlayer`, `PlayerGui` (write it through `player.PlayerGui`, never assume timing), `UserInputService`, `ContextActionService`, `CurrentCamera`, `RenderStepped`, `Mouse` |
| **Client** | `LocalScript` / `Script` with `RunContext = Client` in `StarterPlayerScripts`, `StarterCharacterScripts`, `StarterGui`, `ReplicatedFirst`, or any descendant of the local player's character/PlayerGui | `Players.LocalPlayer`, `UserInputService`, `ContextActionService`, `workspace.CurrentCamera`, `RunService.RenderStepped`, `ScreenGui`, `TweenService` on local UI, `Remote.OnClientEvent` | `DataStoreService`, `ServerStorage`, `.OnServerEvent`, `MessagingService`, authority over anything |
| **ModuleScript** | anywhere | exactly what its **caller** has | anything the caller lacks. It has no runtime of its own |
| **Plugin** | installed plugin, or `Plugin` `RunContext` | the `plugin` global, `ScriptEditorService`, `ChangeHistoryService`, Selection, the Edit DataModel, toolbars/widgets | `LocalPlayer` (nil in Edit), anything Play-only |
| **Edit sandbox** | `rbx lua` / `execute_luau` / command bar | the game tree, `Instance` APIs, property writes | `require` (sandboxed), a shared `_G`, the ability to create a Script/LocalScript/ModuleScript. See `studio` skill |

**Sharpest edges**

- `Drawing` is not a Roblox API. Not in a LocalScript, not in a plugin. Use a `ScreenGui`.
- `plugin` does not exist at runtime. Not in a LocalScript, not in a Script.
- `Players.LocalPlayer` is `nil` on the server and `nil` in Edit. Guarding it does not make it work.
- `RunService.RenderStepped` throws on the server. `RunService.Heartbeat` runs on both.
- `ReplicatedFirst` runs before anything replicates. `WaitForChild` there needs a timeout.
- Studio's Play solo has both a Server and a Client DataModel. `rbx read` during Play sees the
  **client** one.

