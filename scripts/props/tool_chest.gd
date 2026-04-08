extends "res://scripts/props/breakable_prop_base.gd"
class_name ToolChestProp

const OVERRIDE_MODEL_PATH := "res://assets/models/tool_chest.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/metal_tool_chest/metal_tool_chest_4k.gltf"


func _init() -> void:
	hit_points = 3


func get_interaction_name() -> String:
	return "Tool Chest"


func _get_model_candidates() -> Array:
	return [
		{"path": OVERRIDE_MODEL_PATH, "scale": Vector3.ONE * 0.78},
		{"path": INTERNET_MODEL_PATH, "scale": Vector3.ONE * 0.72},
	]


func _build_fallback_visual() -> void:
	var shell_material := BlockLibrary.get_terrain_material(BlockLibrary.get_block_id_by_key("navy_steel"), &"side")
	var accent_material := BlockLibrary.get_terrain_material(BlockLibrary.get_block_id_by_key("circuit_plate"), &"side")

	var base := BoxMesh.new()
	base.size = Vector3(0.98, 0.72, 0.58)
	_add_mesh(base, shell_material, Vector3(0.0, 0.36, 0.0))

	var lid := BoxMesh.new()
	lid.size = Vector3(1.0, 0.22, 0.6)
	_add_mesh(lid, shell_material, Vector3(0.0, 0.78, 0.0), Vector3(deg_to_rad(-6.0), 0.0, 0.0))

	var strip := BoxMesh.new()
	strip.size = Vector3(0.18, 0.88, 0.1)
	_add_mesh(strip, accent_material, Vector3(0.0, 0.42, 0.29))


func _get_collision_shape_size() -> Vector3:
	return Vector3(1.02, 0.84, 0.66)


func _get_collision_shape_position() -> Vector3:
	return Vector3(0.0, 0.42, 0.0)


func _get_drop_payload() -> Dictionary:
	return _make_drops_from_keys(
		[
			"rust_steel",
			"navy_steel",
			"circuit_plate",
			"bronze_plate",
			"ancient_metal",
			"industrial_grate",
			"concrete_panel",
			"polished_concrete",
		],
		3,
		1,
		4,
		173
	)
