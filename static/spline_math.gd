class_name SplineMath
extends Object

const SPPOINT = 0
const SPVEL = 1
const SPVAL = 2

const SAMPLER_ANCHORS = 0
const SAMPLER_SEGMENTS = 1

const TEN_ADJ_DEF: float = 0.32

static func create_1d_spline(tension: float, control_points: Array[float], control_values: Array, with_discontinuous_values: bool = false) -> Array:
	var extended_pts: = cardinal_extrapolated_1d(control_points)
	var sp_velocities: Array[float] = []
	sp_velocities.resize(control_points.size())
	for base_i in control_points.size():
		var e_i: = base_i + 1
		sp_velocities[base_i] = tension * (extended_pts[e_i+1] - extended_pts[e_i-1]) / 3.0
	
	var sp_values: Array = []
	if not with_discontinuous_values:
		for i in control_values.size():
			sp_values.append(control_values[i])
			sp_values.append(control_values[i])
	else:
		sp_values = control_values
	
	var debug_ext: Array[float] = []
	for e in extended_pts.size():
		debug_ext.append(snappedf(extended_pts[e], 0.01))
	
	var debug_vel: Array[float] = []
	for v in sp_velocities:
		debug_vel.append(snappedf(v*3, 0.01))
	#print("New 1D spline, velocities: ", debug_vel, " control points: ", debug_ext)

	return [control_points, sp_velocities, sp_values]

static func get_1d_spline_interp_factor(spline_arr: Array, t: float) -> float:
	var seg: int = get_1d_spline_segment_idx(spline_arr, t)
	var segment_start: float = spline_arr[SPPOINT][seg]
	var segment_length: float = spline_arr[SPPOINT][seg + 1] - segment_start

	var normalized_t: float = (t - segment_start) / segment_length
	return get_1d_spline_interp_for_segment(spline_arr, seg, normalized_t)

static func get_1d_spline_interp_for_segment(spline_arr: Array, seg: int, seg_t: float) -> float:
	var point_a: float = spline_arr[SPPOINT][seg]
	var point_b: float = spline_arr[SPPOINT][seg + 1]
	var local_result: float = bezier_interpolate(point_a, point_a - spline_arr[SPVEL][seg], point_b + spline_arr[SPVEL][seg+1], point_b, seg_t) 
	return (local_result - point_a) / (point_b - point_a)

static func sample_1d_spline_segment(spline_arr: Array, segment_idx: int, t: float) -> Variant:
	var segment_start: float = spline_arr[SPPOINT][segment_idx]
	var segment_length: float = spline_arr[SPPOINT][segment_idx + 1] - segment_start

	var normalized_t: float = (t - segment_start) / segment_length
	var interp_factor: float = get_1d_spline_interp_for_segment(spline_arr, segment_idx, normalized_t)
	var idx_from: int = segment_idx*2 + 1
	var idx_to: int = (segment_idx+1) * 2
	if typeof(spline_arr[SPVAL][segment_idx]) == TYPE_ARRAY:
		#print("lerping arrays: ")
		#print(spline_arr[SPVAL][idx_from])
		#print(spline_arr[SPVAL][idx_to])
		return lerp_arr(spline_arr[SPVAL][idx_from], spline_arr[SPVAL][idx_to], interp_factor)
	else:
		return lerp(spline_arr[SPVAL][idx_from], spline_arr[SPVAL][idx_to], interp_factor)

static func get_1d_spline_control_point_in_out(spline_arr: Array, point_idx: int) -> Array:
	return [ spline_arr[SPVAL][point_idx*2],
			spline_arr[SPVAL][point_idx*2 + 1] ]

static func get_1d_spline_segment_in_out(spline_arr: Array, segment_idx: int) -> Array:
	return [ spline_arr[SPVAL][segment_idx*2 + 1],
			spline_arr[SPVAL][(segment_idx+1)*2] ]

static func get_1d_spline_segment_idx(spline_arr: Array, t: float) -> int:
	for i in spline_arr[SPPOINT].size() - 1:
		if spline_arr[SPPOINT][i + 1] >= t:
			return i
	print_debug("get_1d_spline_segment_idx: t: %s not found in spline" % t)
	return 0

static func sample_1d_spline_at(spline_arr: Array, t: float) -> Variant:
	var seg_idx: int = get_1d_spline_segment_idx(spline_arr, t)
	return sample_1d_spline_segment(spline_arr, seg_idx, t)

static func lerp_arr(values_a: Array, values_b: Array, interp_factor: float) -> Array:
	var result: Array = []
	for i in values_a.size():
		result.append(lerp(values_a[i], values_b[i], interp_factor))
	return result


# returns a dictionary of "1d samplers" for a set of named float values specified at anchor points. see function_like_2d_spline_to_1d_sampler
static func make_scalar_cardinal_sampler_bundle(tension: float, anchor_points: Array[float], values: Dictionary[String, Array]) -> Dictionary[String, Array]:
	var doubled_values: Dictionary[String, Array] = {}
	for key in values.keys():
		var doubled_values_k: Array[float] = []
		for i in values[key].size():
			doubled_values_k.append(values[key][i])
			doubled_values_k.append(values[key][i])
		doubled_values[key] = doubled_values_k
	return make_scalar_cardinal_sampler_bundle_discontinuous(tension, anchor_points, doubled_values)

static func make_scalar_cardinal_sampler_bundle_discontinuous(tension: float, anchor_points: Array[float], values: Dictionary[String, Array]) -> Dictionary[String, Array]:
	var samplers: Dictionary[String, Array] = {}
	var num_anchors: int = anchor_points.size()
	print(values.keys())
	for value_name in values.keys():
		var anchor_positions: Array[Vector2] = []
		for i in num_anchors:
			anchor_positions.append(Vector2(anchor_points[i], values[value_name][i*2]))
			anchor_positions.append(Vector2(anchor_points[i], values[value_name][i*2 + 1]))

		var extended_anchor_pos: Array[Vector2] = anchor_positions.duplicate()
		cardinal_extrapolate_2d_discontinuous(extended_anchor_pos)
		var handle_vectors: Array[Vector2] = []
		for base_i in num_anchors:
			var e_i: = base_i + 1
			var prev_out: Vector2 = extended_anchor_pos[(e_i-1)*2 + 1]
			var next_in: Vector2 = extended_anchor_pos[(e_i+1)*2]
			var auto_handle: Vector2 = tension * (next_in - prev_out) / 3.0
			handle_vectors.append(auto_handle)
			handle_vectors.append(auto_handle)
		samplers[value_name] = function_like_2d_spline_to_1d_sampler(anchor_positions, handle_vectors, 20, value_name == "width_right")
	return samplers


# requires a set of anchor positions and handle vectors that play nicely as a graph of a function of x, with y being the result of said function
# anchor points and handles are doubled at each x position, the anchor points can be discontinuous in both y value and handle direction as long as
#   the intervals between them are function-like
# positions should be sorted by x and the first postion should be at x=0 and the last at x=1
# the first handle in a pair (in handle of an anchor, out handle of a segment) is implicityly reflected around the anchor point, 
#   so it should go in the same direction as the curve's tangent as opposed to a typical bezier handle, and if the velocity at the
#   anchor point is continuous, then the anchor's in handle should be equal to it's out handle
# returned sampler format:
# [anchor_points: Array[float], segment_curves: Array[Curve]]
static func function_like_2d_spline_to_1d_sampler(positions: Array[Vector2], handle_vectors: Array[Vector2], segment_resolution: int = 100, with_debug: bool = false) -> Array[Array]:
	var num_anchors: int = floori(positions.size()/2.)
	if num_anchors < 2:
		print_debug("function-like 2d spline to 1d sampler: need at least 2 anchors to create a sampler")
		return [[], [], [], []]
	for i in positions.size():
		if handle_vectors[i].x < 0.01 * absf(handle_vectors[i].y):
			print_debug("function-like 2d spline to 1d sampler: handle passed in is incompatible with a function-like sampler")
			print_debug("point index: ", floori(i/2.0), " (out)" if i%2 == 1 else " (in)", " handle: ", handle_vectors[i])
			return [[], [], [], []]
	
	var anchor_points: Array[float] = []
	for i in num_anchors:
		anchor_points.append(positions[i*2].x)
	
	# note that the first of the first and second of the last anchor position and handle pairs are not used, but they are still present
	var segment_curves: Array[Curve] = []
	for segment_idx in range(num_anchors - 1):
		var seg_in: = positions[segment_idx*2 + 1]
		var seg_out: = positions[(segment_idx+1)*2]
		var handle_in: = handle_vectors[segment_idx*2 + 1]
		var handle_out: = -handle_vectors[(segment_idx+1)*2]
		
		var segment_curve: Curve = Curve.new()
		segment_curve.bake_resolution = segment_resolution * 5
		segment_curve.min_domain = seg_in.x
		segment_curve.max_domain = seg_out.x
		
		var min_val: float = 0
		var max_val: float = 0

		var points: Array[Vector2] = []
		var tangents_of_angles: Array[float] = []

		#var angle_0
		var partial_0
		for i in segment_resolution:
			var seg_t: float = float(i) / float(segment_resolution - 1)
			var partial_bezier: = partial_bezier_2d(seg_in, handle_in, handle_out, seg_out, seg_t)
			var point: = partial_bezier[0].lerp(partial_bezier[1], seg_t)
			points.append(point)
			min_val = minf(min_val, point.y)
			max_val = maxf(max_val, point.y)
			var angle: = (partial_bezier[1] - partial_bezier[0]).angle()
			tangents_of_angles.append(tan(angle))
			#var diff: = partial_bezier[1] - partial_bezier[0]
			#diff.x /= seg_out.x - seg_in.x
			if i == 0:
				partial_0 = partial_bezier
				#angle_0 = angle
			#segment_curve.add_point(point, tan(angle), tan(angle))
			#segment_curve.add_point(point, rad_to_deg(diff.angle()), rad_to_deg(diff.angle()))
		segment_curve.min_value = min_val
		segment_curve.max_value = max_val
		for i in points.size():
			segment_curve.add_point(points[i], tangents_of_angles[i], tangents_of_angles[i])
		segment_curve.bake()
		segment_curves.append(segment_curve)
		if with_debug:
			#DebugAssist.put_curve_in_scene(segment_curve.duplicate())
			prints("segment_idx:", segment_idx, "value:", segment_curve.get_point_position(0).y, "anchor_pos:", seg_in, "partial bezier:", partial_0)
	return [anchor_points, segment_curves]

# returns the 2 points that when interpolated by t give the final bezier result, these points can be used to get the slope of the resulting curve
static func partial_bezier_2d(point_a: Vector2, handle_a: Vector2, handle_b: Vector2, point_b: Vector2, t: float) -> Array[Vector2]:
	var interp_point_a: = point_a.lerp(point_a + handle_a, t)
	var interp_point_b: = (point_a + handle_a).lerp(point_b + handle_b, t)
	var interp_point_c: = (point_b + handle_b).lerp(point_b, t)
	return [interp_point_a.lerp(interp_point_b, t), interp_point_b.lerp(interp_point_c, t)]


static func sample_scalar_sampler(sampler: Array, t: float) -> float:
	var anchor_idx: int = 0 if t <= 0 else -1
	if t > 0:
		for i in sampler[SAMPLER_ANCHORS].size():
			if sampler[SAMPLER_ANCHORS][i] > t:
				anchor_idx = i - 1
				break
	if anchor_idx == -1:
		print_debug("sample_scalar_sampler: t: %s out of range of the sampler" % t)
		return 0
	return sample_scalar_sampler_segment(sampler, anchor_idx, t)

static func sample_scalar_sampler_segment(sampler: Array, segment_idx: int, t: float) -> float:
	return (sampler[SAMPLER_SEGMENTS][segment_idx] as Curve).sample_baked(t)

# get the value coming into an anchor point and going out of it, which may be discontinuous
static func get_scalar_sampler_anchor_in_out(sampler: Array, anchor_idx: int) -> Array[float]:
	if sampler[SAMPLER_SEGMENTS].size() == 0:
		return [0.0, 0.0]
	var has_in: bool = anchor_idx > 0
	var has_out: bool = anchor_idx < sampler[SAMPLER_SEGMENTS].size()
	var in_val: float = 0.0
	var out_val: float = 0.0
	if has_in:
		in_val = sampler[SAMPLER_SEGMENTS][anchor_idx-1].get_point_position(sampler[SAMPLER_SEGMENTS][anchor_idx-1].point_count - 1).y
	if has_out:
		out_val = sampler[SAMPLER_SEGMENTS][anchor_idx].get_point_position(0).y
	return [in_val if has_in else out_val, out_val if has_out else in_val]



static func get_implicit_tangents_3d(pts: Array[Vector3], normalized: bool) -> Array[Vector3]:
	return get_implicit_inner_tangents_3d(cardinal_extrapolated_3d(pts), normalized)

static func get_implicit_inner_tangents_3d(pts: Array[Vector3], normalized: bool) -> Array[Vector3]:
	if pts.size() <= 2:
		return []
	if pts.size() == 3:
		return [Vector3.FORWARD]
	var tangents: Array[Vector3] = []
	tangents.resize(pts.size() - 2)
	for t_i in tangents.size():
		var p_i: = t_i + 1
		tangents[t_i] = pts[p_i+1] - pts[p_i-1]
		if normalized:
			tangents[t_i] = tangents[t_i].normalized()
	return tangents

func get_implicit_tangents_2d(pts: Array[Vector2], normalized: bool) -> Array[Vector2]:
	return get_implicit_inner_tangents_2d(cardinal_extrapolated_2d(pts), normalized)

static func get_implicit_inner_tangents_2d(pts: Array[Vector2], normalized: bool) -> Array[Vector2]:
	if pts.size() <= 2:
		return []
	if pts.size() == 3:
		return [Vector2.RIGHT]
	var tangents: Array[Vector2] = []
	tangents.resize(pts.size() - 2)
	for t_i in tangents.size():
		var p_i: = t_i + 1
		tangents[t_i] = pts[p_i+1] - pts[p_i-1]
		if normalized:
			tangents[t_i] = tangents[t_i].normalized()
	return tangents



# helper functions for setting/getting Curve3D/2D control points via arrays positions including extra points at the start/end for use with splines that require them
# Updates existing curve3D with new list of extended control points, the curve does not need to have the same number of points to start with
# Curve3D helpers
static func set_curve3d_extended_control_points(curve: Curve3D, control_points: Array[Vector3]) -> void:
	if control_points.size() <= 2:
		print_debug("set_curve3d_extended_control_points: cant set extended points without at least 1 internal point")
		curve.clear_points()
		return
	set_curve3d_control_points(curve, control_points.slice(1, -1))
	# outer control points set as relative to align with expected behavior of bezier control points in Curve3D
	curve.set_point_out(curve.point_count - 1, control_points[-1] - control_points[-2])
	curve.set_point_in( 0,                     control_points[ 0] - control_points[ 1])
# NOTE: also clears extra outer bezier handles
static func set_curve3d_control_points(curve: Curve3D, control_points: Array[Vector3]) -> void:
	curve.clear_points()
	for i in control_points.size():
		curve.add_point(control_points[i])

static func get_curve3d_extended_control_points(curve: Curve3D, extrapolate_end_points: bool = false) -> Array[Vector3]:
	if curve.point_count < 1:
		return []
	if extrapolate_end_points:
		return get_curve3d_cardinal_extrapolated_control_points(curve)
	else:
		var cps: Array[Vector3] = get_curve3d_control_points(curve)
		cps.push_back( cps[-1] + curve.get_point_out(curve.point_count - 1))
		cps.push_front(cps[ 0] + curve.get_point_in( 0))
		return cps
static func get_curve3d_cardinal_extrapolated_control_points(curve: Curve3D) -> Array[Vector3]:
	return cardinal_extrapolated_3d(get_curve3d_control_points(curve))
static func get_curve3d_control_points(curve: Curve3D) -> Array[Vector3]:
	var control_points: Array[Vector3] = []
	for i in curve.point_count:
		control_points.append(curve.get_point_position(i))
	return control_points

static func new_curve3d_with_extended_control_points(control_points: Array[Vector3]) -> Curve3D:
	var new_curve: = Curve3D.new()
	set_curve3d_extended_control_points(new_curve, control_points)
	return new_curve

static func curve3d_copy_extended_control_points(curve_from: Curve3D, curve_to: Curve3D) -> void:
	set_curve3d_extended_control_points(curve_to, get_curve3d_extended_control_points(curve_from))

# Curve2D helpers
static func set_curve2d_extended_control_points(curve: Curve2D, control_points: Array[Vector2]) -> void:
	if control_points.size() <= 2:
		print_debug("set_curve2d_extended_control_points: cant set extended points without at least 1 internal point")
		curve.clear_points()
		return
	set_curve2d_control_points(curve, control_points.slice(1, -1))
	curve.set_point_out(curve.point_count - 1, control_points[-1] - control_points[-2])
	curve.set_point_in( 0,                     control_points[ 0] - control_points[ 1])
# NOTE: also clears extra outer bezier handles
static func set_curve2d_control_points(curve: Curve2D, control_points: Array[Vector2]) -> void:
	curve.clear_points()
	for i in control_points.size():
		curve.add_point(control_points[i])

static func get_curve2d_extended_control_points(curve: Curve2D, extrapolate_end_points: bool = false) -> Array[Vector2]:
	if curve.point_count < 1:
		return []
	if extrapolate_end_points:
		return get_curve2d_cardinal_extrapolated_control_points(curve)
	else:
		var cps: Array[Vector2] = get_curve2d_control_points(curve)
		cps.push_back( cps[-1] + curve.get_point_out(curve.point_count - 1))
		cps.push_front(cps[ 0] + curve.get_point_in(0))
		return cps
static func get_curve2d_cardinal_extrapolated_control_points(curve: Curve2D) -> Array[Vector2]:
	return cardinal_extrapolated_2d(get_curve2d_control_points(curve))
static func get_curve2d_control_points(curve: Curve2D) -> Array[Vector2]:
	var control_points: Array[Vector2] = []
	for i in curve.point_count:
		control_points.append(curve.get_point_position(i))
	return control_points

static func new_curve2d_with_extended_control_points(control_points: Array[Vector2]) -> Curve2D:
	var new_curve: = Curve2D.new()
	set_curve2d_extended_control_points(new_curve, control_points)
	return new_curve

static func curve2d_copy_extended_control_points(curve_from: Curve2D, curve_to: Curve2D) -> void:
	set_curve2d_extended_control_points(curve_to, get_curve2d_extended_control_points(curve_from))



##################
# Curve3D/Curve2D based implementation of cardinal/catmull rom 3d/2d space spline curve
# Can be sampled weighted by curvature or evenly distributed by approximate arc length
# sampling based on input domain could be done manually as well, using sample() or samplef()

# Update a Curve3D to be a valid cardinal/catmull rom spline curve along the existing control points
# The unused in/out bezier control points for the first and last points are used as the extra control points required by the spline
# If extrapolate_end_points is true, these extra points will be generated and saved to the unused slots
static func update_catmull_rom_curve3d(curve: Curve3D, extrapolate_end_points: bool = true) -> void:
	update_cardinal_spline_curve3d(curve, 0.5, extrapolate_end_points)
static func update_cardinal_spline_curve3d(curve: Curve3D, tension: float, extrapolate_end_points: bool = true, tension_adjustment_param: float = TEN_ADJ_DEF) -> void:
	if curve.point_count < 1:
		return
	if extrapolate_end_points:
		curve3d_cardinal_extrapolate(curve)

	var extended_pts: = get_curve3d_extended_control_points(curve)
	var last: = curve.point_count - 1

	print(tension)
	for base_i in curve.point_count:
		var e_i: = base_i + 1
		var tension_adjustment_factor: float = 1.0
		if tension_adjustment_param != 0:
			var relative_a_dist: = (extended_pts[e_i+1] - extended_pts[e_i]).length()
			var relative_b_dist: = (extended_pts[e_i-1] - extended_pts[e_i]).length()
			var relative_dist_ratio: = minf(relative_a_dist, relative_b_dist) / maxf(relative_a_dist, relative_b_dist)
			tension_adjustment_factor = ease(relative_dist_ratio, tension_adjustment_param)
		# a factor of 1/3 converts (velocity length) tangents to bezier in/out handle vectors
		var out_vec: Vector3 = tension_adjustment_factor * tension * (extended_pts[e_i+1] - extended_pts[e_i-1]) / 3.0
		if base_i > 0:    curve.set_point_in(base_i, -out_vec)
		if base_i < last: curve.set_point_out(base_i, out_vec)

# non-in-place version
static func curve3d_catmull_rommed(curve: Curve3D, extrapolate_end_points: bool = true) -> Curve3D:
	return curve3d_cardinal_splined(curve, 0.5, extrapolate_end_points)
static func curve3d_cardinal_splined(curve: Curve3D, tension: float, extrapolate_end_points: bool = true, tension_adjustment_param: float = TEN_ADJ_DEF) -> Curve3D:
	var new_curve: Curve3D = curve.duplicate()
	update_cardinal_spline_curve3d(new_curve, tension, extrapolate_end_points, tension_adjustment_param)
	return new_curve

# new Curve3D version
static func get_catmull_rom_curve3d(control_points: Array[Vector3], extrapolate_end_points: bool = true) -> Curve3D:
	return get_cardinal_spline_curve3d(control_points, 0.5, extrapolate_end_points)
static func get_cardinal_spline_curve3d(control_points: Array[Vector3], tension: float = 0.5, extrapolate_end_points: bool = true, tension_adjustment_param: float = TEN_ADJ_DEF) -> Curve3D:
	if control_points.size() <= (0 if extrapolate_end_points else 2):
		print_debug("get_cardinal_spline_curve3d: Need at least 1 internal point to set extended points, returning empty curve")
		return Curve3D.new()
	if extrapolate_end_points:
		control_points = cardinal_extrapolated_3d(control_points)
	var curve: Curve3D = Curve3D.new()
	set_curve3d_extended_control_points(curve, control_points)
	update_cardinal_spline_curve3d(curve, tension, extrapolate_end_points, tension_adjustment_param)
	return curve

# Curve2D cardinal/catmull rom spline curve
static func update_catmull_rom_curve2d(curve: Curve2D, extrapolate_end_points: bool = true) -> void:
	update_cardinal_spline_curve2d(curve, 0.5, extrapolate_end_points)
static func update_cardinal_spline_curve2d(curve: Curve2D, tension: float, extrapolate_end_points: bool = true, tension_adjustment_param: float = TEN_ADJ_DEF) -> void:
	if curve.point_count < 1:
		return
	if extrapolate_end_points:
		curve2d_cardinal_extrapolate(curve)
	
	var extended_pts: = get_curve2d_extended_control_points(curve)
	var last: = curve.point_count - 1

	for base_i in curve.point_count:
		var e_i: = base_i + 1
		var tension_adjustment_factor: float = 1.0
		if tension_adjustment_param != 0:
			var relative_a_dist: = (extended_pts[e_i+1] - extended_pts[e_i]).length()
			var relative_b_dist: = (extended_pts[e_i-1] - extended_pts[e_i]).length()
			var relative_dist_ratio: = minf(relative_a_dist, relative_b_dist) / maxf(relative_a_dist, relative_b_dist)
			tension_adjustment_factor = ease(relative_dist_ratio, tension_adjustment_param)
		# a factor of 1/3 converts (velocity length) tangents to bezier in/out handle vectors
		var out_vec: Vector2 = tension_adjustment_factor * tension * (extended_pts[e_i+1] - extended_pts[e_i-1]) / 3.0
		if base_i > 0:    curve.set_point_in(base_i, -out_vec)
		if base_i < last: curve.set_point_out(base_i, out_vec)

# non-in-place version
static func curve2d_catmull_rommed(curve: Curve2D, extrapolate_end_points: bool = true) -> Curve2D:
	return curve2d_cardinal_splined(curve, 0.5, extrapolate_end_points)
static func curve2d_cardinal_splined(curve: Curve2D, tension: float, extrapolate_end_points: bool = true, tension_adjustment_param: float = TEN_ADJ_DEF) -> Curve2D:
	var new_curve: Curve2D = curve.duplicate()
	update_cardinal_spline_curve2d(new_curve, tension, extrapolate_end_points, tension_adjustment_param)
	return new_curve

# new Curve2D version
static func get_catmull_rom_curve2d(control_points: Array[Vector2], extrapolate_end_points: bool = true) -> Curve2D:
	return get_cardinal_spline_curve2d(control_points, 0.5, extrapolate_end_points)
static func get_cardinal_spline_curve2d(control_points: Array[Vector2], tension: float = 0.5, extrapolate_end_points: bool = true, tension_adjustment_param: float = TEN_ADJ_DEF) -> Curve2D:
	if control_points.size() <= (0 if extrapolate_end_points else 2):
		print_debug("get_cardinal_spline_curve2d: Need at least 1 internal point to set extended points, returning empty curve")
		return Curve2D.new()
	if extrapolate_end_points:
		control_points = cardinal_extrapolated_2d(control_points)
	var curve: Curve2D = Curve2D.new()
	set_curve2d_extended_control_points(curve, control_points)
	update_cardinal_spline_curve2d(curve, tension, extrapolate_end_points, tension_adjustment_param)
	return curve

# Default method of extrapolating the extra control points by reflecting the second-outer-most point around the outer-most points
static func cardinal_extrapolated_3d(pts: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = pts.duplicate()
	cardinal_extrapolate_3d(result)
	return result
static func cardinal_extrapolate_3d(pts: Array[Vector3]) -> void:
	if pts.size() == 0:
		return
	if pts.size() == 1:
		pts.push_back(pts[0])
		pts.push_back(pts[0])
	else:
		pts.push_back( pts[-1]*2 - pts[-2])
		pts.push_front(pts[ 0]*2 - pts[ 1])

static func curve3d_cardinal_extrapolated(curve: Curve3D) -> Curve3D:
	var new_curve: Curve3D = curve.duplicate()
	curve3d_cardinal_extrapolate(new_curve)
	return new_curve
static func curve3d_cardinal_extrapolate(curve: Curve3D) -> void:
	if curve.point_count == 0:
		return
	if curve.point_count == 1:
		curve.set_point_out(0, Vector3.ZERO)
		curve.set_point_in(0, Vector3.ZERO)
	else:
		var last: = curve.point_count - 1
		curve.set_point_out(last, curve.get_point_position(last) - curve.get_point_position(last - 1))
		curve.set_point_in( 0,    curve.get_point_position(0)      - curve.get_point_position(1))

# 2D version
static func cardinal_extrapolated_2d(pts: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = pts.duplicate()
	cardinal_extrapolate_2d(result)
	return result
static func cardinal_extrapolate_2d(pts: Array[Vector2]) -> void:
	if pts.size() == 0:
		return
	if pts.size() == 1:
		pts.push_back(pts[0])
		pts.push_back(pts[0])
	else:
		pts.push_back( pts[-1]*2 - pts[-2])
		pts.push_front(pts[ 0]*2 - pts[ 1])

static func cardinal_extrapolated_2d_discontinuous(pts: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = pts.duplicate()
	cardinal_extrapolate_2d_discontinuous(result)
	return result
static func cardinal_extrapolate_2d_discontinuous(pts: Array[Vector2]) -> void:
	if pts.size() == 0:
		return
	if pts.size() % 2 != 0:
		print_debug("cardinal extrapolate 2d disc: Expected pairs of points, but got an odd number")
		return
	if pts.size() == 2: # only one pair, just duplicate the in/out values on both ends
		pts.push_front(pts[0])
		pts.push_front(pts[0])
		pts.push_back(pts[1])
		pts.push_back(pts[1])
	else:
		# take into account the first 2 IN points for extrapolating the start, and the last 2 OUT points for extrapolating the end
		# if either end point is itself discontinuous this wont make a lot of sense, but this is good for the case when the penultimate points are discontinuous
		var start: = pts[ 0]*2 - pts[ 2]
		var end: =   pts[-1]*2 - pts[-3]
		pts.push_front(start)
		pts.push_front(start)
		pts.push_back(end)
		pts.push_back(end)

static func curve2d_cardinal_extrapolated(curve: Curve2D) -> Curve2D:
	var new_curve: Curve2D = curve.duplicate()
	curve2d_cardinal_extrapolate(new_curve)
	return new_curve
static func curve2d_cardinal_extrapolate(curve: Curve2D) -> void:
	if curve.point_count == 0:
		return
	if curve.point_count == 1:
		curve.set_point_out(0, Vector2.ZERO)
		curve.set_point_in(0, Vector2.ZERO)
	else:
		var last: = curve.point_count - 1
		curve.set_point_out(last, curve.get_point_position(last) - curve.get_point_position(last - 1))
		curve.set_point_in( 0,    curve.get_point_position(0)    - curve.get_point_position(1))

static func cardinal_extrapolated_1d(pts: Array[float]) -> Array[float]:
	var result: Array[float] = pts.duplicate()
	cardinal_extrapolate_1d(result)
	return result
static func cardinal_extrapolate_1d(pts: Array[float]) -> void:
	if pts.size() == 0:
		return
	if pts.size() == 1:
		pts.push_back(pts[0])
		pts.push_back(pts[0])
	else:    
		pts.push_back( pts[-1]*2 - pts[-2])
		pts.push_front(pts[ 0]*2 - pts[ 1])

static func cardinal_extrapolate_1d_discontinuous(pts: Array[float]) -> void:
	if pts.size() == 0:
		print_debug("cardinal extrapolate 1d disc: Cant extrapolate empty array")
		return
	if pts.size() % 2 != 0:
		print_debug("cardinal extrapolate 1d disc: Expected pairs of points, but got an odd number")
		return
	if pts.size() == 2: # only one pair, just duplicate the in/out values on both ends
		pts.push_front(pts[0])
		pts.push_front(pts[0])
		pts.push_back(pts[1])
		pts.push_back(pts[1])
	else:
		# take into account the first 2 IN points for extrapolating the start, and the last 2 OUT points for extrapolating the end
		# if either end point is itself discontinuous this wont make a lot of sense, but this is good for the case when the penultimate points are discontinuous
		var start: = pts[ 0]*2 - pts[ 2]
		var end: =   pts[-1]*2 - pts[-3]
		pts.push_front(start)
		pts.push_front(start)
		pts.push_back(end)
		pts.push_back(end)



############
# from scratch GDScript implementation of catmull rom spline, kept for reference, probably use the Curve3D implementation instead
static var catmull_rom_matrix: Projection = Projection(
	Vector4(-1, 2, -1, 0),
	Vector4(3, -5, 0, 2),
	Vector4(-3, 4, 1, 0),
	Vector4(1, -1, 0, 0)
)

# returns a number of samples from a single segment catmull rom spline curve defined by
# 4 control points, where the first and last points are outside the segment (previous and next control points in a multi-segment context)
# only samples a fixed number of points per segment, no arc length distributed samples or curvature weighted sampling
static func catmull_rom_3d_curve_segment_sample(control_points: Array[Vector3], num_samples: int) -> Array[Vector3]:
	var samples: Array[Vector3] = []
	samples.resize(num_samples)
	if control_points.size() != 4:
		push_error("catmull_rom_3d_curve_segment_sample: " + str(control_points.size()) + " control points provided, expected 4")
		samples.fill(Vector3.ZERO)
		return samples
	
	var control_point_vectors: Array[Vector4] = []
	for i in 3:
		control_point_vectors.append(Vector4(control_points[0][i], control_points[1][i], control_points[2][i], control_points[3][i]))
	
	var splice_func: Callable = func(t: float) -> Vector3:
		var t_times_matrix: Vector4 = Vector4(t*t*t, t*t, t, 1) * catmull_rom_matrix
		var result: Vector3 = Vector3.ZERO
		for i in 3:
			result[i] = t_times_matrix.dot(control_point_vectors[i]) / 2.0
		return result

	for i in num_samples:
		samples[i] = splice_func.call(i / float(num_samples - 1))

	return samples
