extends RigidBody3D

var hit_impact_scn: PackedScene = preload("res://assets/effects/impact_sphere.tscn")
var non_hit_impact_scn: PackedScene = preload("res://assets/effects/impact_spark.tscn")

@export var damage: float = 10.0
@export var speed: float = 30.0
@export var lifetime: float = 5.0
@export var impace_scale: float = 1.0

@export var anim_modulate: Color = Color.WHITE

@onready var mesh_mat: StandardMaterial3D = find_child("MeshInstance3D").material_override as StandardMaterial3D

var lifetime_timer: Timer = null

var is_enemy_projectile: bool = false:
	set(value):
		is_enemy_projectile = value
		var enemy_coll_layer: = Util.get_phys_layer_by_name("Enemies")
		var player_coll_layer: = Util.get_phys_layer_by_name("Player")
		if is_enemy_projectile:
			set_collision_mask_value(enemy_coll_layer, false)
			set_collision_mask_value(player_coll_layer, true)
		else:
			set_collision_mask_value(enemy_coll_layer, true)
			set_collision_mask_value(player_coll_layer, false)

var bullet_color: Color = Color.WHITE

func _ready() -> void:
	# Start lifetime timer
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = lifetime
	add_child(lifetime_timer)
	lifetime_timer.start()
	lifetime_timer.timeout.connect(_on_lifetime_expired)

	# Connect body entered signal
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	update_mesh_color()

	var anim_player: = $AnimationPlayer
	if not anim_player.is_playing() and lifetime_timer.time_left <= 0.71:
		anim_player.play("out")

func set_direction(direction: Vector3) -> void:
	linear_velocity = direction * speed
	basis = Basis.looking_at(direction, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	#print("projectile hit body: %s" % body.get_path())
	#if Util.check_coll_layer(body, "Player"):
		#return  # Don't hit the player who fired

	var hit_something = false
	var entity = EntityManager.get_entity_from_coll_object(body)
	if entity:
		hit_something = EntityManager.hit_entity(entity, damage)

	elif body.has_method("take_damage"):
		body.take_damage(damage)
		hit_something = true

	if hit_something:
		show_hit_imact()
	else:
		show_non_hit_imact()

	_destroy()

func _on_lifetime_expired() -> void:
	_destroy()

func show_hit_imact() -> void:
	var impact := hit_impact_scn.instantiate()
	get_parent().add_child(impact)
	impact.global_position = global_position
	impact.scale = Vector3.ONE * impace_scale

func show_non_hit_imact() -> void:
	var impact := non_hit_impact_scn.instantiate()
	get_parent().add_child(impact)
	impact.global_position = global_position
	impact.scale = Vector3.ONE * impace_scale

func _destroy() -> void:
	queue_free()

func set_color(color: Color) -> void:
	bullet_color = color

func update_mesh_color() -> void:
	if mesh_mat:
		mesh_mat.emission = bullet_color * anim_modulate
