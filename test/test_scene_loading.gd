extends SceneTree

var scenes_to_test: Array[String] = [
	"res://assets/bg_meshes.tscn",
	"res://assets/player.tscn",
	"res://assets/main_camera.tscn",
	"res://assets/world_scene.tscn",
	"res://assets/new_projectile.tscn",
	"res://assets/level_path.tscn",
	"res://assets/effects/impact_sphere.tscn",
	"res://assets/enemies/enemy_base.tscn",
	"res://assets/enemies/laser_enemy.tscn",
	"res://assets/level/checkpoint_zone.tscn",
	"res://assets/level/enemy_spawner.tscn",
	"res://assets/levels/level2.tscn",
]

func _initialize() -> void:
	var failed: Array[String] = []
	var passed := 0

	print("Testing scene loading...")
	print("=" .repeat(50))

	for scene_path in scenes_to_test:
		if not ResourceLoader.exists(scene_path):
			print("SKIP: %s (file not found)" % scene_path)
			continue

		var scene := load(scene_path) as PackedScene
		if scene == null:
			print("FAIL: %s" % scene_path)
			failed.append(scene_path)
		else:
			print("PASS: %s" % scene_path)
			passed += 1

	print("=" .repeat(50))
	print("Results: %d passed, %d failed" % [passed, failed.size()])

	if failed.size() > 0:
		print("\nFailed scenes:")
		for path in failed:
			print("  - %s" % path)
		quit(1)
	else:
		print("\nAll scenes loaded successfully!")
		quit(0)
