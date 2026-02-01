extends EnemyBase


@onready var animator: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    super._ready()
    EntityManager.set_entity_is_required_destroy(self, false)

func start_now() -> void:
    find_child("CollisionShape3D").set_deferred("disabled", false)
    animator.play("enter")
    death_animator = $DeathAnimator
    #queue_free()
    #return
    #var player: = Util.get_player_ref()
    #assert(player, "Player not found")
    
    #var player_stats: = player.entity_stats as EntityStats
    #EntityManager.entity_removed.connect(_on_entity_removed.bind(player_stats))
    timer_set.start_new_timer("gone", 4, go_out)

func go_out() -> void:
    find_child("CollisionShape3D").set_deferred("disabled", true)
    animator.play("leave")
    await animator.animation_finished
    queue_free()

func _on_entity_removed(_entity: Node3D, _player_stats: EntityStats) -> void:
    pass
    #if not entity == self:
        #return

    #if not player_stats:
        #print_debug("Player stats not found")
        #return
    #EntityManager.entity_removed.disconnect(_on_entity_removed)
    #player_stats.add_health(3)

func _on_entity_stats_out_of_health() -> void:
    super._on_entity_stats_out_of_health()
    do_heal()

func do_heal() -> void:
    var player: = Util.get_player_ref()
    assert(player, "Player not found")
    
    var player_stats: = player.entity_stats as EntityStats
    player_stats.add_health(3)