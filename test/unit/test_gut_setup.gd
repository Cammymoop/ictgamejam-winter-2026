extends GutTest
## Simple test to validate GUT testing framework is properly configured


func test_gut_framework_loads() -> void:
	# Verify GUT test class is accessible
	assert_true(true, "GUT framework is properly installed and running")


func test_can_use_basic_assertions() -> void:
	# Verify basic assertion methods work
	assert_eq(1 + 1, 2, "Basic math assertion works")
	assert_ne(1, 2, "Not equal assertion works")
	assert_gt(5, 3, "Greater than assertion works")
	assert_lt(3, 5, "Less than assertion works")


func test_can_use_string_assertions() -> void:
	var test_str := "hello world"
	assert_true(test_str.contains("hello"), "String contains check works")
	assert_eq(test_str.length(), 11, "String length check works")


func test_can_use_array_assertions() -> void:
	var arr := [1, 2, 3, 4, 5]
	assert_eq(arr.size(), 5, "Array size check works")
	assert_has(arr, 3, "Array contains check works")


func test_can_await_frames() -> void:
	# Verify we can use async testing
	var start_frame := Engine.get_process_frames()
	await get_tree().process_frame
	await get_tree().process_frame
	var end_frame := Engine.get_process_frames()
	assert_gt(end_frame, start_frame, "Frame waiting works")


func test_gut_test_base_exists() -> void:
	# Verify our custom base class is loadable
	var base_script := load("res://test/gut_test_base.gd")
	assert_not_null(base_script, "GutTestBase script should load")
