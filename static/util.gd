extends Node

func _ready() -> void:
    get_all_phys_layer_names()

func get_player_ref() -> Node3D:
    var players: Array[Node] = get_tree().get_nodes_in_group("Player")
    if players.size() == 0 or not players[0] is Node3D:
        print_debug("No players found")
        push_warning("No players found")
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

func get_phys_bitmask_from_layer_names(layer_names: Array[String]) -> int:
    var bitmask: = 0
    for layer_name in layer_names:
        bitmask |= layer_to_bit(get_phys_layer_by_name(layer_name))
    return bitmask

func get_enclosing_aabb_of_mesh_instances_approximate(mesh_is: Array[MeshInstance3D]) -> AABB:
    var total_aabb: = AABB()
    for m in mesh_is:
        var sub_aabb: = m.get_aabb()
        var global_verts: = get_global_aabb_vertices(sub_aabb, m.global_transform)
        for v in global_verts:
            if total_aabb == AABB():
                total_aabb = AABB(v, Vector3.ZERO)
            else:
                total_aabb = total_aabb.expand(v)
    return total_aabb

func get_global_aabb_vertices(aabb: AABB, global_transform: Transform3D) -> Array[Vector3]:
    var global_vertices: Array[Vector3] = []
    for local_vertex in get_aabb_vertices(aabb):
        global_vertices.append(global_transform * local_vertex)
    return global_vertices

func get_aabb_vertices(aabb: AABB) -> Array[Vector3]:
    return [
        aabb.get_endpoint(0), aabb.get_endpoint(1),
        aabb.get_endpoint(2), aabb.get_endpoint(3),
        aabb.get_endpoint(4), aabb.get_endpoint(5),
        aabb.get_endpoint(6), aabb.get_endpoint(7),
    ]