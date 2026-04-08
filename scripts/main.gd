extends Node

const WORLD_SCENE = preload("res://scenes/World.tscn")
const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const HUD_SCENE = preload("res://scenes/ui/HUD.tscn")
const MAIN_MENU_SCENE = preload("res://scenes/ui/MainMenu.tscn")
const ModLoaderScript = preload("res://scripts/mod_loader.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const RuntimeProfileScript = preload("res://scripts/runtime_profile.gd")
const SettingsManagerScript = preload("res://scripts/settings_manager.gd")
const LaunchSecurityScript = preload("res://scripts/launch_security.gd")

const AUTOSAVE_INTERVAL_SECONDS := 12.0
const FPS_SAMPLE_WINDOW_SECONDS := 3.0
const FPS_DROP_THRESHOLD := 28.0
const QUALITY_STEP_COOLDOWN_SECONDS := 10.0

var mod_loader: ModLoader
var save_manager
var settings_manager
var world: VoxelWorld
var player: PlayerController
var hud: HUDLayer
var main_menu
var autosave_timer: Timer
var runtime_profile
var system_profile_data: Dictionary = {}
var graphics_settings: Dictionary = {}
var current_graphics_preset := "auto"
var launcher_version := "1.0.0"
var fps_sample_time := 0.0
var fps_sample_accumulator := 0.0
var fps_sample_count := 0
var quality_step_cooldown := 0.0

var active_slot_id := 0
var session_started_msec := 0
var session_base_play_time := 0.0
var session_title := ""
var is_loading_session := false


func _ready() -> void:
	var launch_validation: Dictionary = LaunchSecurityScript.validate_runtime_launch()
	if not bool(launch_validation.get("authorized", false)):
		var launch_code := String(launch_validation.get("code", "GAME-AUTH-000"))
		if launch_code == "GAME-AUTH-001" and LaunchSecurityScript.try_open_launcher():
			get_tree().quit()
			return
		_show_launch_error_and_quit(
			launch_code,
			String(launch_validation.get("message", "Unauthorized launch."))
		)
		return

	_ensure_input_map()
	mod_loader = ModLoaderScript.new()
	save_manager = SaveManagerScript.new()
	settings_manager = SettingsManagerScript.new()
	runtime_profile = RuntimeProfileScript.new()
	launcher_version = String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	system_profile_data = runtime_profile.get_profile()
	_build_main_menu()
	_build_autosave_timer()
	graphics_settings = settings_manager.load_settings()
	_apply_window_title(true)
	main_menu.set_launcher_context(
		{
			"app_name": "Voxel RTX Game",
			"version": launcher_version,
			"system_profile": system_profile_data,
		}
	)
	main_menu.set_graphics_settings(graphics_settings)
	_refresh_menu_slots()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	if quality_step_cooldown > 0.0:
		quality_step_cooldown = max(0.0, quality_step_cooldown - delta)
	_monitor_performance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if world == null or main_menu.visible:
		return

	if event.is_action_pressed("regenerate_world") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		_regenerate_world()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_active_slot()


func _build_main_menu() -> void:
	main_menu = MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	main_menu.slot_new_requested.connect(_on_slot_new_requested)
	main_menu.slot_load_requested.connect(_on_slot_load_requested)
	main_menu.slot_delete_requested.connect(_on_slot_delete_requested)
	main_menu.quit_requested.connect(_on_quit_requested)
	main_menu.graphics_settings_changed.connect(_on_graphics_settings_changed)


func _build_autosave_timer() -> void:
	autosave_timer = Timer.new()
	autosave_timer.wait_time = AUTOSAVE_INTERVAL_SECONDS
	autosave_timer.one_shot = false
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(autosave_timer)


func _build_world() -> void:
	world = WORLD_SCENE.instantiate()
	world.auto_boot_world = false
	world.configure(mod_loader)
	add_child(world)


func _build_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.attach_world(world)


func _build_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)

	player.inventory_changed.connect(hud.set_inventory)
	player.selected_block_changed.connect(hud.set_selected_block)
	player.target_block_changed.connect(hud.set_targeted_block)
	hud.mod_toggle_requested.connect(_on_mod_toggle_requested)
	hud.world_regenerate_requested.connect(_on_world_regenerate_requested)
	hud.overlay_mode_changed.connect(_on_overlay_mode_changed)


func _destroy_runtime_nodes() -> void:
	for node in [hud, player, world]:
		if node == null:
			continue
		remove_child(node)
		node.queue_free()

	hud = null
	player = null
	world = null


func _refresh_runtime_ui() -> void:
	if world == null or player == null or hud == null:
		return

	world.configure(mod_loader)
	player.attach_world(world)
	player.filter_inventory_against_registry()
	hud.set_mods(mod_loader.get_mod_descriptors())
	hud.set_inventory(player.get_inventory_view())
	hud.set_selected_block(player.selected_slot, player.get_selected_display_name())
	hud.set_targeted_block("")


func _refresh_menu_slots(show_menu: bool = true) -> void:
	main_menu.set_slots(save_manager.list_slots())
	if show_menu:
		_apply_window_title(true)
		main_menu.show_menu()


func _start_new_world(slot_id: int) -> void:
	await _start_session(slot_id, {}, true)


func _load_existing_world(slot_id: int) -> void:
	var slot_data: Dictionary = save_manager.load_slot(slot_id)
	if slot_data.is_empty():
		await _start_session(slot_id, {}, true)
		return
	await _start_session(slot_id, slot_data, false)


func _start_session(slot_id: int, slot_data: Dictionary, is_new_world: bool) -> void:
	if is_loading_session:
		return
	is_loading_session = true

	main_menu.show_loading("Loading World", "Preparing registries and save data...")
	await get_tree().process_frame

	_destroy_runtime_nodes()
	var runtime_profile_data: Dictionary = runtime_profile.build_profile(String(graphics_settings.get("graphics_preset", "auto")))
	current_graphics_preset = String(graphics_settings.get("graphics_preset", "auto"))
	main_menu.set_loading_progress(0.03, "Profiling CPU / GPU / RAM and choosing RTX quality...")
	await get_tree().process_frame

	mod_loader.load_mods()
	if not is_new_world:
		var saved_mod_ids: Array[String] = []
		for mod_id in slot_data.get("meta", {}).get("enabled_mod_ids", []):
			saved_mod_ids.append(String(mod_id))
		if not saved_mod_ids.is_empty():
			mod_loader.set_enabled_mods(saved_mod_ids)

	BlockLibrary.apply_mod_blocks(mod_loader.get_enabled_block_definitions())
	main_menu.set_loading_progress(0.08, "Building world registry and preparing a safe boot zone...")
	await get_tree().process_frame

	_build_world()
	world.apply_runtime_profile(runtime_profile_data)
	main_menu.set_loading_progress(0.18, "Generating terrain and streaming the first safe area...")
	await get_tree().process_frame

	if is_new_world or slot_data.is_empty():
		world.reload_world(true)
		session_base_play_time = 0.0
		session_title = "World %s" % slot_id
	else:
		world.load_from_save(slot_data.get("world", {}))
		session_base_play_time = float(slot_data.get("meta", {}).get("play_time_seconds", 0.0))
		session_title = String(slot_data.get("meta", {}).get("title", "World %s" % slot_id))

	while not world.is_initial_streaming_complete():
		main_menu.set_loading_progress(0.18 + world.get_loading_progress() * 0.54, "Streaming the first world ring...")
		await get_tree().process_frame

	main_menu.set_loading_progress(0.74, "Spawning player and restoring inventory...")
	_build_player()
	await get_tree().process_frame

	if is_new_world or slot_data.is_empty():
		player.respawn_at(world.get_spawn_position())
	else:
		player.apply_save_state(slot_data.get("player", {}))
	world.finish_initial_streaming()

	main_menu.set_loading_progress(0.88, "Building interface and gameplay overlays...")
	_build_hud()
	_refresh_runtime_ui()
	await get_tree().process_frame

	active_slot_id = slot_id
	session_started_msec = Time.get_ticks_msec()
	fps_sample_time = 0.0
	fps_sample_accumulator = 0.0
	fps_sample_count = 0
	quality_step_cooldown = 0.0
	main_menu.set_loading_progress(1.0, "World ready.")
	await get_tree().create_timer(0.2).timeout
	main_menu.hide_menu()
	_apply_window_title(false)
	player.set_mouse_capture_enabled(true)
	_save_active_slot()
	is_loading_session = false


func _regenerate_world() -> void:
	if world == null or player == null or hud == null:
		return

	world.reload_world(true)
	player.respawn_at(world.get_spawn_position())
	_refresh_runtime_ui()
	_save_active_slot()


func _save_active_slot() -> void:
	if active_slot_id <= 0 or world == null or player == null:
		return

	var modified_blocks: Array = world.get_save_state().get("modified_blocks", [])
	var save_payload := {
		"meta": {
			"title": session_title if not session_title.is_empty() else "World %s" % active_slot_id,
			"updated_at": Time.get_datetime_string_from_system(),
			"play_time_seconds": session_base_play_time + _get_elapsed_session_seconds(),
			"modified_block_count": modified_blocks.size(),
			"enabled_mod_ids": mod_loader.get_enabled_mod_ids(),
		},
		"world": world.get_save_state(),
		"player": player.get_save_state(),
	}
	save_manager.save_slot(active_slot_id, save_payload)


func _get_elapsed_session_seconds() -> float:
	if session_started_msec <= 0:
		return 0.0
	return max(0.0, float(Time.get_ticks_msec() - session_started_msec) / 1000.0)


func _on_slot_new_requested(slot_id: int) -> void:
	await _start_new_world(slot_id)
	_refresh_menu_slots(false)


func _on_slot_load_requested(slot_id: int) -> void:
	await _load_existing_world(slot_id)
	_refresh_menu_slots(false)


func _on_slot_delete_requested(slot_id: int) -> void:
	save_manager.delete_slot(slot_id)
	if active_slot_id == slot_id:
		active_slot_id = 0
		session_started_msec = 0
		session_base_play_time = 0.0
		_destroy_runtime_nodes()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_menu_slots()


func _on_quit_requested() -> void:
	_save_active_slot()
	get_tree().quit()


func _on_autosave_timeout() -> void:
	_save_active_slot()


func _on_mod_toggle_requested(mod_id: String) -> void:
	mod_loader.toggle_mod(mod_id)
	BlockLibrary.apply_mod_blocks(mod_loader.get_enabled_block_definitions())
	if world == null or player == null:
		return
	world.reload_world(true)
	player.respawn_at(world.get_spawn_position())
	_refresh_runtime_ui()
	_save_active_slot()


func _on_world_regenerate_requested() -> void:
	_regenerate_world()


func _on_overlay_mode_changed(interactive: bool) -> void:
	if player != null:
		player.set_mouse_capture_enabled(not interactive)


func _on_graphics_settings_changed(settings: Dictionary) -> void:
	graphics_settings["graphics_preset"] = String(settings.get("graphics_preset", "auto")).to_lower()
	graphics_settings["auto_fallback"] = bool(settings.get("auto_fallback", true))
	settings_manager.save_settings(graphics_settings)
	current_graphics_preset = String(graphics_settings.get("graphics_preset", "auto"))

	if world == null:
		return

	var runtime_profile_data: Dictionary = runtime_profile.build_profile(current_graphics_preset)
	world.apply_runtime_profile(runtime_profile_data)
	world.refresh_graphics_profile()
	if player != null:
		player.filter_inventory_against_registry()
	quality_step_cooldown = QUALITY_STEP_COOLDOWN_SECONDS


func _monitor_performance(delta: float) -> void:
	if world == null or main_menu == null or main_menu.visible:
		return
	if not bool(graphics_settings.get("auto_fallback", true)):
		return

	var fps := Engine.get_frames_per_second()
	if fps <= 0:
		return

	fps_sample_time += delta
	fps_sample_accumulator += float(fps)
	fps_sample_count += 1
	if fps_sample_time < FPS_SAMPLE_WINDOW_SECONDS:
		return

	var average_fps: float = fps_sample_accumulator / max(1, fps_sample_count)
	fps_sample_time = 0.0
	fps_sample_accumulator = 0.0
	fps_sample_count = 0

	if average_fps >= FPS_DROP_THRESHOLD or quality_step_cooldown > 0.0:
		return

	_step_down_graphics_quality()


func _step_down_graphics_quality() -> void:
	var next_preset: String = settings_manager.get_next_lower_preset(current_graphics_preset)
	if next_preset == current_graphics_preset:
		return

	graphics_settings["graphics_preset"] = next_preset
	settings_manager.save_settings(graphics_settings)
	current_graphics_preset = next_preset
	main_menu.set_graphics_settings(graphics_settings)

	if world != null:
		var runtime_profile_data: Dictionary = runtime_profile.build_profile(current_graphics_preset)
		world.apply_runtime_profile(runtime_profile_data)
		world.refresh_graphics_profile()

	quality_step_cooldown = QUALITY_STEP_COOLDOWN_SECONDS


func _show_launch_error_and_quit(code: String, detail: String) -> void:
	var title := LaunchSecurityScript.get_product_name()
	var message := "Startup blocked.\nError code: %s\n%s" % [code, detail]
	if code == "GAME-AUTH-001":
		message += "\nOpen VoxelRTXLauncher.exe instead of launching the game executable directly."
	OS.alert(message, title)
	get_tree().quit(1)


func _apply_window_title(show_launcher: bool) -> void:
	DisplayServer.window_set_title("Voxel RTX Game")


func _ensure_input_map() -> void:
	_ensure_action("move_forward")
	_ensure_action("move_backward")
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("jump")
	_ensure_action("sprint")
	_ensure_action("break_block")
	_ensure_action("place_block")
	_ensure_action("next_block")
	_ensure_action("prev_block")
	_ensure_action("toggle_mod_menu")
	_ensure_action("regenerate_world")

	for index in range(BlockLibrary.get_hotbar_size()):
		_ensure_action("slot_%s" % [index + 1])

	_bind_physical_key("move_forward", KEY_W)
	_bind_physical_key("move_backward", KEY_S)
	_bind_physical_key("move_left", KEY_A)
	_bind_physical_key("move_right", KEY_D)
	_bind_physical_key("jump", KEY_SPACE)
	_bind_physical_key("sprint", KEY_SHIFT)

	_bind_keycode("move_forward", KEY_W)
	_bind_keycode("move_forward", KEY_Z)
	_bind_keycode("move_forward", KEY_UP)
	_bind_keycode("move_backward", KEY_S)
	_bind_keycode("move_backward", KEY_DOWN)
	_bind_keycode("move_left", KEY_A)
	_bind_keycode("move_left", KEY_Q)
	_bind_keycode("move_left", KEY_LEFT)
	_bind_keycode("move_right", KEY_D)
	_bind_keycode("move_right", KEY_RIGHT)
	_bind_keycode("jump", KEY_SPACE)
	_bind_keycode("sprint", KEY_SHIFT)
	_bind_keycode("toggle_mod_menu", KEY_M)
	_bind_keycode("regenerate_world", KEY_R)

	_bind_keycode("slot_1", KEY_1)
	_bind_keycode("slot_2", KEY_2)
	_bind_keycode("slot_3", KEY_3)
	_bind_keycode("slot_4", KEY_4)
	_bind_keycode("slot_5", KEY_5)
	_bind_keycode("slot_6", KEY_6)
	_bind_keycode("slot_7", KEY_7)
	_bind_keycode("slot_8", KEY_8)

	_bind_mouse_button("break_block", MOUSE_BUTTON_LEFT)
	_bind_mouse_button("place_block", MOUSE_BUTTON_RIGHT)
	_bind_mouse_button("next_block", MOUSE_BUTTON_WHEEL_UP)
	_bind_mouse_button("prev_block", MOUSE_BUTTON_WHEEL_DOWN)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _bind_physical_key(action_name: StringName, keycode: Key) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _bind_keycode(action_name: StringName, keycode: Key) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.keycode == keycode:
			return

	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)


func _bind_mouse_button(action_name: StringName, button_index: MouseButton) -> void:
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventMouseButton and existing_event.button_index == button_index:
			return

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)
