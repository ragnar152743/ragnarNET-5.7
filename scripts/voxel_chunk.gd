extends StaticBody3D
class_name VoxelChunk

const SAMPLE_PADDING := 1

var world
var chunk_coords := Vector2i.ZERO
var chunk_size := 16
var chunk_min_x := 0
var chunk_min_z := 0
var mesh_instance: MeshInstance3D
var collision_shapes: Array[CollisionShape3D] = []
var collision_enabled := true
var collision_box_cache: Array[Dictionary] = []

var rebuild_requested_version := 0
var rebuild_running_version := 0
var rebuild_in_progress := false
var rebuild_stage := 0
var staged_sample_size_x := 0
var staged_sample_size_z := 0
var staged_sample_cursor := 0
var staged_samples := PackedInt32Array()
var staged_surface_data: Dictionary = {}
var staged_surface_order: Array[String] = []


func _init() -> void:
	collision_layer = 1
	collision_mask = 0


func setup(p_world, p_chunk_coords: Vector2i, p_chunk_size: int) -> void:
	world = p_world
	chunk_coords = p_chunk_coords
	chunk_size = p_chunk_size
	chunk_min_x = chunk_coords.x * chunk_size
	chunk_min_z = chunk_coords.y * chunk_size
	name = "Chunk_%s_%s" % [chunk_coords.x, chunk_coords.y]
	position = Vector3(chunk_min_x, 0.0, chunk_min_z)
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		add_child(mesh_instance)
	refresh_render_culling()


func set_collision_enabled(enabled: bool) -> void:
	if collision_enabled == enabled:
		return

	collision_enabled = enabled
	if collision_enabled:
		_apply_collision_boxes()
	else:
		_clear_collision_shapes()
		collision_layer = 0


func request_rebuild() -> void:
	rebuild_requested_version += 1
	if not rebuild_in_progress:
		_begin_rebuild(rebuild_requested_version)


func is_rebuild_in_progress() -> bool:
	return rebuild_in_progress


func process_rebuild_step(voxel_budget: int) -> bool:
	if not rebuild_in_progress:
		if rebuild_requested_version > rebuild_running_version:
			_begin_rebuild(rebuild_requested_version)
		else:
			return true

	if rebuild_stage == 0:
		_process_sampling_stage(max(1, voxel_budget))
		return not rebuild_in_progress

	match rebuild_stage:
		1:
			_emit_greedy_x_faces(staged_surface_data, staged_surface_order, staged_samples, staged_sample_size_z, true)
			rebuild_stage = 2
		2:
			_emit_greedy_x_faces(staged_surface_data, staged_surface_order, staged_samples, staged_sample_size_z, false)
			rebuild_stage = 3
		3:
			_emit_greedy_y_faces(staged_surface_data, staged_surface_order, staged_samples, staged_sample_size_z, true)
			rebuild_stage = 4
		4:
			_emit_greedy_y_faces(staged_surface_data, staged_surface_order, staged_samples, staged_sample_size_z, false)
			rebuild_stage = 5
		5:
			_emit_greedy_z_faces(staged_surface_data, staged_surface_order, staged_samples, staged_sample_size_z, true)
			rebuild_stage = 6
		6:
			_emit_greedy_z_faces(staged_surface_data, staged_surface_order, staged_samples, staged_sample_size_z, false)
			rebuild_stage = 7
		7:
			_commit_mesh_from_staged_data()
			rebuild_stage = 8
		8:
			collision_box_cache = _build_collision_boxes_from_samples(staged_samples, staged_sample_size_z)
			if collision_enabled:
				_apply_collision_boxes()
			else:
				_clear_collision_shapes()
				collision_layer = 0
			_finish_or_restart_rebuild()

	return not rebuild_in_progress


func rebuild() -> void:
	request_rebuild()
	while not process_rebuild_step(1000000):
		pass


func refresh_render_culling() -> void:
	if mesh_instance == null or world == null:
		return
	mesh_instance.extra_cull_margin = 0.0
	mesh_instance.visibility_range_end = float((world.chunk_load_radius + 1) * chunk_size)
	mesh_instance.visibility_range_end_margin = float(chunk_size * max(1, world.chunk_unload_radius - world.chunk_load_radius + 1))
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _begin_rebuild(version: int) -> void:
	rebuild_running_version = version
	rebuild_in_progress = true
	rebuild_stage = 0
	staged_sample_size_x = chunk_size + SAMPLE_PADDING * 2
	staged_sample_size_z = chunk_size + SAMPLE_PADDING * 2
	staged_sample_cursor = 0
	staged_samples = PackedInt32Array()
	staged_samples.resize(staged_sample_size_x * world.max_height * staged_sample_size_z)
	staged_surface_data = {}
	staged_surface_order.clear()


func _process_sampling_stage(voxel_budget: int) -> void:
	var total_samples: int = staged_samples.size()
	var budget: int = voxel_budget
	while staged_sample_cursor < total_samples and budget > 0:
		var local_z: int = staged_sample_cursor % staged_sample_size_z
		var yz_index: int = int(staged_sample_cursor / staged_sample_size_z)
		var y: int = yz_index % world.max_height
		var local_x: int = int(yz_index / world.max_height)
		var world_x: int = chunk_min_x + local_x - SAMPLE_PADDING
		var world_z: int = chunk_min_z + local_z - SAMPLE_PADDING
		staged_samples[staged_sample_cursor] = world.get_block(Vector3i(world_x, y, world_z))
		staged_sample_cursor += 1
		budget -= 1

	if staged_sample_cursor >= total_samples:
		rebuild_stage = 1


func _commit_mesh_from_staged_data() -> void:
	var mesh := ArrayMesh.new()
	for surface_key in staged_surface_order:
		var entry: Dictionary = staged_surface_data[surface_key]
		var bucket: Dictionary = entry["bucket"]
		if bucket["vertices"].is_empty():
			continue

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(bucket["vertices"])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(bucket["normals"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(bucket["uvs"])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(bucket["indices"])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := BlockLibrary.get_terrain_material(int(entry["block_id"]), StringName(entry["face_key"]))
		if material != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)

	mesh_instance.mesh = mesh
	refresh_render_culling()


func _finish_or_restart_rebuild() -> void:
	var needs_restart := rebuild_requested_version > rebuild_running_version
	_clear_rebuild_buffers()
	if needs_restart:
		_begin_rebuild(rebuild_requested_version)
		return
	rebuild_in_progress = false


func _clear_rebuild_buffers() -> void:
	staged_sample_cursor = 0
	staged_sample_size_x = 0
	staged_sample_size_z = 0
	staged_samples = PackedInt32Array()
	staged_surface_data.clear()
	staged_surface_order.clear()


func _emit_greedy_x_faces(
	surface_data: Dictionary,
	surface_order: Array[String],
	samples: PackedInt32Array,
	sample_size_z: int,
	positive_face: bool
) -> void:
	var axis_u := Vector3(0, 1, 0)
	var axis_v := Vector3(0, 0, 1) if positive_face else Vector3(0, 0, -1)
	var normal := Vector3(1, 0, 0) if positive_face else Vector3(-1, 0, 0)

	for local_x in range(chunk_size):
		var mask := _build_empty_mask(world.max_height, chunk_size)
		for y in range(world.max_height):
			for local_z in range(chunk_size):
				var sample_x := local_x + SAMPLE_PADDING
				var sample_z := local_z + SAMPLE_PADDING
				var block_id: int = samples[_sample_index(sample_x, y, sample_z, sample_size_z)]
				if block_id == BlockLibrary.AIR:
					continue
				var neighbor_offset := 1 if positive_face else -1
				var neighbor_id := samples[_sample_index(sample_x + neighbor_offset, y, sample_z, sample_size_z)]
				if neighbor_id != BlockLibrary.AIR:
					continue
				mask[y * chunk_size + local_z] = block_id

		for rect in _consume_greedy_rectangles(mask, world.max_height, chunk_size):
			var block_id := int(rect["block_id"])
			var start_y := int(rect["start_u"])
			var start_z := int(rect["start_v"])
			var size_y := int(rect["size_u"])
			var size_z := int(rect["size_v"])
			var face_key := &"side"
			var bucket := _ensure_surface_bucket(surface_data, surface_order, block_id, face_key)
			var origin := Vector3(
				float(local_x + 1 if positive_face else local_x),
				float(start_y),
				float(start_z + size_z if not positive_face else start_z)
			)
			_append_quad(bucket, origin, axis_u, axis_v, float(size_y), float(size_z), normal)


func _emit_greedy_y_faces(
	surface_data: Dictionary,
	surface_order: Array[String],
	samples: PackedInt32Array,
	sample_size_z: int,
	positive_face: bool
) -> void:
	var axis_u := Vector3(1, 0, 0)
	var axis_v := Vector3(0, 0, -1) if positive_face else Vector3(0, 0, 1)
	var normal := Vector3(0, 1, 0) if positive_face else Vector3(0, -1, 0)
	var face_key: StringName = &"top" if positive_face else &"bottom"

	for y in range(world.max_height):
		var mask := _build_empty_mask(chunk_size, chunk_size)
		for local_x in range(chunk_size):
			for local_z in range(chunk_size):
				var sample_x := local_x + SAMPLE_PADDING
				var sample_z := local_z + SAMPLE_PADDING
				var block_id: int = samples[_sample_index(sample_x, y, sample_z, sample_size_z)]
				if block_id == BlockLibrary.AIR:
					continue
				var neighbor_y := y + (1 if positive_face else -1)
				var neighbor_id := BlockLibrary.STONE if neighbor_y < 0 else BlockLibrary.AIR if neighbor_y >= world.max_height else samples[_sample_index(sample_x, neighbor_y, sample_z, sample_size_z)]
				if neighbor_id != BlockLibrary.AIR:
					continue
				mask[local_x * chunk_size + local_z] = block_id

		for rect in _consume_greedy_rectangles(mask, chunk_size, chunk_size):
			var block_id := int(rect["block_id"])
			var start_x := int(rect["start_u"])
			var start_z := int(rect["start_v"])
			var size_x := int(rect["size_u"])
			var size_z := int(rect["size_v"])
			var bucket := _ensure_surface_bucket(surface_data, surface_order, block_id, face_key)
			var origin := Vector3(
				float(start_x),
				float(y + 1 if positive_face else y),
				float(start_z + size_z if positive_face else start_z)
			)
			_append_quad(bucket, origin, axis_u, axis_v, float(size_x), float(size_z), normal)


func _emit_greedy_z_faces(
	surface_data: Dictionary,
	surface_order: Array[String],
	samples: PackedInt32Array,
	sample_size_z: int,
	positive_face: bool
) -> void:
	var axis_u := Vector3(0, 1, 0)
	var axis_v := Vector3(-1, 0, 0) if positive_face else Vector3(1, 0, 0)
	var normal := Vector3(0, 0, 1) if positive_face else Vector3(0, 0, -1)

	for local_z in range(chunk_size):
		var mask := _build_empty_mask(world.max_height, chunk_size)
		for y in range(world.max_height):
			for local_x in range(chunk_size):
				var sample_x := local_x + SAMPLE_PADDING
				var sample_z := local_z + SAMPLE_PADDING
				var block_id: int = samples[_sample_index(sample_x, y, sample_z, sample_size_z)]
				if block_id == BlockLibrary.AIR:
					continue
				var neighbor_offset := 1 if positive_face else -1
				var neighbor_id := samples[_sample_index(sample_x, y, sample_z + neighbor_offset, sample_size_z)]
				if neighbor_id != BlockLibrary.AIR:
					continue
				mask[y * chunk_size + local_x] = block_id

		for rect in _consume_greedy_rectangles(mask, world.max_height, chunk_size):
			var block_id := int(rect["block_id"])
			var start_y := int(rect["start_u"])
			var start_x := int(rect["start_v"])
			var size_y := int(rect["size_u"])
			var size_x := int(rect["size_v"])
			var face_key := &"side"
			var bucket := _ensure_surface_bucket(surface_data, surface_order, block_id, face_key)
			var origin := Vector3(
				float(start_x + size_x if positive_face else start_x),
				float(start_y),
				float(local_z + 1 if positive_face else local_z)
			)
			_append_quad(bucket, origin, axis_u, axis_v, float(size_y), float(size_x), normal)


func _build_empty_mask(u_size: int, v_size: int) -> Array[int]:
	var mask: Array[int] = []
	mask.resize(u_size * v_size)
	for index in range(mask.size()):
		mask[index] = BlockLibrary.AIR
	return mask


func _consume_greedy_rectangles(mask: Array[int], u_size: int, v_size: int) -> Array[Dictionary]:
	var rectangles: Array[Dictionary] = []
	for u in range(u_size):
		var v := 0
		while v < v_size:
			var index := u * v_size + v
			var block_id := mask[index]
			if block_id == BlockLibrary.AIR:
				v += 1
				continue

			var rect_width := 1
			while v + rect_width < v_size and mask[u * v_size + v + rect_width] == block_id:
				rect_width += 1

			var rect_height := 1
			var can_expand := true
			while u + rect_height < u_size and can_expand:
				for test_v in range(v, v + rect_width):
					if mask[(u + rect_height) * v_size + test_v] != block_id:
						can_expand = false
						break
				if can_expand:
					rect_height += 1

			for clear_u in range(u, u + rect_height):
				for clear_v in range(v, v + rect_width):
					mask[clear_u * v_size + clear_v] = BlockLibrary.AIR

			rectangles.append(
				{
					"block_id": block_id,
					"start_u": u,
					"start_v": v,
					"size_u": rect_height,
					"size_v": rect_width,
				}
			)
			v += rect_width
	return rectangles


func _ensure_surface_bucket(
	surface_data: Dictionary,
	surface_order: Array[String],
	block_id: int,
	face_key: StringName
) -> Dictionary:
	var surface_key := "%s:%s" % [block_id, face_key]
	if not surface_data.has(surface_key):
		surface_data[surface_key] = {
			"block_id": block_id,
			"face_key": face_key,
			"bucket": _create_bucket(),
		}
		surface_order.append(surface_key)
	return surface_data[surface_key]["bucket"]


func _create_bucket() -> Dictionary:
	return {
		"vertices": [],
		"normals": [],
		"uvs": [],
		"indices": [],
	}


func _append_quad(
	bucket: Dictionary,
	origin: Vector3,
	axis_u: Vector3,
	axis_v: Vector3,
	size_u: float,
	size_v: float,
	normal: Vector3
) -> void:
	var base_index: int = bucket["vertices"].size()
	var corners := [
		origin,
		origin + axis_u * size_u,
		origin + axis_u * size_u + axis_v * size_v,
		origin + axis_v * size_v,
	]
	var scaled_uvs := [
		Vector2(0.0, size_u),
		Vector2(0.0, 0.0),
		Vector2(size_v, 0.0),
		Vector2(size_v, size_u),
	]

	for corner in corners:
		bucket["vertices"].append(corner)
		bucket["normals"].append(normal)

	for uv in scaled_uvs:
		bucket["uvs"].append(uv)

	bucket["indices"].append(base_index)
	bucket["indices"].append(base_index + 1)
	bucket["indices"].append(base_index + 2)
	bucket["indices"].append(base_index)
	bucket["indices"].append(base_index + 2)
	bucket["indices"].append(base_index + 3)


func _sample_index(local_x: int, y: int, local_z: int, sample_size_z: int) -> int:
	return ((local_x * world.max_height) + y) * sample_size_z + local_z


func _build_collision_boxes_from_samples(samples: PackedInt32Array, sample_size_z: int) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var segment_groups: Dictionary = {}
	for local_x in range(chunk_size):
		for local_z in range(chunk_size):
			var y := 0
			while y < world.max_height:
				if samples[_sample_index(local_x + SAMPLE_PADDING, y, local_z + SAMPLE_PADDING, sample_size_z)] == BlockLibrary.AIR:
					y += 1
					continue

				var segment_start := y
				while y + 1 < world.max_height and samples[_sample_index(local_x + SAMPLE_PADDING, y + 1, local_z + SAMPLE_PADDING, sample_size_z)] != BlockLibrary.AIR:
					y += 1

				var segment_key := Vector2i(segment_start, y)
				if not segment_groups.has(segment_key):
					segment_groups[segment_key] = {
						"start_y": segment_start,
						"end_y": y,
						"cells": {},
					}
				var cells: Dictionary = segment_groups[segment_key]["cells"]
				cells[Vector2i(local_x, local_z)] = true
				y += 1

	for segment_key_variant in segment_groups.keys():
		var group: Dictionary = segment_groups[segment_key_variant]
		var start_y := int(group.get("start_y", 0))
		var end_y := int(group.get("end_y", start_y))
		var cells: Dictionary = group.get("cells", {})
		var visited: Dictionary = {}

		for local_x in range(chunk_size):
			for local_z in range(chunk_size):
				var cell_key := Vector2i(local_x, local_z)
				if not cells.has(cell_key) or visited.has(cell_key):
					continue

				var width := 1
				while local_x + width < chunk_size:
					var next_key := Vector2i(local_x + width, local_z)
					if not cells.has(next_key) or visited.has(next_key):
						break
					width += 1

				var depth := 1
				var keep_expanding := true
				while local_z + depth < chunk_size and keep_expanding:
					for test_x in range(local_x, local_x + width):
						var test_key := Vector2i(test_x, local_z + depth)
						if not cells.has(test_key) or visited.has(test_key):
							keep_expanding = false
							break
					if keep_expanding:
						depth += 1

				for mark_x in range(local_x, local_x + width):
					for mark_z in range(local_z, local_z + depth):
						visited[Vector2i(mark_x, mark_z)] = true

				_append_collision_box(boxes, start_y, end_y, local_x, local_z, width, depth)

	return boxes


func _append_collision_box(
	boxes: Array[Dictionary],
	start_y: int,
	end_y: int,
	start_x: int,
	start_z: int,
	width: int,
	depth: int
) -> void:
	var height := float(end_y - start_y + 1)
	boxes.append(
		{
			"size": Vector3(float(width), height, float(depth)),
			"center": Vector3(
				float(start_x) + float(width) * 0.5,
				float(start_y) + height * 0.5,
				float(start_z) + float(depth) * 0.5
			),
		}
	)


func _apply_collision_boxes() -> void:
	_clear_collision_shapes()
	collision_layer = 1
	for box_entry_variant in collision_box_cache:
		var box_entry: Dictionary = box_entry_variant
		var size: Vector3 = box_entry.get("size", Vector3.ONE)
		var center: Vector3 = box_entry.get("center", Vector3.ZERO)

		var collision := CollisionShape3D.new()
		collision.name = "Collision_%s_%s_%s" % [snappedf(center.x, 0.1), snappedf(center.y, 0.1), snappedf(center.z, 0.1)]

		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		collision.position = center

		add_child(collision)
		collision_shapes.append(collision)


func _clear_collision_shapes() -> void:
	for collision in collision_shapes:
		if collision == null:
			continue
		remove_child(collision)
		collision.queue_free()
	collision_shapes.clear()
