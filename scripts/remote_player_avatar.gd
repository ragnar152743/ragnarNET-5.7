extends Node3D
class_name RemotePlayerAvatar

const CHARACTER_MODEL_PATH := "res://assets/models/character/RobotExpressive.glb"

var _label: Label3D
var _visual_root: Node3D
var _current_pitch := 0.0


func _ready() -> void:
	_build_visual()
	set_display_name("Peer")


func set_display_name(player_name: String) -> void:
	if _label != null:
		_label.text = player_name


func apply_state(state: Dictionary) -> void:
	global_position = state.get("position", global_position)
	rotation.y = float(state.get("yaw", rotation.y))
	_current_pitch = float(state.get("pitch", _current_pitch))


func _process(delta: float) -> void:
	if _visual_root != null:
		_visual_root.rotation.x = lerpf(_visual_root.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))


func _build_visual() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.modulate = Color(0.9, 0.97, 1.0)
	_label.position = Vector3(0.0, 2.18, 0.0)
	add_child(_label)

	_visual_root = Node3D.new()
	_visual_root.position = Vector3(0.0, 0.08, 0.0)
	add_child(_visual_root)

	if ResourceLoader.exists(CHARACTER_MODEL_PATH):
		var scene = load(CHARACTER_MODEL_PATH)
		if scene is PackedScene:
			var instance: Node3D = (scene as PackedScene).instantiate()
			instance.rotation = Vector3(0.0, PI, 0.0)
			instance.scale = Vector3.ONE * 0.98
			_visual_root.add_child(instance)
			_apply_visual_budget(instance)
			return

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.mid_height = 0.95
	body.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.44, 0.78, 0.98)
	material.roughness = 0.56
	body.material_override = material
	body.position = Vector3(0.0, 1.0, 0.0)
	_visual_root.add_child(body)


func _apply_visual_budget(root: Node) -> void:
	if root is GeometryInstance3D:
		var geometry := root as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		geometry.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	for child in root.get_children():
		_apply_visual_budget(child)
