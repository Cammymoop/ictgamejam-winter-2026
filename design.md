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
