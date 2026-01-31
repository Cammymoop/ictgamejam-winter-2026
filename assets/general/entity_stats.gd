extends Node
class_name EntityStats

signal health_changed(new_health: float)
signal got_hit()
signal got_hit_damage(damage: float, damage_ratio: float, prev_health: float, prev_health_ratio: float)
signal out_of_health()

var base_node: Node3D
var check_can_be_hit: Callable = Callable()

@export var _can_be_hit: bool = true
@export var health: float = 10
@export var max_health: float = 10

func _ready() -> void:
    base_node = get_parent() as Node3D
    assert(base_node != null, "EntityStats must be a child of a Node3D")
    
    await get_tree().process_frame
    EntityManager.register_entity(base_node, self)

func get_hit(amount: float) -> void:
    if not can_i_be_hit() or health <= 0:
        return
    var prev_health = health
    got_hit.emit()
    got_hit_damage.emit(amount, amount / max_health, prev_health, prev_health / max_health)
    health = clampf(health - amount, 0, max_health)
    health_changed.emit(health)
    if health <= 0:
        out_of_health.emit()

func get_health_ratio() -> float:
    return clampf(health / max_health, 0, 1)

func can_i_be_hit() -> bool:
    if not _can_be_hit:
        return false
    if check_can_be_hit.is_valid():
        return check_can_be_hit.call()
    return true