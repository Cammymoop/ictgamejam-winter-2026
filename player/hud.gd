extends Control

var player_stats: EntityStats
@onready var health_ui: Control = find_child("HealthUI")

@onready var weapon_ui: Control = find_child("WeaponUI")

func _ready() -> void:
    var player: = Util.get_player_ref()
    await player.ready
    player_stats = player.entity_stats
    assert(player_stats, "HUD: PlayerStats not found")
    
    health_ui.set_entity_stats(player_stats)