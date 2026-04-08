extends Node3D
class_name TreeProp

const OVERRIDE_MODEL_PATH := "res://assets/models/tree.glb"
const INTERNET_MODEL_PATH := "res://assets/models/polyhaven/quiver_tree_02/quiver_tree_02_2k.gltf"
const VISIBILITY_END := 88.0
const SHADOW_CASTING := GeometryInstance3D.SHADOW_CASTING_SETTING_ON

var world_ref: VoxelWorld
var prop_key := ""
var wood_yield := 4
var hit_points := 4
var destroyed := false

var _built := false
var visual_root: Node3D
var hit_body: StaticBody3D


func configure(p_world: VoxelWorld, p_prop_key: String, p_wood_yield: int = 4) -> void:
	world_ref = p_world
	prop_key = p_prop_key
	wood_yield = max(1, p_wood_yield)


func get_interaction_name() -> String:
	return "Tree"


func _ready() -> void:
	if _built:
		return
	_built = true

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	if _try_load_external_model(OVERRIDE_MODEL_PATH, Vector3.ONE * 2.4):
		_add_simple_trunk_collision()
		return

	if _try_load_external_model(INTERNET_MODEL_PATH, Vector3.ONE * 2.6):
		_add_simple_trunk_collision()
		return

	_build_procedural_tree()


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

	_play_break_animation()
	return {
		"drops": [
			{
				"block_id": BlockLibrary.WOOD,
				"count": wood_yield,
			}
		]
	}


func _play_hit_animation() -> void:
	if visual_root == null or destroyed:
		return

	var tween := create_tween()
	tween.tween_property(visual_root, "rotation_degrees", Vector3(0.0, 0.0, -6.0), 0.06)
	tween.tween_property(visual_root, "rotation_degrees", Vector3(0.0, 0.0, 4.0), 0.08)
	tween.tween_property(visual_root, "rotation_degrees", Vector3.ZERO, 0.08)


func _play_break_animation() -> void:
	if visual_root == null:
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(visual_root, "rotation_degrees", Vector3(0.0, 0.0, -68.0), 0.28)
	tween.parallel().tween_property(visual_root, "position:y", -0.18, 0.28)
	tween.parallel().tween_property(visual_root, "scale", visual_root.scale * Vector3(1.0, 0.92, 1.0), 0.28)
	tween.finished.connect(queue_free)


func _try_load_external_model(path: String, model_scale: Vector3) -> bool:
	if not ResourceLoader.exists(path):
		return false

	var resource = load(path)
	if resource is PackedScene:
		var instance: Node3D = resource.instantiate()
		instance.scale = model_scale
		visual_root.add_child(instance)
		_apply_visual_budget(instance)
		return true

	return false


func _build_procedural_tree() -> void:
	var materials := BlockLibrary.create_prop_materials()
	var trunk_material: Material = materials["trunk"]
	var leaf_material: Material = materials["leaf"]

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 3.6
	trunk_mesh.top_radius = 0.24
	trunk_mesh.bottom_radius = 0.48
	_add_mesh(trunk_mesh, trunk_material, Vector3(0.0, 1.8, 0.0))

	var root_rotations: Array[Vector3] = [
		Vector3(deg_to_rad(78.0), 0.0, deg_to_rad(18.0)),
		Vector3(deg_to_rad(74.0), deg_to_rad(126.0), deg_to_rad(-14.0)),
		Vector3(deg_to_rad(82.0), deg_to_rad(240.0), deg_to_rad(9.0)),
	]
	for root_rotation in root_rotations:
		var root_mesh := CylinderMesh.new()
		root_mesh.height = 1.15
		root_mesh.top_radius = 0.08
		root_mesh.bottom_radius = 0.14
		_add_mesh(root_mesh, trunk_material, Vector3(0.0, 0.32, 0.0), root_rotation)

	var branch_positions: Array[Vector3] = [
		Vector3(0.28, 2.7, 0.08),
		Vector3(-0.26, 2.42, -0.1),
		Vector3(0.12, 2.95, -0.28),
	]
	var branch_rotations: Array[Vector3] = [
		Vector3(deg_to_rad(42.0), deg_to_rad(18.0), deg_to_rad(-32.0)),
		Vector3(deg_to_rad(56.0), deg_to_rad(-96.0), deg_to_rad(22.0)),
		Vector3(deg_to_rad(38.0), deg_to_rad(132.0), deg_to_rad(-18.0)),
	]
	for index in range(branch_positions.size()):
		var branch_mesh := CylinderMesh.new()
		branch_mesh.height = 1.55
		branch_mesh.top_radius = 0.08
		branch_mesh.bottom_radius = 0.14
		_add_mesh(branch_mesh, trunk_material, branch_positions[index], branch_rotations[index])

	var foliage_positions: Array[Vector3] = [
		Vector3(0.0, 4.0, 0.0),
		Vector3(0.56, 3.74, 0.18),
		Vector3(-0.54, 3.6, -0.22),
		Vector3(0.14, 4.52, -0.32),
		Vector3(-0.08, 3.32, 0.42),
	]
	var foliage_scales: Array[Vector3] = [
		Vector3(1.35, 0.82, 1.35),
		Vector3(1.0, 0.72, 0.96),
		Vector3(1.02, 0.68, 0.9),
		Vector3(0.9, 0.62, 0.84),
		Vector3(0.86, 0.58, 0.8),
	]
	for index in range(foliage_positions.size()):
		var foliage_mesh := SphereMesh.new()
		foliage_mesh.radius = 0.82
		foliage_mesh.height = 1.64
		_add_mesh(foliage_mesh, leaf_material, foliage_positions[index], Vector3.ZERO, foliage_scales[index])

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.64
	cap_mesh.height = 1.15
	_add_mesh(cap_mesh, leaf_material, Vector3(0.0, 4.92, 0.0), Vector3.ZERO, Vector3(0.84, 0.52, 0.84))

	_add_simple_trunk_collision()


func _add_simple_trunk_collision() -> void:
	hit_body = StaticBody3D.new()
	hit_body.name = "CollisionBody"
	hit_body.collision_layer = 2
	hit_body.collision_mask = 0
	add_child(hit_body)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 1.6, 0.0)
	hit_body.add_child(shape)


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
	visual_root.add_child(mesh_instance)


func _apply_visual_budget(root: Node) -> void:
	if root is GeometryInstance3D:
		var geometry_root := root as GeometryInstance3D
		geometry_root.cast_shadow = SHADOW_CASTING
		geometry_root.visibility_range_end = VISIBILITY_END

	for child in root.get_children():
		_apply_visual_budget(child)
