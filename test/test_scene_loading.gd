extends SceneTree

var scenes_to_test: Array[String] = [
	"res://main_game_scene.tscn",
	"res://assets/bg_meshes.tscn",
	"res://assets/player.tscn",
	"res://assets/main_camera.tscn",
	"res://assets/world_scene.tscn",
	"res://assets/new_projectile.tscn",
	"res://assets/effects/impact_sphere.tscn",
	"res://assets/enemies/test_enemy.tscn",
	"res://assets/enemies/test_projectile.tscn",
	"res://assets/enemies/flight_enemy.tscn",
	"res://player/enemy.tscn",
	"res://player/player.tscn",
	"res://player/weapon_manager.tscn",
	"res://player/projectile.tscn",
	"res://ui/lose_screen.tscn",
	"res://ui/win_screen.tscn",
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
			scene = null  # Release reference to allow cleanup

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
