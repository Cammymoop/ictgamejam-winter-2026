extends Node

func _ready() -> void:
    get_all_phys_layer_names()

func get_player_ref() -> Node3D:
    var players: Array[Node] = get_tree().get_nodes_in_group("Player")
    if players.size() == 0 or not players[0] is Node3D:
        return null
    return players[0] as Node3D

var phys_coll_layer_names: Dictionary[String, int] = {}
func get_all_phys_layer_names() -> void:
    for i in 32:
        var layer_num: = i + 1
        var layer_name_str: String = "layer_names/3d_physics/layer_%d" % layer_num
        var layer_name: Variant = ProjectSettings.get_setting_with_override(layer_name_str)
        if not layer_name:
            continue
        prints("phys layer name", layer_num, layer_name)
        phys_coll_layer_names[layer_name] = layer_num

func get_phys_layer_by_name(layer_name: String) -> int:
    return phys_coll_layer_names.get(layer_name, -1)

func check_coll_layer(coll_obj: CollisionObject3D, layer_name: String) -> bool:
    return coll_obj.get_collision_layer_value(get_phys_layer_by_name(layer_name))

func check_coll_mask(coll_obj: CollisionObject3D, mask_name: String) -> bool:
    return coll_obj.get_collision_mask_value(get_phys_layer_by_name(mask_name))

func layer_to_bit(layer_num: int) -> int:
    return 1 << (layer_num - 1)
