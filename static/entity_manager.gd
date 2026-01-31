extends Node

var entities: Array[Node3D] = []
var entity_stats: Dictionary[Node3D, EntityStats] = {}
var entity_coll_objects: Dictionary[CollisionObject3D, Node3D] = {}

func register_entity(entity: Node3D, stats: EntityStats) -> void:
    entities.append(entity)
    entity_stats[entity] = stats
    if entity is CollisionObject3D:
        entity_coll_objects[entity as CollisionObject3D] = entity
    for child in entity.get_children():
        if child is CollisionObject3D:
            entity_coll_objects[child as CollisionObject3D] = entity

func get_entity_from_coll_object(coll_object: CollisionObject3D) -> Node3D:
    if coll_object in entity_coll_objects:
        return entity_coll_objects[coll_object]
    return null

func hit_entity(entity: Node3D, amount: float) -> void:
    if not entity in entities:
        print_debug("Entity not found in entity manager: %s" % entity.get_path())
        push_warning("Entity not found in entity manager: %s" % entity.get_path())
        return
    entity_stats[entity].get_hit(amount)