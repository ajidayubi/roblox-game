# Tower Climb — a make.fun roblox-game-01 entry

**Tower Climb** is a 3D obstacle tower climb for Roblox. Race a 3:00 countdown
up five stages of platforms to the Golden Summit, grab coins on the way,
dodge the red spinner hazards, and save your progress at each glowing
checkpoint pad. Fall and you restart from your last checkpoint — never from
the bottom.

## How to play

- **Goal:** reach the golden summit pad at the top of the tower before the
  3:00 timer runs out. Reaching it wins the round and pays a +10 coin bonus.
- **Move:** WASD / arrow keys. **Jump:** Space. **Sprint:** hold Shift.
- **Coins:** gold spinning coins sit on platforms (3 per stage, plus a 5-coin
  bonus coin on the summit). Collecting one is worth 1 coin.
- **Checkpoints:** each stage ends on a wide glowing pad. Touch it to save
  your progress — falls and spinner hits send you back there.
- **Hazards:** from stage 3, red spinner bars sweep platforms; touching one
  knocks you back to your checkpoint. From stage 4, some platforms vanish
  on a cycle — time your jumps.
- **Leaderboard:** the top 5 climbers (by height, then coins) show live in
  the HUD panel and on the standing board by the spawn pad. Winners get a 👑.
  Your session personal best height is toasted when you beat it and shown
  on the end screen.
- **Rounds:** when the timer hits zero, everyone who hasn't won sees their
  result and a new round starts automatically. Press **Climb Again** to
  restart your own run at any time after winning or timing out.

## Layout

```
src/
  shared/GameConfig.luau        — one source of truth: tuning, palette, stage layout
  server/GameServer.server.luau — authoritative rules: timer, coins, checkpoints,
                                  hazards, falls, wins, leaderboard broadcasts
  server/TowerBuilder.luau      — builds the tower, coins, hazards and board from config
  server/LeaderboardService.luau— in-memory top-5 ranking (height, then coins)
  client/TowerClient.client.luau— HUD state, start/end screens, sprint, remote listeners
  client/HudBuilder.luau       — builds every ScreenGui element (top bar, board, toasts)
```

The server owns every score, timer and teleport; the client only renders
state and asks to restart. Coins and checkpoints are collected with
server-side `Touched` handlers (debounced per player), so scores can't be
faked from the client.

## Build

Requires [Rojo](https://github.com/rojo-rbx/rojo) 7.x:

```sh
rojo build default.project.json --output game.rbxl
```

Open `game.rbxl` in Roblox Studio to play-test and publish. The place file
is the binary format (never `.rbxlx`).

## Publish (owner's step)

Publish the place from Roblox Studio to the owner's Roblox account, set the
experience **Public** on the Creator Dashboard (age check, description,
genre, content questions first), then fill in `PLAY.json` with the real
`place_id` and `universe_id`.

## License

MIT — see `LICENSE`.
