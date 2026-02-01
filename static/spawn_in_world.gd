extends Node

var main_game: Node3D

func _ready() -> void:
    main_game = get_tree().current_scene

func spawn(instance: Node, global_position: Vector3, with_consistent_name: bool = false) -> void:
    spawn_centered(instance, with_consistent_name)
    instance.global_position = global_position

func spawn_centered(instance: Node, with_consistent_name: bool = false) -> void:
    if not main_game.current_world:
        push_warning("SpawnInWorld: No current world found")
        return
    main_game.current_world.add_child(instance, with_consistent_name)