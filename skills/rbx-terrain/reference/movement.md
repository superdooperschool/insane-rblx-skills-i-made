# Ball movement contract (rolling-ball game)

Sources: `ServerStorage.Modules.BallHandler` (server, lines ~547-625, 1770-1975),
`StarterPlayer.StarterPlayerScripts.BallHandler.targetDriveForce` (client 728), `ReplicatedStorage.GameConfig`
folder `Ball`. Workspace gravity 196.2. Re-read if those files change.

| Value | Number | Terrain meaning |
|---|---|---|
| Drive force | only while grounded; ground = straight-down ray from the collider | past vertical there is no ground, no drive, no downforce |
| UphillBoost | x3 drive when vel.Y > 3 | every bank up to ~35 deg is cheap to climb |
| DownhillSlowdown | x0.6 when vel.Y < -3 | gravity does the work downhill |
| LaunchCap | 18 studs/s up while grounded | crests and kickers cannot launch (apex < 1 stud) |
| Downforce | 55 studs/s2 while grounded | ball stays glued over bumps |
| Wall | face with abs(normal.Y) <= 0.4 (>= ~66 deg) | wall-ride: up to WallRideUp 72, WallClimbUp 17, stamina 2.6 s, WallJumpOut 58 |
| AirControl / AirDrag | 0.45 / 0.4 | air is slower than rolling; jumps are bursts |
| JumpPower | 56 | 0.57 s air, apex 8 studs, gap ~45 studs at base speed 95 |
| Bounce combo | apex >= 3 studs above take-off | only jumps build combos; terrain drops do not |
| Speed | MaxSpeedBase 95 -> 170 | turns need radius >= 100 on lanes |
| Grip | 3.2 | sideways speed is turned into forward speed: banked turns keep momentum |

## Works

Banked turns and berms (10-30 deg), dished lanes, half-pipes that top out below 45 deg, quarter-pipe
into a >= 70 deg wall (wall-ride launch), bowls and donuts to circle in, tunnels and arches (>= 32 clear),
bridges, drops, jump gaps <= 40 studs, long gentle ramps (<= 15 deg).

## Never

Loops, corkscrews, ceilings, inverted track (not grounded past vertical, drive and downforce stop,
wall-ride only lifts upward). Kicker ramps "for air" (LaunchCap flattens them). Driven planes at 45-66 deg
(too steep to drive, not steep enough to wall-ride, no blades above 55). Lanes narrower than the gaps
allow at speed (trail minimum ~28 floor; race lane 90+).
