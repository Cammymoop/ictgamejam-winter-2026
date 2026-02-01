extends SceneTree

var test_scripts: Array[String] = []
var total_passed := 0
var total_failed := 0

func _initialize() -> void:
	print("=" .repeat(60))
	print("Running Tests")
	print("=" .repeat(60))

	discover_tests()

	for script_path in test_scripts:
		run_test_script(script_path)

	print("=" .repeat(60))
	print("Final Results: %d passed, %d failed" % [total_passed, total_failed])
	print("=" .repeat(60))

	quit(1 if total_failed > 0 else 0)

func discover_tests() -> void:
	var dir := DirAccess.open("res://test/unit")
	if dir == null:
		print("Warning: Could not open test/unit directory")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gd") and file_name.begins_with("test_"):
			test_scripts.append("res://test/unit/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	test_scripts.sort()

func run_test_script(script_path: String) -> void:
	print("\n[%s]" % script_path.get_file())

	var script := load(script_path) as GDScript
	if script == null:
		print("  FAIL: Could not load script")
		total_failed += 1
		return

	var test_instance: Object = script.new()

	for method in test_instance.get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			run_single_test(test_instance, method_name)

	if test_instance.has_method("_cleanup"):
		test_instance._cleanup()

	# Ensure proper cleanup of test instance
	test_instance = null

func run_single_test(instance: Object, method_name: String) -> void:
	var result: Variant = instance.call(method_name)

	if result is bool:
		if result:
			print("  PASS: %s" % method_name)
			total_passed += 1
		else:
			print("  FAIL: %s" % method_name)
			total_failed += 1
	elif result is String:
		print("  FAIL: %s - %s" % [method_name, result])
		total_failed += 1
	else:
		print("  PASS: %s" % method_name)
		total_passed += 1
