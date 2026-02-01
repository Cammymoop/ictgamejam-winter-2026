extends Node

signal entity_removed(entity: Node3D)

var entities: Array[Node3D] = []
var entity_stats: Dictionary[Node3D, EntityStats] = {}
var entity_coll_objects: Dictionary[Node3D, Array] = {}
var entity_coll_objects_rev: Dictionary[CollisionObject3D, Node3D] = {}

func register_entity(entity: Node3D, stats: EntityStats) -> void:
    entities.append(entity)
    entity_stats[entity] = stats
    var all_coll_objects: = recursive_collect_nodes(entity, "CollisionObject3D")
    for coll_object in all_coll_objects:
        _add_entity_coll_object(entity, coll_object as CollisionObject3D)
    entity.tree_exited.connect(entity_exiting_tree.bind(entity))

func _add_entity_coll_object(entity: Node3D, coll_object: CollisionObject3D) -> void:
    if not entity in entity_coll_objects:
        entity_coll_objects[entity] = Array([], TYPE_OBJECT, &"CollisionObject3D", null)
    entity_coll_objects[entity].append(coll_object)
    entity_coll_objects_rev[coll_object] = entity

func get_entity_from_coll_object(coll_object: CollisionObject3D) -> Node3D:
    if coll_object in entity_coll_objects_rev:
        return entity_coll_objects_rev[coll_object]
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

func entity_exiting_tree(entity: Node3D) -> void:
    entities.erase(entity)
    entity_stats.erase(entity)
    for coll_object in entity_coll_objects[entity]:
        entity_coll_objects_rev.erase(coll_object)
    entity_coll_objects.erase(entity)
    entity_removed.emit(entity)