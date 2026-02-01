extends Node

signal entity_removed(entity: Node3D)

var entities: Array[Node3D] = []
var entity_stats: Dictionary[Node3D, EntityStats] = {}
var entity_coll_objects: Dictionary[Node3D, Array] = {}
var entity_coll_objects_rev: Dictionary[CollisionObject3D, Node3D] = {}

var entity_is_required_destroy: Dictionary[Node3D, bool] = {}

var require_destroy_first_added: bool = false

func _ready() -> void:
    get_tree().scene_changed.connect(reset_all)

func register_entity(entity: Node3D, stats: EntityStats) -> void:
    entities.append(entity)
    entity_stats[entity] = stats
    var all_coll_objects: = recursive_collect_nodes(entity, "CollisionObject3D")
    for coll_object in all_coll_objects:
        _add_entity_coll_object(entity, coll_object as CollisionObject3D)
    if not entity.tree_exited.is_connected(entity_exiting_tree):
        entity.tree_exited.connect(entity_exiting_tree.bind(entity))

func reset_all() -> void:
    entities.clear()
    entity_stats.clear()
    entity_coll_objects.clear()
    entity_coll_objects_rev.clear()
    entity_is_required_destroy.clear()
    require_destroy_first_added = false

func set_entity_is_required_destroy(entity: Node3D, is_required_destroy: bool) -> void:
    if not require_destroy_first_added and is_required_destroy:
        require_destroy_first_added = true
    entity_is_required_destroy[entity] = is_required_destroy

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
    if entity in entity_coll_objects:
        for coll_object in entity_coll_objects[entity]:
            entity_coll_objects_rev.erase(coll_object)
        entity_coll_objects.erase(entity)
    if entity_is_required_destroy.has(entity):
        entity_is_required_destroy.erase(entity)
    entity_removed.emit(entity)

func are_all_entities_required_destroy() -> bool:
    #if not require_destroy_first_added:
    var tower_count: = 0
    for entity in entities:
        if entity.get_script() == preload("res://assets/enemies/tower_enemy.gd"):
            tower_count += 1
    if tower_count > 0:
        return false

    var count: = 0
    for entity in entity_is_required_destroy:
        if entity_is_required_destroy.get(entity, false):
            count += 1
    return count < 1