extends Node

var entities: Array[Node3D] = []
var entity_stats: Dictionary = {}  # Stores Node3D -> EntityStats
var entity_coll_objects: Dictionary[CollisionObject3D, Node3D] = {}

func register_entity(entity: Node3D, stats: Node) -> void:  # stats is EntityStats
    entities.append(entity)
    entity_stats[entity] = stats
    var all_coll_objects: = recursive_collect_nodes(entity, "CollisionObject3D")
    for coll_object in all_coll_objects:
        entity_coll_objects[coll_object as CollisionObject3D] = entity

func get_entity_from_coll_object(coll_object: CollisionObject3D) -> Node3D:
    if coll_object in entity_coll_objects:
        return entity_coll_objects[coll_object]
    return null

func hit_entity(entity: Node3D, amount: float) -> bool:
    if not entity in entities:
        print_debug("Entity not found in entity manager: %s" % entity.get_path())
        push_warning("Entity not found in entity manager: %s" % entity.get_path())
        return false
    return entity_stats[entity].get_hit(amount)

func recursive_collect_nodes(at_node: Node, node_class: String) -> Array[Node]:
    var nodes: Array[Node] = []
    if ClassDB.is_parent_class(at_node.get_class(), node_class):
        nodes.append(at_node)
    for child in at_node.get_children():
        nodes.append_array(recursive_collect_nodes(child, node_class))
    return nodes