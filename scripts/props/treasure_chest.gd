extends "res://scripts/props/breakable_prop_base.gd"
class_name TreasureChestProp

const OVERRIDE_MODEL_PATH := "res://assets/models/treasure_chest.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/treasure_chest/treasure_chest_4k.gltf"


func _init() -> void:
	hit_points = 3


func get_interaction_name() -> String:
	return "Treasure Chest"


func _get_model_candidates() -> Array:
	return [
		{"path": OVERRIDE_MODEL_PATH, "scale": Vector3.ONE * 0.62},
		{"path": INTERNET_MODEL_PATH, "scale": Vector3.ONE * 0.58},
	]


func _build_fallback_visual() -> void:
	var wood_material := BlockLibrary.get_terrain_material(BlockLibrary.WOOD, &"side")
	var ancient_metal_block_id := BlockLibrary.get_block_id_by_key("ancient_metal")
	var metal_material := BlockLibrary.get_terrain_material(ancient_metal_block_id if ancient_metal_block_id != BlockLibrary.AIR else BlockLibrary.COPPER_BLOCK, &"side")

	var base := BoxMesh.new()
	base.size = Vector3(0.92, 0.58, 0.62)
	_add_mesh(base, wood_material, Vector3(0.0, 0.3, 0.0))

	var lid := BoxMesh.new()
	lid.size = Vector3(0.94, 0.28, 0.66)
	_add_mesh(lid, wood_material, Vector3(0.0, 0.72, 0.0), Vector3(deg_to_rad(-10.0), 0.0, 0.0))

	var band := BoxMesh.new()
	band.size = Vector3(0.12, 0.84, 0.7)
	_add_mesh(band, metal_material, Vector3(0.0, 0.44, 0.0))


func _get_collision_shape_size() -> Vector3:
	return Vector3(0.92, 0.82, 0.72)


func _get_collision_shape_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


func _get_drop_payload() -> Dictionary:
	return _make_drops_from_keys(
		[
			"amethyst",
			"ember_crystal",
			"storm_crystal",
			"aurora_crystal",
			"white_citadel_brick",
			"royal_mosaic",
			"terrazzo_lux",
			"marble_tile",
			"prism_glass",
		],
		3,
		2,
		6,
		97
	)
