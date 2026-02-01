extends RefCounted

const SplineMath = preload("res://static/spline_math.gd")

func test_cardinal_extrapolate_1d_basic() -> bool:
	var pts: Array[float] = [0.0, 1.0, 2.0]
	var result: Array[float] = SplineMath.cardinal_extrapolated_1d(pts)
	# Should add extrapolated point at start and end
	if result.size() != 5:
		return false
	# First point should be 0 - (1 - 0) = -1
	if not is_equal_approx(result[0], -1.0):
		return false
	# Last point should be 2 + (2 - 1) = 3
	if not is_equal_approx(result[4], 3.0):
		return false
	return true

func test_cardinal_extrapolate_1d_single_point() -> bool:
	var pts: Array[float] = [5.0]
	var result: Array[float] = SplineMath.cardinal_extrapolated_1d(pts)
	# Single point should duplicate
	if result.size() != 3:
		return false
	return is_equal_approx(result[0], 5.0) and is_equal_approx(result[2], 5.0)

func test_cardinal_extrapolate_2d_basic() -> bool:
	var pts: Array[Vector2] = [Vector2(0, 0), Vector2(1, 1), Vector2(2, 0)]
	var result: Array[Vector2] = SplineMath.cardinal_extrapolated_2d(pts)
	if result.size() != 5:
		return false
	# First extrapolated point
	var expected_first := Vector2(0, 0) * 2 - Vector2(1, 1)
	if not result[0].is_equal_approx(expected_first):
		return false
	return true

func test_cardinal_extrapolate_3d_basic() -> bool:
	var pts: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1, 1, 1), Vector3(2, 2, 2)]
	var result: Array[Vector3] = SplineMath.cardinal_extrapolated_3d(pts)
	if result.size() != 5:
		return false
	return true

func test_lerp_arr() -> bool:
	var a: Array = [0.0, 0.0]
	var b: Array = [10.0, 20.0]
	var result: Array = SplineMath.lerp_arr(a, b, 0.5)
	if result.size() != 2:
		return false
	if not is_equal_approx(result[0], 5.0):
		return false
	if not is_equal_approx(result[1], 10.0):
		return false
	return true

func test_partial_bezier_2d() -> bool:
	var p0 := Vector2(0, 0)
	var h0 := Vector2(1, 0)
	var h1 := Vector2(-1, 0)
	var p1 := Vector2(2, 0)
	var result: Array[Vector2] = SplineMath.partial_bezier_2d(p0, h0, h1, p1, 0.5)
	# Should return 2 points
	if result.size() != 2:
		return false
	return true

func test_get_implicit_tangents_3d_empty() -> bool:
	var pts: Array[Vector3] = []
	var result: Array[Vector3] = SplineMath.get_implicit_tangents_3d(pts, true)
	return result.size() == 0

func test_get_implicit_tangents_3d_two_points() -> bool:
	var pts: Array[Vector3] = [Vector3.ZERO, Vector3.ONE]
	var result: Array[Vector3] = SplineMath.get_implicit_tangents_3d(pts, true)
	# 2 input points get extrapolated to 4 points, which yields 2 inner tangents
	return result.size() == 2

func test_create_1d_spline() -> bool:
	var control_pts: Array[float] = [0.0, 0.5, 1.0]
	var control_vals: Array = [0.0, 1.0, 0.0]
	var spline: Array = SplineMath.create_1d_spline(0.5, control_pts, control_vals)
	# Should return array with [points, velocities, values]
	if spline.size() != 3:
		return false
	if spline[SplineMath.SPPOINT].size() != 3:
		return false
	return true

func test_get_1d_spline_segment_idx() -> bool:
	var control_pts: Array[float] = [0.0, 0.5, 1.0]
	var control_vals: Array = [0.0, 1.0, 0.0]
	var spline: Array = SplineMath.create_1d_spline(0.5, control_pts, control_vals)

	var seg0: int = SplineMath.get_1d_spline_segment_idx(spline, 0.25)
	var seg1: int = SplineMath.get_1d_spline_segment_idx(spline, 0.75)

	return seg0 == 0 and seg1 == 1
