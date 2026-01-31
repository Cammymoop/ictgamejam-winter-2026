# Game Interaction Design Checklist

## Overview
Design specification for WASD movement, mouse cursor aiming, and 3D enemy scene interactions.

---

## 1. Input System

### WASD Movement
- [x] Player moves on XZ plane (Y is up)
- [x] Movement is relative to camera orientation (not world axes)
- [x] W = camera forward, S = camera back, A = camera left, D = camera right
- [x] Diagonal movement normalized to prevent speed boost
- [x] Smooth acceleration/deceleration for responsive feel

### Mouse Cursor
- [x] OS cursor hidden, replaced with 2D sprite on CanvasLayer
- [x] Cursor sprite follows `get_viewport().get_mouse_position()`
- [x] Cursor provides visual feedback (crosshair, reticle)
- [x] Cursor changes color/shape when hovering over enemy

---

## 2. Cursor to 3D Translation

### Raycast Pipeline
```
Screen Position (2D)
       |
Camera.project_ray_origin(screen_pos)
Camera.project_ray_normal(screen_pos)
       |
PhysicsRayQueryParameters3D
       |
World3D.direct_space_state.intersect_ray()
       |
World Position (3D)
```

### Collision Layers for Raycast
| Layer | Name | Purpose |
|-------|------|---------|
| 1 | Player | Player body (excluded from cursor ray) |
| 2 | Ground | Floor/terrain for cursor positioning |
| 3 | Enemies | Enemy bodies (for targeting feedback) |
| 4 | Projectiles | Weapon projectiles |

### Raycast Behavior
- [x] Ray originates from camera, passes through mouse screen position
- [x] Ray length: 1000 units (sufficient for game scale)
- [x] Collides with: Ground (layer 2), Enemies (layer 3)
- [x] Excludes: Player (layer 1), Projectiles (layer 4)
- [x] Fallback: If no collision, intersect with Y=0 plane
- [x] Returns: `{ position: Vector3, collider: Node, normal: Vector3 }`

---

## 3. Enemy Scene Structure

### Node Hierarchy
```
Enemy (CharacterBody3D) [Layer 3]
├── MeshInstance3D (visual representation)
├── CollisionShape3D (physics body)
├── HurtboxArea (Area3D) [Layer 3]
│   └── CollisionShape3D
├── HealthComponent (Node)
└── AIController (Node)
```

### Enemy Collision Configuration
- [x] **CharacterBody3D**: Layer 3, Mask 1,2 (collides with player, ground)
- [x] **HurtboxArea**: Layer 3, Mask 4 (detects projectile hits)
- [x] Separate hurtbox allows projectiles to pass through after hit

### Enemy Required Methods
```gdscript
func take_damage(amount: float) -> void
func get_health() -> float
func is_alive() -> bool
func die() -> void
```

---

## 4. Projectile Collision Geometry

### Projectile Scene Structure
```
Projectile (RigidBody3D) [Layer 4, Mask 2,3]
├── MeshInstance3D (bullet visual)
├── CollisionShape3D (SphereShape3D, small radius)
└── GPUParticles3D (trail effect)
```

### Collision Matrix

|                | Player (1) | Ground (2) | Enemy (3) | Projectile (4) |
|----------------|------------|------------|-----------|----------------|
| **Player**     | -          | Y          | Y         | -              |
| **Ground**     | Y          | -          | Y         | Y              |
| **Enemy**      | Y          | Y          | -         | Y              |
| **Projectile** | -          | Y          | Y         | -              |

### Projectile Behavior
- [x] Spawns at weapon muzzle position
- [x] Direction: `(cursor_world_pos - muzzle_pos).normalized()`
- [x] Velocity set via `RigidBody3D.linear_velocity`
- [x] Gravity disabled (`gravity_scale = 0`)
- [x] On collision with Ground: Destroy projectile
- [x] On collision with Enemy: Call `enemy.take_damage()`, destroy projectile
- [x] Lifetime timeout: 5 seconds max, then destroy

---

## 5. Interaction Flow

### Frame Update Sequence
```
1. Input._process()
   └── Capture WASD state, mouse position

2. CursorManager._process()
   ├── Update 2D cursor sprite position
   ├── Perform 3D raycast
   ├── Store world_position result
   └── Notify Player and WeaponManager of target

3. Player._physics_process()
   ├── Calculate movement from WASD input
   ├── Apply velocity via move_and_slide()
   └── Rotate to face cursor world position

4. WeaponManager._process()
   ├── Rotate to face cursor world position
   └── If fire input: spawn projectile toward target

5. Projectile._physics_process()
   └── RigidBody3D handles movement automatically

6. Enemy._physics_process()
   └── AI movement, check if hit by projectiles
```

### Event Flow: Player Fires at Enemy
```
[Click] -> WeaponManager.fire()
              |
       Projectile spawned
              |
       RigidBody3D moves toward target
              |
       body_entered signal (Enemy detected)
              |
       Enemy.take_damage(damage)
              |
       Projectile.queue_free()
              |
       Enemy checks health -> die() if <= 0
```

---

## 6. Enemy Scene Checklist

### Minimum Viable Enemy
- [x] CharacterBody3D with collision layer 3
- [x] Visible mesh: Low-poly NURBS style (smooth curved shape with reduced segments)
- [x] CollisionShape3D matching mesh bounds
- [x] Script with `take_damage()` method
- [x] Health variable (default: 100)
- [x] Death handling (queue_free or death animation)
- [x] Group membership: `"enemies"`

### Optional Enhancements
- [ ] Health bar (SubViewport or 3D sprite)
- [x] Hit flash effect (shader or tween)
- [ ] Death particles
- [ ] AI patrol/chase behavior
- [ ] Attack capability (damage player on contact)

---

## 7. Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `enemy.gd` | Created | Enemy script with health, damage, death |
| `enemy.tscn` | Created | Enemy scene with collision setup |
| `project.godot` | Modified | Define collision layer names |
| `cursor_manager.gd` | Modified | Add enemy hover detection |
| `projectile.gd` | Verified | Proper collision handling |
| `player.tscn` | Modified | Set collision layers |
| `main.tscn` | Modified | Added test enemies |

---

## 8. Testing Checklist

- [ ] Player moves with WASD in correct directions
- [ ] Cursor follows mouse and renders above 3D scene
- [ ] Raycast returns valid 3D position on ground
- [ ] Raycast detects enemy when cursor hovers over
- [ ] Projectiles travel toward cursor 3D position
- [ ] Projectiles collide with enemies
- [ ] Enemies take damage and die at 0 health
- [ ] Projectiles are destroyed on impact
- [ ] Projectiles are destroyed when hitting ground
- [ ] No projectile-player collision

---

## 9. Collision Layer Reference

| Layer | Name | Bitmask Value |
|-------|------|---------------|
| 1 | Player | 1 |
| 2 | Ground | 2 |
| 3 | Enemies | 4 |
| 4 | Projectiles | 8 |

### Current Configuration
- **Player**: layer=1, mask=6 (ground+enemies)
- **Ground**: layer=2
- **Enemy**: layer=4 (layer 3), mask=3 (player+ground)
- **Enemy Hurtbox**: layer=4 (layer 3), mask=8 (projectiles)
- **Projectile**: layer=8 (layer 4), mask=6 (ground+enemies)
- **Cursor Raycast**: mask=6 (ground+enemies)

---

## 10. Procedural Music System

### Architecture Overview
```
MusicTheory (Autoload)
       |
GenreDefinition (Resource)
       |
CompositionGenerator
       |
Composition (generated)
       |
CompositionPlayer -> VoiceSynth nodes
```

### Music Theory (music/gdscript/music_theory.gd)
- Note frequency calculation (A4 = 440Hz)
- Scales: major, minor, pentatonic, blues, dorian, mixolydian, harmonic/melodic minor
- Chord types: major, minor, dim, aug, 7ths, sus, add9
- Chord voicings: root, inversions, spread, wide
- Progressions: I-IV-V-I, I-V-vi-IV, ii-V-I, 12-bar blues

### Composition Generation
- GenreDefinition: tempo range, scales, progressions, rhythm patterns, instruments
- CompositionGenerator: creates tracks per voice role (melody, harmony, bass, rhythm)
- Arpeggiator: pattern-based melody generation
- RhythmPattern: beat patterns with velocity/duration

### Voice Roles
| Role | Description | Octave |
|------|-------------|--------|
| melody | Arpeggiated or scale-based lead | 4 |
| harmony | Sustained chord pads | 3 |
| bass | Chord root notes with rhythm | 2 |
| rhythm | Percussion using noise frequencies | N/A |

### C++ Synth Extension (music/cpp/)
- VoiceSynthNode: AudioStreamPlayer-based polyphonic synth
- Waveforms: sine, square, saw, triangle, noise
- ADSR envelope per voice
- Vibrato and detune parameters
- Requires building with godot-cpp (see build instructions)

### Build Instructions
```bash
# Clone godot-cpp (if not present)
cd music && git clone --depth 1 --branch 4.2 https://github.com/godotengine/godot-cpp.git

# Build godot-cpp bindings
cd music/godot-cpp && scons platform=macos

# Build synth extension
cd music/cpp && scons platform=macos
```

### Files
| Path | Purpose |
|------|---------|
| music/gdscript/music_theory.gd | Core scales, chords, progressions |
| music/gdscript/composition_generator.gd | Creates Composition from GenreDefinition |
| music/gdscript/composition.gd | Data structure for tracks and notes |
| music/gdscript/composition_player.gd | Playback via VoiceSynth nodes |
| music/gdscript/genre_definition.gd | Genre resource with music parameters |
| music/gdscript/arpeggiator.gd | Arpeggio pattern generator |
| music/gdscript/rhythm_pattern.gd | Beat patterns |
| music/gdscript/instrument_preset.gd | Synth voice settings |
| music/cpp/voice_synth_node.* | C++ polyphonic synthesizer |
| music/cpp/synth.gdextension | GDExtension configuration |

---

## 11. Enemy System

### Enemy Architecture

All enemies extend `EnemyBase` (CharacterBody3D) which provides:
- State machine: IDLE → ACTIVE → ATTACKING → DYING
- EntityStats integration for health/damage
- Player targeting utilities
- Hit flash and death effects

### Enemy Types

| Enemy | Behavior | Damage | Counterplay |
|-------|----------|--------|-------------|
| ExplodingEnemy | Rushes player, detonates on contact or death | 2.0 (40% HP) | Kite sideways, kill before detonation range |
| LaserEnemy | Charges 1.8s, fires instant beam | 1.5 (30% HP) | Move perpendicular during charge telegraph |
| ThrowingEnemy | Lobs arcing projectiles with trajectory preview | 1.0 (20% HP) | Watch orange preview line, sidestep impact zone |

### Balance Documentation

Player context for all balance decisions:
- **Player HP**: 5
- **Player Speed**: 10.0 units/s
- **Play Bounds**: 4×3 units

### Enemy Files

| Path | Purpose |
|------|---------|
| `assets/enemies/enemy_base.gd` | Base class for all enemies |
| `assets/enemies/exploding_enemy.gd` | Rush + detonate enemy |
| `assets/enemies/laser_enemy.gd` | Charge + beam enemy |
| `assets/enemies/throwing_enemy.gd` | Arc projectile enemy |
| `assets/enemies/arc_projectile.gd` | Physics projectile with trajectory |
| `static/sfx_manager.gd` | Procedural sound effects |

### Procedural SFX

SFXManager generates placeholder sounds procedurally:
- **Tick**: Square wave beeps (exploding enemy approach)
- **Boom**: Filtered noise burst (explosions)
- **Charge Whine**: Rising pitch tone (laser charge)
- **Zap**: Sawtooth burst (laser fire)
- **Grunt**: Low noise burst (throwing enemy)
- **Thud**: Impact noise (projectile landing)
