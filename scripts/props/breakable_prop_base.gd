extends Node3D
class_name BreakablePropBase

var world_ref: VoxelWorld
var prop_key := ""
var hit_points := 2
var destroyed := false

var _built := false
var visual_root: Node3D
var hit_body: StaticBody3D


func configure(p_world: VoxelWorld, p_prop_key: String, p_hit_points: int = -1) -> void:
	world_ref = p_world
	prop_key = p_prop_key
	if p_hit_points > 0:
		hit_points = p_hit_points


func get_interaction_name() -> String:
	return "Prop"


func _ready() -> void:
	if _built:
		return
	_built = true
	add_to_group("breakable_props")

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	if not _try_build_external_models():
		_build_fallback_visual()

	_add_interaction_collision()


func apply_damage() -> Dictionary:
	if destroyed:
		return {}

	hit_points -= 1
	_play_hit_animation()
	if hit_points > 0:
		return {}

	destroyed = true
	if world_ref != null and not prop_key.is_empty():
		world_ref.mark_prop_removed(prop_key)

	if hit_body != null:
		hit_body.collision_layer = 0
		hit_body.collision_mask = 0

	var drops := _get_drop_payload()
	_play_break_animation()
	return drops


func _try_build_external_models() -> bool:
	for candidate in _get_model_candidates():
		if not (candidate is Dictionary):
			continue
		var path := String(candidate.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var resource = load(path)
		if resource is PackedScene:
			var instance: Node3D = (resource as PackedScene).instantiate()
			instance.scale = candidate.get("scale", Vector3.ONE)
			instance.position = candidate.get("position", Vector3.ZERO)
			instance.rotation = candidate.get("rotation", Vector3.ZERO)
			visual_root.add_child(instance)
			_configure_loaded_visual(instance)
			return true
	return false


func _get_model_candidates() -> Array:
	return []


func _configure_loaded_visual(_instance: Node3D) -> void:
	_apply_visual_budget(_instance, _get_visibility_end(), _get_shadow_casting_setting())


func _build_fallback_visual() -> void:
	pass


func _get_visibility_end() -> float:
	return 52.0


func _get_shadow_casting_setting() -> int:
	return GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _get_collision_shape_size() -> Vector3:
	return Vector3.ONE


func _get_collision_shape_position() -> Vector3:
	return Vector3(0.0, 0.5, 0.0)


func _get_drop_payload() -> Dictionary:
	return {}


func _make_drops_from_keys(block_keys: Array[String], roll_count: int, min_count: int, max_count: int, salt: int = 0) -> Dictionary:
	var candidate_ids: Array[int] = []
	for block_key in block_keys:
		var block_id := BlockLibrary.get_block_id_by_key(block_key)
		if block_id != BlockLibrary.AIR:
			candidate_ids.append(block_id)

	if candidate_ids.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(String(prop_key).hash()) + abs(world_ref.world_seed if world_ref != null else 0) * 13 + salt)

	var drops: Array[Dictionary] = []
	for _roll in range(max(1, roll_count)):
		var block_id := candidate_ids[rng.randi_range(0, candidate_ids.size() - 1)]
		var amount := rng.randi_range(min_count, max_count)
		drops.append(
			{
				"block_id": block_id,
				"count": amount,
			}
		)

	return {
		"drops": drops,
	}


func _add_interaction_collision() -> void:
	hit_body = StaticBody3D.new()
	hit_body.name = "CollisionBody"
	hit_body.collision_layer = 2
	hit_body.collision_mask = 0
	add_child(hit_body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _get_collision_shape_size()
	shape.shape = box
	shape.position = _get_collision_shape_position()
	hit_body.add_child(shape)


func _play_hit_animation() -> void:
	if visual_root == null or destroyed:
		return

	var tween := create_tween()
	tween.tween_property(visual_root, "rotation_degrees", Vector3(0.0, 0.0, -7.0), 0.05)
	tween.tween_property(visual_root, "rotation_degrees", Vector3(0.0, 0.0, 4.0), 0.07)
	tween.tween_property(visual_root, "rotation_degrees", Vector3.ZERO, 0.08)


func _play_break_animation() -> void:
	if visual_root == null:
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(visual_root, "rotation_degrees", Vector3(-12.0, 0.0, -22.0), 0.16)
	tween.parallel().tween_property(visual_root, "position:y", -0.14, 0.16)
	tween.parallel().tween_property(visual_root, "scale", visual_root.scale * Vector3(0.94, 0.9, 0.94), 0.16)
	tween.finished.connect(queue_free)


func _add_mesh(
	mesh: Mesh,
	material: Material,
	position: Vector3,
	rotation: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	mesh_instance.scale = scale_value
	mesh_instance.cast_shadow = _get_shadow_casting_setting()
	var visibility_end := _get_visibility_end()
	if visibility_end > 0.0:
		mesh_instance.visibility_range_end = visibility_end
	visual_root.add_child(mesh_instance)


func _apply_visual_budget(root: Node, visibility_end: float, shadow_casting: int) -> void:
	if root is GeometryInstance3D:
		var geometry_root := root as GeometryInstance3D
		geometry_root.cast_shadow = shadow_casting
		geometry_root.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		if visibility_end > 0.0:
			geometry_root.visibility_range_end = visibility_end

	for child in root.get_children():
		_apply_visual_budget(child, visibility_end, shadow_casting)
