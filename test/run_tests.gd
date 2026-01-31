@tool
extends SceneTree
## Headless test runner for CI/agent-driven TDD
## Usage: godot --headless -s test/run_tests.gd

const TEST_DIRS := ["res://test/unit/", "res://test/integration/"]
const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1


func _init() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	print("=" .repeat(60))
	print("Running GUT Tests")
	print("=" .repeat(60))

	# Check if GUT is available
	if not ResourceLoader.exists("res://addons/gut/gut.gd"):
		print("\nERROR: GUT addon not installed!")
		print("Install via: ")
		print("  1. Godot Asset Library (search 'GUT')")
		print("  2. Or: git clone https://github.com/bitwes/Gut.git addons/gut")
		print("\nRunning basic validation instead...\n")
		run_basic_validation()
		return

	# Load and run GUT
	var gut_script := load("res://addons/gut/gut.gd")
	var gut = gut_script.new()
	root.add_child(gut)

	# Configure GUT
	gut.add_directory("res://test/unit/")
	gut.add_directory("res://test/integration/")

	# Run and wait for completion
	gut.test_scripts()

	while gut.is_running():
		await process_frame

	# Report results
	var passed: int = gut.get_pass_count()
	var failed: int = gut.get_fail_count()

	print("\n" + "=" .repeat(60))
	print("Results: %d passed, %d failed" % [passed, failed])
	print("=" .repeat(60))

	quit(EXIT_SUCCESS if failed == 0 else EXIT_FAILURE)


func run_basic_validation() -> void:
	## Fallback validation when GUT is not installed
	var passed := 0
	var failed := 0

	# Test 1: EntityStats class exists
	print("Testing EntityStats class...")
	if ClassDB.class_exists("EntityStats") or ResourceLoader.exists("res://assets/general/entity_stats.gd"):
		print("  PASS: EntityStats exists")
		passed += 1
	else:
		print("  FAIL: EntityStats not found")
		failed += 1

	# Test 2: Test files exist
	print("Testing test file structure...")
	var test_files := [
		"res://test/gut_test_base.gd",
		"res://test/unit/test_entity_stats.gd",
	]
	for path in test_files:
		if ResourceLoader.exists(path):
			print("  PASS: %s exists" % path)
			passed += 1
		else:
			print("  FAIL: %s not found" % path)
			failed += 1

	# Test 3: Core game scripts load
	print("Testing core scripts load...")
	var core_scripts := [
		"res://assets/level_path.gd",
		"res://assets/general/entity_stats.gd",
		"res://static/entity_manager.gd",
	]
	for path in core_scripts:
		if ResourceLoader.exists(path):
			var script = load(path)
			if script:
				print("  PASS: %s loads" % path)
				passed += 1
			else:
				print("  FAIL: %s failed to load" % path)
				failed += 1
		else:
			print("  SKIP: %s not found" % path)

	print("\n" + "=" .repeat(60))
	print("Basic Validation: %d passed, %d failed" % [passed, failed])
	print("=" .repeat(60))
	print("\nNote: Install GUT for full test suite execution")

	quit(EXIT_SUCCESS if failed == 0 else EXIT_FAILURE)
