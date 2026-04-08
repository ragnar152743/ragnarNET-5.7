extends "res://scripts/props/breakable_prop_base.gd"
class_name WoodenCrateProp

const OVERRIDE_MODEL_PATH := "res://assets/models/wooden_crate.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/wooden_crate_01/wooden_crate_01_4k.gltf"


func _init() -> void:
	hit_points = 2


func get_interaction_name() -> String:
	return "Wooden Crate"


func _get_model_candidates() -> Array:
	return [
		{"path": OVERRIDE_MODEL_PATH, "scale": Vector3.ONE * 0.76},
		{"path": INTERNET_MODEL_PATH, "scale": Vector3.ONE * 0.72},
	]


func _build_fallback_visual() -> void:
	var plank_block_id := BlockLibrary.get_block_id_by_key("old_planks")
	var bark_block_id := BlockLibrary.get_block_id_by_key("bark_block")
	var wood_material := BlockLibrary.get_terrain_material(plank_block_id if plank_block_id != BlockLibrary.AIR else BlockLibrary.WOOD, &"side")
	var band_material := BlockLibrary.get_terrain_material(bark_block_id if bark_block_id != BlockLibrary.AIR else BlockLibrary.WOOD, &"side")

	var body := BoxMesh.new()
	body.size = Vector3(0.9, 0.9, 0.9)
	_add_mesh(body, wood_material, Vector3(0.0, 0.45, 0.0))

	var slat := BoxMesh.new()
	slat.size = Vector3(0.96, 0.12, 0.12)
	_add_mesh(slat, band_material, Vector3(0.0, 0.2, 0.36))
	_add_mesh(slat, band_material, Vector3(0.0, 0.2, -0.36))
	_add_mesh(slat, band_material, Vector3(0.0, 0.7, 0.36))
	_add_mesh(slat, band_material, Vector3(0.0, 0.7, -0.36))


func _get_collision_shape_size() -> Vector3:
	return Vector3(0.92, 0.92, 0.92)


func _get_collision_shape_position() -> Vector3:
	return Vector3(0.0, 0.46, 0.0)


func _get_drop_payload() -> Dictionary:
	return _make_drops_from_keys(
		[
			"wood",
			"bark_block",
			"dark_timber",
			"old_planks",
			"moss_wood_block",
		],
		2,
		2,
		5,
		131
	)
