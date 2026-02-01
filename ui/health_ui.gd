extends VBoxContainer

@onready var health_progress_bar: Range = find_child("HealthBar")
@onready var old_health_progress_bar: Range = find_child("OldHealthBar")
@onready var health_bar_cover: Control = find_child("HealthBarCover")
@onready var flash_animator: AnimationPlayer = find_child("FlashAnimator")

var entity_stats: EntityStats = null
var old_health_ratio: float = 1.0

@export var old_health_drop_delay_amt: float = 0.6
@export var old_health_drop_speed: float = 0.1
var old_health_drop_delay_timeleft: float = 0.0

func set_entity_stats(stats: EntityStats) -> void:
    if entity_stats:
        clear_entity_stats()
    entity_stats = stats
    entity_stats.got_hit_damage.connect(_on_entity_stats_got_hit)
    entity_stats.health_changed.connect(_on_entity_stats_health_changed)
    entity_stats.out_of_health.connect(_on_entity_stats_out_of_health)
    update_health_bar()

func _process(delta: float) -> void:
    if old_health_ratio > 0:
        if old_health_drop_delay_timeleft > 0:
            old_health_drop_delay_timeleft -= delta
        else:
            old_health_ratio -= delta * old_health_drop_speed
            if old_health_ratio < minf(0, health_progress_bar.value):
                hide_old_health()
            else:
                old_health_progress_bar.value = old_health_ratio
    elif old_health_progress_bar.value > 0:
        hide_old_health()
        

func _on_entity_stats_got_hit(_damage: float, _damage_ratio: float, _prev_health: float, prev_health_ratio: float) -> void:
    if old_health_ratio == 0:
        old_health_drop_delay_timeleft = old_health_drop_delay_amt
    old_health_ratio = prev_health_ratio
    flash_animator.play("flash")

func _on_entity_stats_health_changed(_new_health: float) -> void:
    update_health_bar()

func _on_entity_stats_out_of_health() -> void:
    health_bar_cover.visible = true

func update_health_bar() -> void:
    var health_ratio = entity_stats.get_health_ratio()
    if old_health_ratio > 0 and health_ratio >= old_health_ratio:
        hide_old_health()
    health_progress_bar.value = health_ratio
    if health_ratio > 0:
        health_bar_cover.visible = false

func hide_old_health() -> void:
    old_health_ratio = 0
    old_health_drop_delay_timeleft = 0
    old_health_progress_bar.value = 0

func clear_entity_stats() -> void:
    if entity_stats.health_changed.is_connected(_on_entity_stats_health_changed):
        entity_stats.health_changed.disconnect(_on_entity_stats_health_changed)
    if entity_stats.out_of_health.is_connected(_on_entity_stats_out_of_health):
        entity_stats.out_of_health.disconnect(_on_entity_stats_out_of_health)
    entity_stats = null
