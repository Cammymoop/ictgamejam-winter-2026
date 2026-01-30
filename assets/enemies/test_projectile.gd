extends Node3D

@export var speed: float = 120
@export var life_time: float = 6

func _process(delta: float) -> void:
    position.z += speed * delta
    life_time -= delta
    if life_time <= 0:
        queue_free()