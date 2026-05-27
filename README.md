


# Soccer Online

> `Soccer Online` is a Godot 4.6 2D pixel-art arcade soccer project, forked from [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course). The current goal is to capture the feel of small-team arcade soccer with physical tackles, power shots, field and weather effects, local play, tournaments, and online matches.

[简体中文](./README.zh-CN.md) -  English

## Project Status

- Engine: Godot 4.6 with GL Compatibility renderer
- Language: GDScript
- Main scene: `scenes/soccer_game.tscn`
- Native resolution: `280x180`, scaled with integer scaling
- Local modes: single player vs AI, local two-player, tournament
- Online mode: lobby, rooms, team selection, input snapshots, and world snapshot sync are implemented as a foundation and still being improved

## Features

- **6-a-side soccer**: each team has 6 players, including goalie, defenders, midfielders, and forwards.
- **9 national teams**: France, Argentina, Brazil, England, Germany, Italy, Spain, USA, and Canada.
- **Arcade actions**: movement, passing, charged shots, tackles, jumps, headers, volleys, bicycle kicks, and chest control.
- **Power shots**: normal, strong, rising, curve, invisible, jump, paint-trail, fish, taiji, gemini, and more.
- **Player state machine**: movement, tackle, jump, shot, hurt, celebration, reset, and other states are handled separately.
- **Role-based AI**: goalies, defenders, midfielders, and forwards use different behavior logic.
- **Field and weather foundation**: `FieldCondition`, weather particles, and field patch systems are present for speed, friction, slipping, and ball-trajectory effects.
- **Tournament mode**: local bracket flow with progression and winner display.
- **Online rooms**: ENet-based room list, room creation/joining, team and position selection, and match loading sync.

## Controls

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | `W` `A` `S` `D` | Arrow keys |
| Pass | `J` | `[` |
| Shoot / Confirm | `K` | `]` |
| Jump | `Space` or `J + K` | `Insert` or `[ + ]` |
| Tackle | Shoot while moving | Shoot while moving |

Tips:

- Hold shoot to charge power. When power reaches the threshold and the player is facing the goal, the configured power shot can trigger.
- Press pass while off the ball to swap players or request teammate support.
- Air-ball timing can trigger headers, volleys, bicycle kicks, and other aerial actions.

## Quick Start

1. Install Godot 4.6 or newer.
2. Open `project.godot` from the repository root in Godot.
3. Press `F5` to run the main scene.
4. Press `F6` to run the currently open scene for focused debugging.

## Online Play

The project uses Godot's built-in `ENetMultiplayerPeer`. The default port is `7000`.

Dedicated server mode starts automatically when any of the following is true:

- Running headless with `--headless`
- Running with the `--server` command-line argument
- Running with the Godot feature tag `server`

Typical flow:

1. Start one server instance.
2. Open a client, enter online mode, and connect to the server IP.
3. Create or join a room.
4. Select team and position in the online team-selection screen.
5. When all players are ready, the match scene loads and starts.

## Project Structure

```text
.
├── assets/                  # Art, fonts, squad data, music, sound effects
│   ├── art/                 # Pixel art, UI, pitch, players, national flags
│   ├── fonts/               # Daydream, Pixeled
│   ├── json/                # squads_en.json / squads_zh.json
│   ├── music/               # Menu, gameplay, tournament, and win music
│   └── sfx/                 # Shot, pass, tackle, UI, and match sounds
├── docs/                    # Chinese design notes and implementation plans
├── resources/               # Custom Resources, such as players and field conditions
├── scenes/
│   ├── audio/               # AudioPlayer, MusicPlayer
│   ├── ball/                # Ball entity, ball state machine, power-shot states
│   ├── characters/          # Player entity, player state machine, AI behavior
│   ├── game_manager/        # Match state machine, score, time, kickoff, game over
│   ├── network/             # RoomManager, SyncManager, online data flow
│   ├── screens/             # Main menu, team selection, online lobby, tournament, world
│   └── ui/                  # HUD and theme resources
├── shaders/                 # Color replacement, environment masks, and other shaders
├── utils/                   # Data loading, input, flags, score, time helpers
├── export_presets.cfg       # Godot export presets
└── project.godot            # Godot project configuration
```

## Architecture

The project mainly uses state machines and factory classes:

- `PlayerStateFactory` manages player action states.
- `BallStateFactory` manages ball possession, free movement, shots, and power-shot states.
- `GameStateFactory` manages match flow states such as kickoff, in play, scored, overtime, and game over.
- `ScreenFactory` manages screens such as the main menu, team selection, tournament, and online lobby.

Global singletons are registered through Godot Autoload:

- `DataLoader`: loads English and Chinese squad data.
- `GameEvents`: global signal bus.
- `GameManager`: match state, score, and current fixture.
- `AudioPlayer` / `MusicPlayer`: sound effects and music.
- `InputManager`: combo input and network input injection.
- `RoomManager`: ENet connection, rooms, lobby, and team selection.
- `SyncManager`: online match lifecycle, client input upload, world snapshots, and reliable event sync.

## Credits

This project is extended from [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course), with added power shots, aerial actions, role-based AI, tournament flow, and online play.
