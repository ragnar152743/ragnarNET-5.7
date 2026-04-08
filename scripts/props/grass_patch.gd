extends Node3D
class_name GrassPatchProp

const OVERRIDE_MODEL_PATH := "res://assets/models/grass_patch.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/grass_bermuda_01/grass_bermuda_01_1k.gltf"
const VISIBILITY_END := 34.0
const SHADOW_CASTING := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true

	if _try_load_external_model(OVERRIDE_MODEL_PATH, Vector3.ONE):
		return

	if _try_load_external_model(INTERNET_MODEL_PATH, Vector3.ONE * 0.28):
		return

	_build_procedural_patch()


func _try_load_external_model(path: String, model_scale: Vector3) -> bool:
	if not ResourceLoader.exists(path):
		return false

	var resource = load(path)
	if resource is PackedScene:
		var instance: Node3D = resource.instantiate()
		instance.scale = model_scale
		_apply_visual_budget(instance)
		add_child(instance)
		return true

	return false


func _build_procedural_patch() -> void:
	var materials := BlockLibrary.create_prop_materials()
	var grass_material: Material = materials["grass"]
	var flower_material: Material = BlockLibrary.get_terrain_material(BlockLibrary.GLOW, &"side")

	var blade_offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.12, 0.0, -0.08),
		Vector3(-0.1, 0.0, 0.14),
		Vector3(0.08, 0.0, 0.12),
		Vector3(-0.16, 0.0, -0.06),
		Vector3(0.18, 0.0, 0.02),
	]
	var blade_sizes: Array[Vector2] = [
		Vector2(0.26, 0.82),
		Vector2(0.22, 0.68),
		Vector2(0.24, 0.76),
		Vector2(0.18, 0.58),
		Vector2(0.2, 0.62),
		Vector2(0.16, 0.48),
	]
	var blade_angles := [0.0, 0.58, 1.14, 1.8, 2.28, 2.92]

	for index in range(blade_offsets.size()):
		var quad := QuadMesh.new()
		quad.size = blade_sizes[index]
		_add_blade(quad, grass_material, blade_offsets[index], blade_angles[index])
		_add_blade(quad, grass_material, blade_offsets[index], blade_angles[index] + PI * 0.5)

	var stem_mesh := CylinderMesh.new()
	stem_mesh.height = 0.34
	stem_mesh.top_radius = 0.02
	stem_mesh.bottom_radius = 0.03
	_add_mesh(stem_mesh, grass_material, Vector3(0.04, 0.17, -0.03))

	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.08
	flower_mesh.height = 0.16
	_add_mesh(flower_mesh, flower_material, Vector3(0.04, 0.38, -0.03), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))


func _add_blade(quad: QuadMesh, material: Material, offset: Vector3, angle: float) -> void:
	var blade := MeshInstance3D.new()
	blade.mesh = quad
	blade.material_override = material
	blade.position = offset + Vector3(0.0, quad.size.y * 0.5, 0.0)
	blade.rotation = Vector3(0.0, angle, 0.0)
	blade.cast_shadow = SHADOW_CASTING
	blade.visibility_range_end = VISIBILITY_END
	add_child(blade)


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
