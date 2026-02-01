@tool
extends Node3D

signal unloading_world
signal loaded_new_world

const world_scenes: Dictionary = {
    "Test Level": preload("res://assets/world/world_scene.tscn"),
    "Big Level": preload("res://assets/world/bigger_world.tscn"),
}

@export var default_world_scene: String = "Test Level"
var first_load: bool = true
var current_world: Node3D

func _validate_property(property_info: Dictionary) -> void:
    if property_info.name == &"default_world_scene":
        property_info.hint = PROPERTY_HINT_ENUM
        property_info.hint_string = ",".join(world_scenes.keys())

func _init() -> void:
    if Engine.is_editor_hint():
        return
    assert(default_world_scene, "Default world scene not set")
    assert(world_scenes.has(default_world_scene), "Default world scene key is not in the list")
    load_world_by_name(default_world_scene)

func load_world_by_name(world_name: String) -> bool:
    if Engine.is_editor_hint():
        return false
    if not world_scenes.has(world_name):
        return false
    if current_world:
        unload_current_world()
    
    current_world = world_scenes[world_name].instantiate()
    add_child(current_world, true)
    if first_load:
        first_load = false
    else:
        loaded_new_world.emit()
    return true

func unload_current_world() -> void:
    unloading_world.emit()
    current_world.queue_free()
    current_world = null
