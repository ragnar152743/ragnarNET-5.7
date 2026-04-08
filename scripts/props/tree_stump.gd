extends "res://scripts/props/breakable_prop_base.gd"
class_name TreeStumpProp

const OVERRIDE_MODEL_PATH := "res://assets/models/tree_stump.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/tree_stump_01/tree_stump_01_4k.gltf"


func _init() -> void:
	hit_points = 2


func get_interaction_name() -> String:
	return "Tree Stump"


func _get_model_candidates() -> Array:
	return [
		{"path": OVERRIDE_MODEL_PATH, "scale": Vector3.ONE * 0.82},
		{"path": INTERNET_MODEL_PATH, "scale": Vector3.ONE * 0.68},
	]


func _build_fallback_visual() -> void:
	var wood_material := BlockLibrary.get_terrain_material(BlockLibrary.WOOD, &"side")
	var bark_block_id := BlockLibrary.get_block_id_by_key("bark_block")
	var bark_material := BlockLibrary.get_terrain_material(bark_block_id if bark_block_id != BlockLibrary.AIR else BlockLibrary.WOOD, &"side")

	var stump := CylinderMesh.new()
	stump.height = 0.86
	stump.top_radius = 0.38
	stump.bottom_radius = 0.44
	_add_mesh(stump, bark_material, Vector3(0.0, 0.42, 0.0))

	var top := CylinderMesh.new()
	top.height = 0.1
	top.top_radius = 0.36
	top.bottom_radius = 0.36
	_add_mesh(top, wood_material, Vector3(0.0, 0.84, 0.0))


func _get_collision_shape_size() -> Vector3:
	return Vector3(0.84, 0.92, 0.84)


func _get_collision_shape_position() -> Vector3:
	return Vector3(0.0, 0.46, 0.0)


func _get_drop_payload() -> Dictionary:
	return _make_drops_from_keys(
		[
			"wood",
			"bark_block",
			"old_planks",
		],
		2,
		1,
		3,
		211
	)
