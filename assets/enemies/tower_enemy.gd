extends EnemyBase

var projectile_scene: PackedScene = preload("res://assets/general/projectile.tscn")

class Timers:
    const DELAY = "delay"
    const ACTIVE_CHECK = "active_check"
    const RELOAD = "reload"
    const MIN_ACTIVE = "minimum_active"

@export var shoot_from: Node3D = null

@export var active_distance: float = 57

@export var use_shield: bool = true
@export var shield_on_when_inactive: bool = true

@export var show_before_shoot: Node3D

@onready var shield_mesh: MeshInstance3D = find_child("Shield")
@onready var shield_body: CollisionObject3D = shield_mesh.get_node("StaticBody3D")
@onready var shield_collider: CollisionShape3D = shield_body.get_node("CollisionShape3D")

@onready var shake_offset: Node3D = find_child("Shake")

@export_group("Weapon Properties")
@export var bullet_speed: float = 90
@export var bullet_lifetime: float = 6
@export var bullet_color: Color = Color.ORANGE
@export var innacuracy: float = TAU / 32
@export_exp_easing var innacuracy_curve_param: float = 1

@export_group("Timing")
@export var fire_rate: float = 0.2
@export var delay_chance: float = 0.2
@export var min_time_before_shield: float = 1
@export var delay_base_time: float = 2.0
@export var active_check_interval: float = 0.5

@export_group("Animations")
@export var show_warning_time: float = 0.3
@export var shake_strength: float = 0.2
@onready var active_animator: AnimationPlayer = find_child("ActiveAnimator")

@export_group("Debug")
@export var show_debug_path: bool = false

var active_check_waiting: bool = false

var is_shooting: bool = false

var is_enabled: bool = true
var is_active: bool = false
var is_shaking: bool = false

func _ready() -> void:
    super._ready()
    if show_before_shoot:
        show_before_shoot.visible = false
        show_before_shoot.material_override.albedo_color = bullet_color
    
    active_animator.animation_finished.connect(_on_active_animator_animation_finished)
    
    show_warning_time = minf(show_warning_time, (1 / fire_rate) * 0.75)
    
    timer_set.add_timer(Timers.DELAY, delay_base_time, delay_over)
    timer_set.add_timer(Timers.ACTIVE_CHECK, active_check_interval, active_check_ready, true)
    timer_set.add_timer(Timers.RELOAD, 1 / fire_rate)
    timer_set.add_timer(Timers.MIN_ACTIVE, min_time_before_shield)
    
    if (not use_shield or not shield_on_when_inactive) and is_shield_active():
        turn_off_shield()
    
    if use_shield:
        entity_stats.check_can_be_hit = can_enemy_be_hit
    
    set_player_ref()
    if not player_ref:
        disable()
    else:
        var starting_active: = true
        if player_ref.global_position.distance_to(global_position) < active_distance:
            try_activate()
            if active_check_waiting:
                starting_active = false
        else:
            starting_active = false
        
        if not starting_active:
            active_animator.play("RESET_inactive")
    
    var los_checker: = find_child("LineOfSightChecker") as ShapeCast3D
    if los_checker:
        los_checker.add_exception(shield_body)

func can_enemy_be_hit() -> bool:
    return not is_shield_active()

func is_shield_active() -> bool:
    return shield_mesh.visible

func turn_on_shield() -> void:
    var anim: = shield_mesh.get_node("AnimationPlayer") as AnimationPlayer
    if anim:
        anim.play("show")
    else:
        shield_mesh.visible = true
    shield_collider.set_deferred("disabled", false)

func turn_off_shield() -> void:
    var anim: = shield_mesh.get_node("AnimationPlayer") as AnimationPlayer
    if anim:
        anim.play("hide")
    else:
        shield_mesh.visible = false
    shield_collider.set_deferred("disabled", true)

func disable() -> void:
    is_enabled = false

func random_delay() -> void:
    is_shooting = false
    timer_set.start(Timers.DELAY, delay_base_time * randf_range(.8, 1.5))
    if use_shield and not is_shield_active():
        turn_on_shield()

func delay_over() -> void:
    is_shooting = true
    if use_shield and is_shield_active():
        turn_off_shield()

func active_check_ready() -> void:
    active_check_waiting = false

func try_activate(recheck: bool = false) -> void:
    if is_active and not recheck:
        return

    var los_checker: = find_child("LineOfSightChecker") as ShapeCast3D
    if not los_checker and not is_active:
        print_debug("This enemy has no line of sight checker")
        activate()
        return

    if show_debug_path and not los_checker.visible:
        los_checker.visible = true
    
    los_checker.enabled = true
    los_checker.target_position = los_checker.to_local(get_player_global_pos())
    los_checker.force_shapecast_update()
    
    if los_checker.is_colliding():
        if is_active:
            deactivate()
        active_check_waiting = true
        timer_set.start(Timers.ACTIVE_CHECK)
    else:
        activate()


func activate() -> void:
    active_animator.play("activate")

func _on_active_animator_animation_finished(anim_name: String) -> void:
    if not is_active and anim_name == "activate":
        activate_done()

func activate_done() -> void:
    timer_set.start(Timers.MIN_ACTIVE)
    active_check_waiting = false
    is_active = true
    random_delay()

func deactivate() -> void:
    is_active = false
    active_animator.play("deactivate")
    if use_shield and shield_on_when_inactive:
        turn_on_shield()

func _process(_delta: float) -> void:
    if show_before_shoot:
        show_before_shoot.visible = false
    if is_shaking:
        if randf() < 0.4:
            var rand_shake: = Vector3(randf() * shake_strength, randf() * shake_strength, randf() * shake_strength)
            shake_offset.position = rand_shake * 2 - (Vector3.ONE * shake_strength)
            
    if not is_enabled:
        return
    
    var player_distance = get_distance_to_player()
    if not is_active:
        if player_distance < active_distance and not active_check_waiting:
            try_activate()
    elif player_distance > active_distance + 5:
        deactivate()
    
    if not is_shooting or not is_active:
        return
    
    var reload_timeleft: = timer_set.time_left(Timers.RELOAD)
    var is_reloading: = reload_timeleft > 0
    if is_reloading:
        if show_before_shoot:
            show_before_shoot.visible = reload_timeleft < show_warning_time
    
    if is_shooting and not is_reloading:
        fire()
        if randf() < delay_chance:
            random_delay()
        else:
            timer_set.start(Timers.RELOAD)

func fire() -> void:
    var start_pos = global_position
    if shoot_from:
        start_pos = shoot_from.global_position

    var player_pos = get_player_global_pos()
    var dist_to_player = start_pos.distance_to(player_pos)
    var player_pos_estimated = player_pos + (Global.player_velocity * (dist_to_player / bullet_speed))

    var projectile = projectile_scene.instantiate()
    PhysicsServer3D.body_add_collision_exception(projectile.get_rid(), shield_body.get_rid())
    projectile.set_color(bullet_color)

    projectile.speed = bullet_speed
    projectile.is_enemy_projectile = true
    var fire_dir: = (player_pos_estimated - start_pos).normalized()
    var fire_basis: = Basis.looking_at(fire_dir, Vector3.UP)
    fire_dir = fire_dir.rotated(fire_basis.x, ease(randf(), innacuracy_curve_param) * innacuracy)
    fire_dir = fire_dir.rotated(fire_basis.z, randf_range(0, TAU))
    
    projectile.set_direction(fire_dir)
    
    projectile.damage = 1

    SpawnInWorld.spawn(projectile, start_pos)
    
    if show_debug_path:
        draw_debug_path(start_pos, player_pos_estimated)

func draw_debug_path(start_pos: Vector3, end_pos: Vector3) -> void:
    var debug_path: = Path3D.new()
    debug_path.curve = Curve3D.new()
    for point in [start_pos, end_pos]:
        debug_path.curve.add_point(point)
    get_node("/root/Game").add_child(debug_path)
    await get_tree().create_timer(8).timeout
    debug_path.queue_free()

func _on_entity_stats_got_hit() -> void:
    super._on_entity_stats_got_hit()
    damage_anim_material()

func _on_entity_stats_out_of_health() -> void:
    if show_before_shoot:
        show_before_shoot.visible = false
        turn_off_shield()
    is_shaking = true
    is_enabled = false
    super._on_entity_stats_out_of_health()

func damage_anim_material() -> void:
    var health_ratio = entity_stats.health / entity_stats.max_health
    var material: = find_child("MeshInstance3D").material_override as StandardMaterial3D
    if not material:
        print_debug("Material not found")
        return
    material.detail_enabled = health_ratio < 0.99
    var mask_gradient: Gradient = material.detail_mask.color_ramp as Gradient
    mask_gradient.set_offset(1, health_ratio)

func death_anim_over(anim_name: String) -> void:
    if anim_name != "death":
        return
    queue_free()