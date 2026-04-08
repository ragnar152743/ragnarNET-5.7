extends Node3D
class_name ShrubProp

const OVERRIDE_MODEL_PATH := "res://assets/models/shrub.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/shrub_sorrel_01/shrub_sorrel_01_4k.gltf"
const ALT_INTERNET_MODEL_PATH := "res://assets/models/polyhaven/pachira_aquatica_01/pachira_aquatica_01_4k.gltf"
const VISIBILITY_END := 40.0
const SHADOW_CASTING := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true

	if _try_load_external_model(OVERRIDE_MODEL_PATH, Vector3.ONE):
		return

	var use_alt_variant := _pick_alt_variant()
	if use_alt_variant:
		if _try_load_external_model(ALT_INTERNET_MODEL_PATH, Vector3.ONE * 0.22):
			return
		if _try_load_external_model(INTERNET_MODEL_PATH, Vector3.ONE * 0.52):
			return
	else:
		if _try_load_external_model(INTERNET_MODEL_PATH, Vector3.ONE * 0.52):
			return
		if _try_load_external_model(ALT_INTERNET_MODEL_PATH, Vector3.ONE * 0.22):
			return

	if _try_load_external_model(ALT_INTERNET_MODEL_PATH, Vector3.ONE * 0.22):
		return

	_build_fallback_shrub()


func _pick_alt_variant() -> bool:
	var seed_value := int(round(global_position.x * 10.0)) * 73856093 ^ int(round(global_position.z * 10.0)) * 19349663
	return abs(seed_value) % 3 == 0


func _try_load_external_model(path: String, model_scale: Vector3) -> bool:
	if not ResourceLoader.exists(path):
		return false

	var resource = load(path)
	if resource is PackedScene:
		var instance: Node3D = (resource as PackedScene).instantiate()
		instance.scale = model_scale
		_apply_visual_budget(instance)
		add_child(instance)
		return true

	return false


func _build_fallback_shrub() -> void:
	var materials := BlockLibrary.create_prop_materials()
	var leaf_material: Material = materials["leaf"]

	var foliage_positions: Array[Vector3] = [
		Vector3(0.0, 0.42, 0.0),
		Vector3(0.28, 0.34, 0.18),
		Vector3(-0.24, 0.3, -0.16),
		Vector3(0.12, 0.56, -0.22),
	]
	var foliage_scales: Array[Vector3] = [
		Vector3(0.9, 0.62, 0.86),
		Vector3(0.66, 0.46, 0.64),
		Vector3(0.62, 0.4, 0.58),
		Vector3(0.52, 0.34, 0.48),
	]

	for index in range(foliage_positions.size()):
		var foliage_mesh := SphereMesh.new()
		foliage_mesh.radius = 0.34
		foliage_mesh.height = 0.68
		_add_mesh(foliage_mesh, leaf_material, foliage_positions[index], Vector3.ZERO, foliage_scales[index])


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
	mesh_instance.cast_shadow = SHADOW_CASTING
	mesh_instance.visibility_range_end = VISIBILITY_END
	add_child(mesh_instance)


func _apply_visual_budget(root: Node) -> void:
	if root is GeometryInstance3D:
		var geometry_root := root as GeometryInstance3D
		geometry_root.cast_shadow = SHADOW_CASTING
		geometry_root.visibility_range_end = VISIBILITY_END

	for child in root.get_children():
		_apply_visual_budget(child)
