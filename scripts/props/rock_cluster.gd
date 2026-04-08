extends Node3D
class_name RockClusterProp

const OVERRIDE_MODEL_PATH := "res://assets/models/rock_cluster.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/boulder_01/boulder_01_2k.gltf"
const VISIBILITY_END := 68.0
const SHADOW_CASTING := GeometryInstance3D.SHADOW_CASTING_SETTING_ON

var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true

	if _try_load_external_model(OVERRIDE_MODEL_PATH, Vector3.ONE):
		_add_collision()
		return

	if _try_load_external_model(INTERNET_MODEL_PATH, Vector3.ONE * 0.88):
		_add_collision()
		return

	_build_procedural_rocks()


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


func _build_procedural_rocks() -> void:
	var materials := BlockLibrary.create_prop_materials()
	var rock_material: Material = materials["rock"]
	var crystal_material: Material = materials["crystal"]

	var rock_positions: Array[Vector3] = [
		Vector3(0.0, 0.54, 0.0),
		Vector3(0.72, 0.34, -0.22),
		Vector3(-0.54, 0.3, 0.36),
		Vector3(0.08, 0.26, 0.58),
	]
	var rock_scales: Array[Vector3] = [
		Vector3(1.36, 0.92, 1.06),
		Vector3(0.84, 0.58, 0.76),
		Vector3(0.76, 0.5, 0.7),
		Vector3(0.52, 0.34, 0.48),
	]
	for index in range(rock_positions.size()):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		_add_mesh(mesh, rock_material, rock_positions[index], Vector3.ZERO, rock_scales[index])

	var crystal_positions: Array[Vector3] = [
		Vector3(0.08, 0.92, 0.04),
		Vector3(-0.16, 0.74, -0.1),
		Vector3(0.24, 0.68, -0.18),
	]
	var crystal_scales: Array[Vector3] = [
		Vector3(1.0, 1.0, 1.0),
		Vector3(0.68, 0.78, 0.68),
		Vector3(0.58, 0.66, 0.58),
	]
	var crystal_rotations: Array[Vector3] = [
		Vector3(0.0, 0.0, deg_to_rad(14.0)),
		Vector3(deg_to_rad(8.0), deg_to_rad(36.0), deg_to_rad(-12.0)),
		Vector3(deg_to_rad(-6.0), deg_to_rad(-28.0), deg_to_rad(10.0)),
	]
	for index in range(crystal_positions.size()):
		var crystal_mesh := BoxMesh.new()
		crystal_mesh.size = Vector3(0.18, 0.54, 0.18)
		_add_mesh(crystal_mesh, crystal_material, crystal_positions[index], crystal_rotations[index], crystal_scales[index])

	_add_collision()


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "CollisionBody"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.2, 1.6)
	shape.shape = box
	shape.position = Vector3(0.0, 0.45, 0.0)
	body.add_child(shape)


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
