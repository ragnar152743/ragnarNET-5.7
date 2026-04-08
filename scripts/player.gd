extends CharacterBody3D
class_name PlayerController

signal inventory_changed(slot_view)
signal selected_block_changed(slot_index, block_name)
signal target_block_changed(label_text)

const WALK_SPEED := 6.8
const SPRINT_SPEED := 10.4
const GROUND_ACCELERATION := 18.0
const GROUND_DECELERATION := 22.0
const AIR_ACCELERATION := 6.2
const AIR_DECELERATION := 2.4
const JUMP_VELOCITY := 6.55
const COYOTE_TIME := 0.14
const JUMP_BUFFER_TIME := 0.16
const LOW_JUMP_GRAVITY_MULTIPLIER := 1.3
const FALL_GRAVITY_MULTIPLIER := 1.58
const MAX_FALL_SPEED := 52.0
const LOOK_SENSITIVITY := 0.0022
const INTERACTION_DISTANCE := 7.5
const PROP_BREAK_DURATION := 0.85
const BREAK_ANIMATION_INTERVAL := 0.2
const BREAK_TARGET_GRACE_TIME := 0.18
const SPAWN_LIFT_STEP := 0.35
const MAX_SPAWN_LIFT_STEPS := 14
const CHARACTER_MODEL_PATH := "res://assets/models/character/RobotExpressive.glb"
const CAMERA_HEIGHT := 1.84
const VIEW_MODEL_BASE_OFFSET := Vector3(0.0, -0.08, -0.06)
const BASE_FOV := 82.0
const SPRINT_FOV := 90.5
const FOV_LERP_SPEED := 7.5

var world: VoxelWorld
var head: Node3D
var camera: Camera3D
var break_player: AudioStreamPlayer
var place_player: AudioStreamPlayer

var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var pitch := 0.0
var selected_slot := 0
var last_target_label := ""
var skip_interaction_frame := false
var mouse_look_enabled := true

var inventory_slots: Array[Dictionary] = []

var view_model_root: Node3D
var character_instance: Node3D
var character_animation_player: AnimationPlayer
var character_animations: Dictionary = {}
var character_action_timer := 0.0
var view_model_idle_time := 0.0
var view_model_base_rotation := Vector3.ZERO
var is_sprinting := false
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jump_key_was_down := false
var break_target_signature := ""
var break_progress := 0.0
var break_duration := 1.0
var break_animation_timer := 0.0
var break_target_grace_timer := 0.0
var last_break_hit: Dictionary = {}


func _ready() -> void:
	name = "Player"
	collision_layer = 4
	collision_mask = 3
	safe_margin = 0.03
	floor_snap_length = 0.14
	_initialize_inventory()
	_build_rig()
	_build_audio_players()
	call_deferred("_capture_mouse")
	_emit_inventory_state()


func attach_world(p_world: VoxelWorld) -> void:
	world = p_world
	if world != null:
		world.attach_player_anchor(self)


func respawn_at(spawn_world_position: Vector3) -> void:
	global_position = spawn_world_position
	velocity = Vector3.ZERO
	_reset_break_state()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	jump_key_was_down = false

	for _attempt in range(MAX_SPAWN_LIFT_STEPS):
		if not test_move(global_transform, Vector3.ZERO):
			return
		global_position.y += SPAWN_LIFT_STEP


func set_mouse_capture_enabled(enabled: bool) -> void:
	if enabled:
		_capture_mouse()
	else:
		_release_mouse()


func filter_inventory_against_registry() -> void:
	var valid_blocks := BlockLibrary.get_placeable_block_ids()
	for slot_index in range(inventory_slots.size()):
		var slot := inventory_slots[slot_index]
		if int(slot.get("block_id", BlockLibrary.AIR)) == BlockLibrary.AIR:
			continue
		if valid_blocks.has(int(slot.get("block_id", BlockLibrary.AIR))):
			continue
		inventory_slots[slot_index] = _make_empty_slot()
	_emit_inventory_state()


func get_inventory_names() -> Array[String]:
	var names: Array[String] = []
	for slot in inventory_slots:
		var block_id := int(slot.get("block_id", BlockLibrary.AIR))
		names.append("" if block_id == BlockLibrary.AIR else BlockLibrary.get_display_name(block_id))
	return names


func get_inventory_view() -> Array[Dictionary]:
	var slot_view: Array[Dictionary] = []
	for slot in inventory_slots:
		var block_id := int(slot.get("block_id", BlockLibrary.AIR))
		var count := int(slot.get("count", 0))
		if block_id == BlockLibrary.AIR or count <= 0:
			slot_view.append(
				{
					"empty": true,
					"name": "Empty",
					"count": 0,
					"accent": Color(0.24, 0.3, 0.38),
				}
			)
			continue

		slot_view.append(
			{
				"empty": false,
				"name": BlockLibrary.get_display_name(block_id),
				"count": count,
				"accent": BlockLibrary.get_item_color(block_id),
			}
		)
	return slot_view


func get_selected_display_name() -> String:
	var block_id := _get_selected_block_id()
	if block_id == BlockLibrary.AIR:
		return "Empty"
	return BlockLibrary.get_display_name(block_id)


func get_save_state() -> Dictionary:
	var serialized_slots: Array = []
	for slot in inventory_slots:
		serialized_slots.append(
			{
				"block_id": int(slot.get("block_id", BlockLibrary.AIR)),
				"count": int(slot.get("count", 0)),
			}
		)

	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": pitch,
		"selected_slot": selected_slot,
		"inventory_slots": serialized_slots,
	}


func apply_save_state(state: Dictionary) -> void:
	_initialize_inventory()

	var serialized_slots: Array = state.get("inventory_slots", [])
	for slot_index in range(min(serialized_slots.size(), inventory_slots.size())):
		var slot_data = serialized_slots[slot_index]
		if slot_data is Dictionary:
			inventory_slots[slot_index] = {
				"block_id": int(slot_data.get("block_id", BlockLibrary.AIR)),
				"count": int(slot_data.get("count", 0)),
			}

	filter_inventory_against_registry()
	selected_slot = clampi(int(state.get("selected_slot", 0)), 0, max(0, inventory_slots.size() - 1))
	rotation.y = float(state.get("yaw", 0.0))
	pitch = clampf(float(state.get("pitch", 0.0)), deg_to_rad(-88.0), deg_to_rad(88.0))
	if head != null:
		head.rotation.x = pitch

	var position_data: Array = state.get("position", [])
	if position_data.size() >= 3:
		respawn_at(Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2])))
	else:
		respawn_at(world.get_spawn_position() if world != null else global_position)

	_emit_inventory_state()


func _ready_character_animation_state() -> void:
	if character_animation_player == null:
		return

	for animation_name in character_animation_player.get_animation_list():
		character_animations[String(animation_name).to_lower()] = String(animation_name)

	_play_character_animation(_resolve_character_animation(["idle", "standing", "breathing idle"]))


func _build_rig() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.37
		capsule.height = 1.18
		collision.shape = capsule
		collision.position = Vector3(0.0, 0.97, 0.0)
		add_child(collision)

	head = get_node_or_null("Head")
	if head == null:
		head = Node3D.new()
		head.name = "Head"
		head.position = Vector3(0.0, CAMERA_HEIGHT, 0.0)
		add_child(head)
	else:
		head.position.y = CAMERA_HEIGHT

	camera = head.get_node_or_null("Camera3D")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		camera.fov = BASE_FOV
		camera.near = 0.05
		head.add_child(camera)

	view_model_root = camera.get_node_or_null("ViewModelRoot")
	if view_model_root == null:
		view_model_root = Node3D.new()
		view_model_root.name = "ViewModelRoot"
		camera.add_child(view_model_root)
	view_model_root.position = VIEW_MODEL_BASE_OFFSET
	view_model_root.rotation = view_model_base_rotation

	_build_character_view_model()


func _build_character_view_model() -> void:
	if ResourceLoader.exists(CHARACTER_MODEL_PATH):
		var resource = load(CHARACTER_MODEL_PATH)
		if resource is PackedScene:
			character_instance = resource.instantiate()
			character_instance.position = Vector3(0.0, -1.42, -0.18)
			character_instance.rotation = Vector3(0.0, PI, 0.0)
			character_instance.scale = Vector3.ONE * 0.98
			view_model_root.add_child(character_instance)
			_configure_first_person_character(character_instance)
			character_animation_player = _find_animation_player(character_instance)
			_ready_character_animation_state()
			return

	_build_fallback_view_model()


func _build_fallback_view_model() -> void:
	var materials := BlockLibrary.create_prop_materials()
	var arm_material: Material = materials["trunk"]

	for arm_index in range(2):
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.56, 0.16)
		arm.mesh = box
		arm.material_override = arm_material
		arm.position = Vector3(-0.18 if arm_index == 0 else 0.18, -0.46, -0.62)
		arm.rotation_degrees = Vector3(-18.0, 0.0, -10.0 if arm_index == 0 else 10.0)
		view_model_root.add_child(arm)


func _configure_first_person_character(node: Node) -> void:
	if node is MeshInstance3D:
		var lowered_name := node.name.to_lower()
		var keep_visible := (
			lowered_name.contains("arm_l")
			or lowered_name.contains("arm_r")
			or lowered_name.contains("hand_l")
			or lowered_name.contains("hand_r")
			or lowered_name.contains("shoulder_l")
			or lowered_name.contains("shoulder_r")
		)
		(node as MeshInstance3D).visible = keep_visible

	for child in node.get_children():
		_configure_first_person_character(child)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player
	return null


func _build_audio_players() -> void:
	break_player = AudioStreamPlayer.new()
	break_player.name = "BreakSound"
	add_child(break_player)

	place_player = AudioStreamPlayer.new()
	place_player.name = "PlaceSound"
	add_child(place_player)

	if ResourceLoader.exists("res://assets/audio/break_block.ogg"):
		break_player.stream = load("res://assets/audio/break_block.ogg")

	if ResourceLoader.exists("res://assets/audio/place_block.ogg"):
		place_player.stream = load("res://assets/audio/place_block.ogg")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_look_enabled:
		apply_look_delta(event.relative)
		return

	if event is InputEventMouseButton and event.pressed and not mouse_look_enabled:
		skip_interaction_frame = true
		_capture_mouse()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mouse_look_enabled:
			_release_mouse()
		else:
			_capture_mouse()


func _physics_process(delta: float) -> void:
	_handle_selection_input()
	_handle_movement(delta)
	move_and_slide()
	_update_camera_fov(delta)
	_update_view_model_animation(delta)

	if world != null:
		if skip_interaction_frame:
			skip_interaction_frame = false
		else:
			_handle_block_interactions(delta)
		_update_targeted_block()
		if global_position.y < world.get_kill_plane_y():
			respawn_at(world.get_spawn_position())


func _handle_movement(delta: float) -> void:
	var input_vector := _get_move_input()
	var wants_sprint := _is_sprint_pressed() and input_vector.y > -0.1 and input_vector.length_squared() > 0.0
	var on_floor := is_on_floor()
	is_sprinting = wants_sprint and on_floor
	var move_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	break_animation_timer = max(0.0, break_animation_timer - delta)

	if on_floor:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	var jump_down := _is_jump_held()
	if jump_down and not jump_key_was_down:
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	jump_key_was_down = jump_down

	var basis := global_transform.basis
	var forward := -basis.z
	var right := basis.x
	var move_direction := (right * input_vector.x + forward * input_vector.y)
	move_direction.y = 0.0
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	var target_velocity := move_direction * move_speed
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var target_horizontal_velocity := Vector2(target_velocity.x, target_velocity.z)
	var acceleration := GROUND_ACCELERATION if move_direction.length_squared() > 0.0 else GROUND_DECELERATION
	if not on_floor:
		acceleration = AIR_ACCELERATION if move_direction.length_squared() > 0.0 else AIR_DECELERATION
	if is_sprinting and on_floor and move_direction.length_squared() > 0.0:
		acceleration *= 1.08

	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.y

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		floor_snap_length = 0.0
	elif on_floor:
		floor_snap_length = 0.14
		if velocity.y < 0.0:
			velocity.y = max(velocity.y, -2.0)
	else:
		floor_snap_length = 0.0
		var gravity_multiplier := FALL_GRAVITY_MULTIPLIER if velocity.y < 0.0 else 1.0
		if velocity.y > 0.0 and not _is_jump_held():
			gravity_multiplier = LOW_JUMP_GRAVITY_MULTIPLIER
		velocity.y -= gravity * gravity_multiplier * delta

	velocity.y = max(velocity.y, -MAX_FALL_SPEED)


func _handle_selection_input() -> void:
	for slot_index in range(inventory_slots.size()):
		var action_name := "slot_%s" % [slot_index + 1]
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			_set_selected_slot(slot_index)

	if InputMap.has_action("next_block") and Input.is_action_just_pressed("next_block"):
		_set_selected_slot((selected_slot + 1) % inventory_slots.size())

	if InputMap.has_action("prev_block") and Input.is_action_just_pressed("prev_block"):
		_set_selected_slot((selected_slot - 1 + inventory_slots.size()) % inventory_slots.size())


func _set_selected_slot(slot_index: int) -> void:
	selected_slot = clampi(slot_index, 0, inventory_slots.size() - 1)
	selected_block_changed.emit(selected_slot, get_selected_display_name())


func _handle_block_interactions(delta: float) -> void:
	if not mouse_look_enabled:
		_reset_break_state()
		return

	var hit := _query_target()
	var wants_break := Input.is_action_pressed("break_block")
	if hit.is_empty():
		break_target_grace_timer = max(0.0, break_target_grace_timer - delta)
		if wants_break and break_target_grace_timer > 0.0 and not last_break_hit.is_empty():
			hit = last_break_hit.duplicate(true)
	else:
		last_break_hit = hit.duplicate(true)
		break_target_grace_timer = BREAK_TARGET_GRACE_TIME

	if wants_break and not hit.is_empty():
		var target_signature := _build_break_signature(hit)
		if target_signature.is_empty():
			_reset_break_state()
		else:
			if target_signature != break_target_signature:
				break_target_signature = target_signature
				break_progress = 0.0
				break_duration = _get_break_duration_for_hit(hit)
				break_animation_timer = 0.0

			if break_animation_timer <= 0.0:
				_play_break_animation()
				break_animation_timer = BREAK_ANIMATION_INTERVAL

			break_progress = min(1.0, break_progress + delta / max(break_duration, 0.01))
			if break_progress >= 1.0:
				_complete_break(hit)
				_reset_break_state()
	else:
		_reset_break_state()

	if Input.is_action_just_pressed("place_block"):
		if hit.is_empty():
			return
		if String(hit.get("kind", "")) != "block":
			return
		var block_id := _get_selected_block_id()
		if block_id == BlockLibrary.AIR:
			return
		if world.place_block(hit["place_cell"], block_id, global_position):
			if _consume_selected_block(1):
				_play_sound_if_ready(place_player)


func _apply_loot(result: Dictionary) -> void:
	if result.is_empty():
		return

	if result.has("block_id"):
		add_block_to_inventory(int(result.get("block_id", BlockLibrary.AIR)), int(result.get("count", 0)))
		return

	if result.has("drops"):
		for drop in result.get("drops", []):
			if drop is Dictionary:
				add_block_to_inventory(int(drop.get("block_id", BlockLibrary.AIR)), int(drop.get("count", 0)))


func add_block_to_inventory(block_id: int, count: int) -> int:
	if block_id == BlockLibrary.AIR or count <= 0:
		return 0

	var remaining := count
	var stack_limit := BlockLibrary.get_stack_limit(block_id)

	for slot in inventory_slots:
		if int(slot.get("block_id", BlockLibrary.AIR)) != block_id:
			continue
		var space_left := stack_limit - int(slot.get("count", 0))
		if space_left <= 0:
			continue
		var amount: int = min(space_left, remaining)
		slot["count"] = int(slot.get("count", 0)) + amount
		remaining -= amount
		if remaining <= 0:
			_emit_inventory_state()
			return 0

	for slot in inventory_slots:
		if int(slot.get("block_id", BlockLibrary.AIR)) != BlockLibrary.AIR:
			continue
		var amount: int = min(stack_limit, remaining)
		slot["block_id"] = block_id
		slot["count"] = amount
		remaining -= amount
		if remaining <= 0:
			_emit_inventory_state()
			return 0

	_emit_inventory_state()
	return remaining


func _consume_selected_block(amount: int) -> bool:
	var slot := inventory_slots[selected_slot]
	var count := int(slot.get("count", 0))
	if count < amount:
		return false

	slot["count"] = count - amount
	if int(slot.get("count", 0)) <= 0:
		inventory_slots[selected_slot] = _make_empty_slot()

	_emit_inventory_state()
	return true


func _update_targeted_block() -> void:
	var label := ""
	if mouse_look_enabled:
		var hit := _query_target()
		if not hit.is_empty():
			label = String(hit.get("display_name", ""))
			var target_signature := _build_break_signature(hit)
			if target_signature == break_target_signature and break_progress > 0.0:
				label = "%s (%s%%)" % [label, int(round(break_progress * 100.0))]

	if label == last_target_label:
		return

	last_target_label = label
	target_block_changed.emit(label)


func _query_target() -> Dictionary:
	if world == null or camera == null:
		return {}

	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * INTERACTION_DISTANCE
	return world.pick_target(from, to)


func apply_look_delta(relative: Vector2) -> void:
	rotate_y(-relative.x * LOOK_SENSITIVITY)
	pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY, deg_to_rad(-88.0), deg_to_rad(88.0))
	head.rotation.x = pitch


func _capture_mouse() -> void:
	mouse_look_enabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _release_mouse() -> void:
	mouse_look_enabled = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _get_move_input() -> Vector2:
	var input_vector := Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var raw_x := 0.0
	var raw_y := 0.0

	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		raw_x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		raw_x += 1.0
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		raw_y += 1.0
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		raw_y -= 1.0

	var raw_vector := Vector2(raw_x, raw_y)
	if raw_vector.length_squared() > 1.0:
		raw_vector = raw_vector.normalized()

	if raw_vector.length_squared() > input_vector.length_squared():
		return raw_vector
	return input_vector


func _is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE)


func _is_jump_held() -> bool:
	return Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE)


func _is_sprint_pressed() -> bool:
	return (
		(InputMap.has_action("sprint") and Input.is_action_pressed("sprint"))
		or Input.is_key_pressed(KEY_SHIFT)
		or Input.is_physical_key_pressed(KEY_SHIFT)
	)


func _play_sound_if_ready(player_node: AudioStreamPlayer) -> void:
	if player_node != null and player_node.stream != null:
		player_node.play()


func _emit_inventory_state() -> void:
	inventory_changed.emit(get_inventory_view())
	selected_block_changed.emit(selected_slot, get_selected_display_name())
	target_block_changed.emit(last_target_label)


func _initialize_inventory() -> void:
	inventory_slots.clear()
	for _slot_index in range(BlockLibrary.get_hotbar_size()):
		inventory_slots.append(_make_empty_slot())


func _make_empty_slot() -> Dictionary:
	return {
		"block_id": BlockLibrary.AIR,
		"count": 0,
	}


func _get_selected_block_id() -> int:
	if selected_slot < 0 or selected_slot >= inventory_slots.size():
		return BlockLibrary.AIR
	return int(inventory_slots[selected_slot].get("block_id", BlockLibrary.AIR))


func _update_view_model_animation(delta: float) -> void:
	if view_model_root == null:
		return

	view_model_idle_time += delta
	character_action_timer = max(0.0, character_action_timer - delta)
	var bob_speed := 12.5 if is_sprinting else 8.5
	var bob_strength := 0.03 if is_sprinting else 0.02
	var walk_bob: float = sin(view_model_idle_time * bob_speed) * min(1.0, Vector2(velocity.x, velocity.z).length() / max(SPRINT_SPEED, 0.01)) * bob_strength
	view_model_root.position = VIEW_MODEL_BASE_OFFSET + Vector3(0.0, walk_bob, 0.0)

	if character_animation_player == null or character_action_timer > 0.0:
		return

	var animation_candidates: Array[String] = []
	if not is_on_floor():
		animation_candidates = ["jump", "falling"]
	elif Vector2(velocity.x, velocity.z).length() > 0.18:
		animation_candidates = ["running", "run", "walking", "walk"] if is_sprinting else ["walking", "walk", "running", "run"]
	else:
		animation_candidates = ["idle", "standing", "breathing idle"]

	_play_character_animation(_resolve_character_animation(animation_candidates))


func _play_break_animation() -> void:
	if character_animation_player != null:
		var punch_animation := _resolve_character_animation(["punch", "wave", "yes"])
		if not punch_animation.is_empty():
			character_action_timer = 0.42
			character_animation_player.play(punch_animation, 0.08, 1.25)
			return

	character_action_timer = 0.22
	var tween := create_tween()
	tween.tween_property(view_model_root, "rotation_degrees", Vector3(-12.0, 0.0, -10.0), 0.08)
	tween.tween_property(view_model_root, "rotation_degrees", Vector3.ZERO, 0.12)


func _resolve_character_animation(candidates: Array[String]) -> String:
	for candidate in candidates:
		var lowered := candidate.to_lower()
		if character_animations.has(lowered):
			return String(character_animations[lowered])
	return ""


func _play_character_animation(animation_name: String) -> void:
	if character_animation_player == null or animation_name.is_empty():
		return
	if character_animation_player.current_animation == animation_name and character_animation_player.is_playing():
		return
	character_animation_player.play(animation_name, 0.18)


func _update_camera_fov(delta: float) -> void:
	if camera == null:
		return

	var target_fov := SPRINT_FOV if is_sprinting else BASE_FOV
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * FOV_LERP_SPEED, 0.0, 1.0))


func _reset_break_state() -> void:
	break_target_signature = ""
	break_progress = 0.0
	break_duration = 1.0
	break_animation_timer = 0.0
	break_target_grace_timer = 0.0
	last_break_hit.clear()


func _build_break_signature(hit: Dictionary) -> String:
	var hit_kind := String(hit.get("kind", ""))
	if hit_kind == "block":
		var cell: Vector3i = hit.get("cell", Vector3i.ZERO)
		return "block:%s:%s:%s" % [cell.x, cell.y, cell.z]
	if hit_kind == "prop":
		var prop: Variant = hit.get("prop", null)
		if prop is Node:
			return "prop:%s" % int((prop as Node).get_instance_id())
	return ""


func _get_break_duration_for_hit(hit: Dictionary) -> float:
	var hit_kind := String(hit.get("kind", ""))
	if hit_kind == "prop":
		return PROP_BREAK_DURATION
	if hit_kind == "block":
		var cell: Vector3i = hit.get("cell", Vector3i.ZERO)
		return BlockLibrary.get_break_duration(world.get_block(cell))
	return 1.0


func _complete_break(hit: Dictionary) -> void:
	var hit_kind := String(hit.get("kind", ""))
	if hit_kind == "prop":
		var prop = hit.get("prop", null)
		if prop != null and prop.has_method("apply_damage"):
			var result: Dictionary = prop.call("apply_damage")
			_apply_loot(result)
			_play_sound_if_ready(break_player)
		return

	if hit_kind == "block":
		var break_result := world.break_block(hit["cell"])
		if not break_result.is_empty():
			_apply_loot(break_result)
			_play_sound_if_ready(break_player)
