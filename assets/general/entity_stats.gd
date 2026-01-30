extends Node
class_name EntityStats

signal health_changed(new_health: float)
signal out_of_health()

var base_node: Node3D

@export var can_be_hit: bool = true
@export var health: float = 10
@export var max_health: float = 10

func _ready() -> void:
    base_node = get_parent() as Node3D
    assert(base_node != null, "EntityStats must be a child of a Node3D")

func get_hit(amount: float) -> void:
    if not can_be_hit or health <= 0:
        return
    health = clampf(health - amount, 0, max_health)
    health_changed.emit(health)
    if health <= 0:
        out_of_health.emit()