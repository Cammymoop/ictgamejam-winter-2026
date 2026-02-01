extends Node

const TowerEnemy = preload("res://assets/enemies/tower_enemy.gd")

var spawn_spots: Array[Node3D] = []

var spawned_towers: Array[TowerEnemy] = []

var lower_amt: float = 7
var spawn_raise_timer: float = 2.1
var spawn_raise_curve_param: float = .45
var spawned_towers_progress: float = 0

func _ready() -> void:
    var parent: = get_parent()
    for child in parent.get_children():
        if child.name.begins_with("TowerHere"):
            spawn_spots.append(child)

func do_spawn() -> void:
    EntityManager.reset_all()
    spawned_towers.clear()
    spawned_towers_progress = 0
    for spot in spawn_spots:
        var tower: = preload("res://assets/enemies/tower_enemy.tscn").instantiate() as TowerEnemy
        if spot.get_meta("far", false):
            tower.active_distance = 200
            tower.bullet_speed = 180
        tower.is_enabled = false
        SpawnInWorld.spawn(tower, spot.global_position + Vector3.DOWN * lower_amt, true)
        spawned_towers.append(tower)

func spawned_towers_ready() -> void:
    for tower in spawned_towers:
        tower.is_enabled = true
    spawned_towers.clear()

func _process(delta: float) -> void:
    if not spawned_towers:
        return
    
    var last_progress: = spawned_towers_progress
    var last_amt: = ease(last_progress, spawn_raise_curve_param) * lower_amt
    spawned_towers_progress += delta / spawn_raise_timer

    var current_amt: = ease(spawned_towers_progress, spawn_raise_curve_param) * lower_amt
    
    for tower in spawned_towers:
        tower.position.y += (current_amt - last_amt)
        #var animatable_body: = tower.find_child("AnimatableBody3D") as AnimatableBody3D
        #assert(animatable_body, "AnimatableBody3D not found")
        #animatable_body.position = animatable_body.position
    
    if spawned_towers_progress >= 1:
        spawned_towers_ready()
        
