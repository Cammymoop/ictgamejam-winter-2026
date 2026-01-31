# ICT Game Jam Winter 2026

A fast-paced 3D rail shooter where you defend against waves of unique enemies while the camera carries you through procedurally-scored levels.

## Elevator Pitch

**Survive the rail.** Your camera moves on a fixed path through 3D space. Enemies spawn at checkpoints - explosive rushers, charging laser turrets, and projectile lobbers. Use WASD to dodge, mouse to aim, and click to shoot. Clear all enemies to advance. Die and restart. The soundtrack generates itself as you play.

## Getting Started

### Requirements
- [Godot 4.6+](https://godotengine.org/download)

### Run the Game
```bash
# Clone the repository
git clone <repo-url>
cd ictgamejam-winter-2026

# Open in Godot
godot --path . --editor

# Or run directly
godot --path . main_game_scene.tscn
```

### Controls
| Input | Action |
|-------|--------|
| WASD | Move player |
| Mouse | Aim cursor |
| Left Click | Fire projectile |
| ESC | Toggle mouse capture |

### Run Tests
```bash
# Requires Godot in PATH or set GODOT env var
make test
```

## Project Structure

```
├── assets/enemies/     # Enemy types (exploding, laser, throwing)
├── assets/level/       # Checkpoint and spawner systems
├── player/             # Player, weapons, projectiles
├── ui/                 # Win/lose screens, HUD
├── static/             # Utilities, SFX manager
├── test/               # GUT unit tests
└── main_game_scene.tscn
```

## Enemy Types

| Enemy | Behavior | Counter |
|-------|----------|---------|
| Exploding | Rushes and detonates | Kite and kill early |
| Laser | Charges beam, fires instantly | Move during charge-up |
| Throwing | Lobs arcing projectiles | Watch trajectory preview |

## License

Game jam project - see individual asset licenses.
