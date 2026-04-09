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
const LanDiscoveryScript = preload("res://scripts/lan_discovery.gd")
const RemotePlayerAvatarScript = preload("res://scripts/remote_player_avatar.gd")

const AUTOSAVE_INTERVAL_SECONDS := 12.0
const FPS_SAMPLE_WINDOW_SECONDS := 3.0
const FPS_DROP_THRESHOLD := 28.0
const QUALITY_STEP_COOLDOWN_SECONDS := 10.0
const LAN_BASE_PORT := 28650
const LAN_MAX_PORT_ATTEMPTS := 12
const LAN_MAX_CLIENTS := 6
const LAN_JOIN_TIMEOUT_SECONDS := 8.0
const LAN_PLAYER_SYNC_INTERVAL_SECONDS := 0.1

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
var player_name := "Player"

var lan_discovery
var lan_mode := "offline"
var lan_port := 0
var lan_session_id := ""
var lan_join_error := ""
var pending_lan_snapshot: Dictionary = {}
var connected_peer_names: Dictionary = {}
var remote_players: Dictionary = {}
var remote_players_root: Node3D
var lan_state_sync_timer := 0.0


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
	graphics_settings = settings_manager.load_settings()
	player_name = String(graphics_settings.get("player_name", "Player"))
	graphics_settings["player_name"] = player_name
	settings_manager.save_settings(graphics_settings)
	_build_lan_discovery()
	multiplayer.peer_connected.connect(_on_lan_peer_connected)
	multiplayer.peer_disconnected.connect(_on_lan_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_lan_connected_to_server)
	multiplayer.connection_failed.connect(_on_lan_connection_failed)
	multiplayer.server_disconnected.connect(_on_lan_server_disconnected)
	_build_main_menu()
	_build_autosave_timer()
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
	_update_lan_runtime(delta)


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
	main_menu.lan_join_requested.connect(_on_lan_join_requested)
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
	player.block_break_requested.connect(_on_player_block_break_requested)
	player.block_place_requested.connect(_on_player_block_place_requested)
	player.prop_break_requested.connect(_on_player_prop_break_requested)


func _build_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)

	player.inventory_changed.connect(hud.set_inventory)
	player.selected_block_changed.connect(hud.set_selected_block)
	player.target_block_changed.connect(hud.set_targeted_block)
	hud.mod_toggle_requested.connect(_on_mod_toggle_requested)
	hud.world_regenerate_requested.connect(_on_world_regenerate_requested)
	hud.chat_submitted.connect(_on_chat_submitted)
	hud.overlay_mode_changed.connect(_on_overlay_mode_changed)


func _destroy_runtime_nodes() -> void:
	_clear_remote_players()
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
	hud.clear_chat_messages()
	hud.set_network_status(_get_lan_status_text())
	_ensure_remote_players_root()


func _refresh_menu_slots(show_menu: bool = true) -> void:
	main_menu.set_slots(save_manager.list_slots())
	if lan_discovery != null:
		main_menu.set_lan_sessions(lan_discovery.get_sessions())
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

	_shutdown_lan_session()
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
	_start_lan_host()

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
	if lan_mode != "offline":
		hud.append_chat_message("System", "La regeneration de seed est desactivee pendant une session LAN.")
		return

	world.reload_world(true)
	player.respawn_at(world.get_spawn_position())
	_refresh_runtime_ui()
	_update_lan_announcement()
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
		_shutdown_lan_session()
		_destroy_runtime_nodes()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_menu_slots()


func _on_quit_requested() -> void:
	_save_active_slot()
	_shutdown_lan_session()
	get_tree().quit()


func _on_autosave_timeout() -> void:
	_save_active_slot()


func _on_mod_toggle_requested(mod_id: String) -> void:
	if lan_mode != "offline":
		if hud != null:
			hud.append_chat_message("System", "Les mods ne peuvent pas etre modifies pendant une session LAN.")
		return
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


func _build_lan_discovery() -> void:
	lan_discovery = LanDiscoveryScript.new()
	add_child(lan_discovery)
	lan_discovery.sessions_updated.connect(_on_lan_sessions_updated)
	lan_discovery.call_deferred("start_discovery")


func _start_lan_host() -> void:
	if world == null:
		return
	_shutdown_lan_session()
	var peer := ENetMultiplayerPeer.new()
	var selected_port := 0
	for offset in range(LAN_MAX_PORT_ATTEMPTS):
		var candidate_port := LAN_BASE_PORT + offset
		if peer.create_server(candidate_port, LAN_MAX_CLIENTS) == OK:
			selected_port = candidate_port
			break
	if selected_port == 0:
		lan_mode = "offline"
		_update_lan_announcement()
		_update_lan_status_ui()
		return

	multiplayer.multiplayer_peer = peer
	lan_mode = "host"
	lan_port = selected_port
	lan_session_id = "%s-%s-%s" % [player_name, world.get_seed(), Time.get_ticks_msec()]
	connected_peer_names.clear()
	connected_peer_names[multiplayer.get_unique_id()] = player_name
	lan_state_sync_timer = 0.0
	_update_lan_announcement()
	_update_lan_status_ui()
	if hud != null:
		hud.append_chat_message("System", "Monde LAN diffuse sur le reseau local.")


func _shutdown_lan_session() -> void:
	lan_mode = "offline"
	lan_port = 0
	lan_session_id = ""
	lan_join_error = ""
	pending_lan_snapshot.clear()
	connected_peer_names.clear()
	lan_state_sync_timer = 0.0
	_clear_remote_players()
	if lan_discovery != null:
		lan_discovery.clear_host_payload()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_update_lan_status_ui()


func _update_lan_announcement() -> void:
	if lan_discovery == null:
		return
	if lan_mode != "host" or world == null:
		lan_discovery.clear_host_payload()
		return
	var summary := world.get_world_summary()
	lan_discovery.set_host_payload(
		{
			"session_id": lan_session_id,
			"port": lan_port,
			"world_name": session_title if not session_title.is_empty() else "World %s" % max(active_slot_id, 1),
			"host_name": player_name,
			"seed": world.get_seed(),
			"biome": String(summary.get("spawn_biome", "temperate")),
			"player_count": max(1, connected_peer_names.size()),
			"max_players": LAN_MAX_CLIENTS,
			"version": launcher_version,
		}
	)


func _get_lan_status_text() -> String:
	match lan_mode:
		"host":
			return "LAN Host  |  %s joueur(s)  |  port %s" % [max(1, connected_peer_names.size()), lan_port]
		"client":
			return "LAN Client  |  connecte a %s" % String(connected_peer_names.get(1, "Host"))
	return "Offline"


func _update_lan_status_ui() -> void:
	if hud != null:
		hud.set_network_status(_get_lan_status_text())


func _update_lan_runtime(delta: float) -> void:
	if lan_mode == "offline" or player == null or world == null or multiplayer.multiplayer_peer == null:
		return
	lan_state_sync_timer += delta
	if lan_state_sync_timer < LAN_PLAYER_SYNC_INTERVAL_SECONDS:
		return
	lan_state_sync_timer = 0.0
	var state := player.get_network_state()
	if lan_mode == "host":
		if remote_players.size() > 0:
			rpc("_sync_remote_player_state", multiplayer.get_unique_id(), state)
	elif lan_mode == "client":
		rpc_id(1, "_submit_player_state", state)


func _ensure_remote_players_root() -> void:
	if world == null:
		return
	if remote_players_root != null and is_instance_valid(remote_players_root):
		return
	remote_players_root = Node3D.new()
	remote_players_root.name = "RemotePlayers"
	world.add_child(remote_players_root)


func _clear_remote_players() -> void:
	for avatar_variant in remote_players.values():
		if avatar_variant is Node:
			(avatar_variant as Node).queue_free()
	remote_players.clear()
	if remote_players_root != null and is_instance_valid(remote_players_root):
		remote_players_root.queue_free()
	remote_players_root = null


func _ensure_remote_player_avatar(peer_id: int):
	if peer_id == multiplayer.get_unique_id():
		return null
	if remote_players.has(peer_id) and is_instance_valid(remote_players[peer_id]):
		return remote_players[peer_id]
	_ensure_remote_players_root()
	var avatar = RemotePlayerAvatarScript.new()
	remote_players_root.add_child(avatar)
	avatar.set_display_name(String(connected_peer_names.get(peer_id, "Peer %s" % peer_id)))
	remote_players[peer_id] = avatar
	return avatar


func _apply_remote_player_state(peer_id: int, state: Dictionary) -> void:
	var avatar = _ensure_remote_player_avatar(peer_id)
	if avatar == null:
		return
	avatar.apply_state(state)
	avatar.set_display_name(String(connected_peer_names.get(peer_id, "Peer %s" % peer_id)))


func _remove_remote_player(peer_id: int) -> void:
	if not remote_players.has(peer_id):
		return
	var avatar = remote_players[peer_id]
	remote_players.erase(peer_id)
	if avatar is Node:
		(avatar as Node).queue_free()


func _build_lan_snapshot() -> Dictionary:
	return {
		"meta": {
			"title": session_title if not session_title.is_empty() else "LAN World",
			"host_name": player_name,
			"enabled_mod_ids": mod_loader.get_enabled_mod_ids(),
		},
		"world": world.get_save_state() if world != null else {},
	}


func _join_lan_world(session: Dictionary) -> void:
	if is_loading_session:
		return
	is_loading_session = true
	main_menu.show_loading("Joining LAN World", "Connexion au monde reseau...")
	await get_tree().process_frame

	_shutdown_lan_session()
	_destroy_runtime_nodes()
	mod_loader.load_mods()
	BlockLibrary.apply_mod_blocks(mod_loader.get_enabled_block_definitions())
	pending_lan_snapshot.clear()
	lan_join_error = ""
	lan_mode = "client"

	var address := String(session.get("address", ""))
	var port := int(session.get("port", 0))
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port)
	if result != OK:
		lan_join_error = "Connexion LAN impossible."
	else:
		multiplayer.multiplayer_peer = peer

	var start_msec := Time.get_ticks_msec()
	while pending_lan_snapshot.is_empty() and lan_join_error.is_empty():
		var elapsed := float(Time.get_ticks_msec() - start_msec) / 1000.0
		if elapsed >= LAN_JOIN_TIMEOUT_SECONDS:
			lan_join_error = "Le host LAN n'a pas repondu a temps."
			break
		main_menu.set_loading_progress(min(0.92, elapsed / LAN_JOIN_TIMEOUT_SECONDS), "Attente du snapshot reseau et des donnees du monde...")
		await get_tree().process_frame

	if not lan_join_error.is_empty():
		_shutdown_lan_session()
		_refresh_menu_slots(true)
		main_menu.show_loading("Join failed", lan_join_error)
		await get_tree().create_timer(0.8).timeout
		_refresh_menu_slots(true)
		is_loading_session = false
		return

	await _start_lan_client_session(pending_lan_snapshot)
	is_loading_session = false


func _start_lan_client_session(snapshot: Dictionary) -> void:
	var snapshot_meta: Dictionary = snapshot.get("meta", {})
	var saved_mod_ids: Array[String] = []
	for mod_id in snapshot_meta.get("enabled_mod_ids", []):
		saved_mod_ids.append(String(mod_id))
	if not saved_mod_ids.is_empty():
		mod_loader.set_enabled_mods(saved_mod_ids)
	BlockLibrary.apply_mod_blocks(mod_loader.get_enabled_block_definitions())

	var runtime_profile_data: Dictionary = runtime_profile.build_profile(String(graphics_settings.get("graphics_preset", "auto")))
	current_graphics_preset = String(graphics_settings.get("graphics_preset", "auto"))
	main_menu.set_loading_progress(0.12, "Construction du monde reseau...")
	_build_world()
	world.apply_runtime_profile(runtime_profile_data)
	world.load_from_save(snapshot.get("world", {}))

	while not world.is_initial_streaming_complete():
		main_menu.set_loading_progress(0.12 + world.get_loading_progress() * 0.56, "Generation locale du monde du host...")
		await get_tree().process_frame

	main_menu.set_loading_progress(0.76, "Spawning client player...")
	_build_player()
	player.respawn_at(world.get_spawn_position())
	world.finish_initial_streaming()

	main_menu.set_loading_progress(0.9, "Building LAN HUD...")
	_build_hud()
	_refresh_runtime_ui()
	await get_tree().process_frame

	active_slot_id = 0
	session_title = "%s (LAN)" % String(snapshot_meta.get("title", "LAN World"))
	session_started_msec = Time.get_ticks_msec()
	session_base_play_time = 0.0
	fps_sample_time = 0.0
	fps_sample_accumulator = 0.0
	fps_sample_count = 0
	quality_step_cooldown = 0.0
	main_menu.set_loading_progress(1.0, "LAN world ready.")
	await get_tree().create_timer(0.2).timeout
	main_menu.hide_menu()
	player.set_mouse_capture_enabled(true)
	_update_lan_status_ui()
	if hud != null:
		hud.append_chat_message("System", "Connecte au monde LAN de %s." % String(snapshot_meta.get("host_name", "Host")))


func _on_player_block_break_requested(cell: Vector3i) -> void:
	if world == null or player == null:
		return
	if lan_mode == "client":
		rpc_id(1, "_request_break_block", cell)
		return
	var break_result := world.break_block(cell)
	if not break_result.is_empty():
		player.apply_loot_result(break_result)
		player.play_break_feedback()
		if lan_mode == "host":
			rpc("_sync_block_state", cell, BlockLibrary.AIR, true)


func _on_player_block_place_requested(cell: Vector3i, block_id: int, player_position: Vector3) -> void:
	if world == null or player == null:
		return
	if lan_mode == "client":
		rpc_id(1, "_request_place_block", cell, block_id, player_position)
		return
	if world.place_block(cell, block_id, player_position):
		player.consume_block_from_inventory(block_id, 1)
		player.play_place_feedback()
		if lan_mode == "host":
			rpc("_sync_block_state", cell, block_id, false)


func _on_player_prop_break_requested(prop_key: String) -> void:
	if world == null or player == null:
		return
	if lan_mode == "client":
		rpc_id(1, "_request_break_prop", prop_key)
		return
	var result := world.apply_damage_to_prop(prop_key)
	if not result.is_empty():
		player.apply_loot_result(result)
		player.play_break_feedback()
		if lan_mode == "host":
			rpc("_sync_prop_removed", prop_key)


func _on_chat_submitted(message: String) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		return
	if lan_mode == "client":
		rpc_id(1, "_submit_chat_message", trimmed)
		return
	if hud != null:
		hud.append_chat_message(player_name, trimmed)
	if lan_mode == "host":
		rpc("_push_chat_message", player_name, trimmed)


func _on_lan_sessions_updated(sessions: Array[Dictionary]) -> void:
	if main_menu != null:
		main_menu.set_lan_sessions(sessions)


func _on_lan_join_requested(session: Dictionary) -> void:
	await _join_lan_world(session)


func _on_lan_peer_connected(peer_id: int) -> void:
	if lan_mode == "host":
		connected_peer_names[peer_id] = "Peer %s" % peer_id
		_update_lan_announcement()
		_update_lan_status_ui()


func _on_lan_peer_disconnected(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	connected_peer_names.erase(peer_id)
	if lan_mode == "host":
		rpc("_drop_remote_player", peer_id)
		_update_lan_announcement()
	_update_lan_status_ui()
	if hud != null and lan_mode != "offline":
		hud.append_chat_message("System", "Peer %s a quitte la session." % peer_id)


func _on_lan_connected_to_server() -> void:
	if lan_mode != "client":
		return
	connected_peer_names.clear()
	rpc_id(1, "_request_world_snapshot", player_name)


func _on_lan_connection_failed() -> void:
	if lan_mode == "client":
		lan_join_error = "Connexion au host LAN echouee."


func _on_lan_server_disconnected() -> void:
	if lan_mode != "client":
		return
	lan_join_error = "Le host LAN a ferme la session."
	_shutdown_lan_session()
	_destroy_runtime_nodes()
	_refresh_menu_slots(true)
	if main_menu != null:
		main_menu.show_loading("LAN disconnected", lan_join_error)


@rpc("any_peer", "reliable")
func _request_world_snapshot(requested_name: String) -> void:
	if lan_mode != "host" or world == null:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sanitized_name: String = settings_manager.normalize_player_name(requested_name)
	connected_peer_names[sender_id] = sanitized_name
	for peer_id_variant in connected_peer_names.keys():
		rpc_id(sender_id, "_sync_peer_name", int(peer_id_variant), String(connected_peer_names[peer_id_variant]))
	rpc("_sync_peer_name", sender_id, sanitized_name)
	rpc_id(sender_id, "_receive_world_snapshot", _build_lan_snapshot())
	if hud != null:
		hud.append_chat_message("System", "%s a rejoint le monde." % sanitized_name)
	_update_lan_announcement()
	_update_lan_status_ui()


@rpc("authority", "reliable")
func _receive_world_snapshot(snapshot: Dictionary) -> void:
	pending_lan_snapshot = snapshot.duplicate(true)


@rpc("authority", "reliable", "call_local")
func _sync_peer_name(peer_id: int, peer_name_value: String) -> void:
	connected_peer_names[peer_id] = peer_name_value
	if remote_players.has(peer_id) and is_instance_valid(remote_players[peer_id]):
		remote_players[peer_id].set_display_name(peer_name_value)
	_update_lan_status_ui()


@rpc("any_peer", "reliable")
func _submit_chat_message(message: String) -> void:
	if lan_mode != "host":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_name := String(connected_peer_names.get(sender_id, "Peer %s" % sender_id))
	var sanitized_message := message.strip_edges().substr(0, 180)
	if sanitized_message.is_empty():
		return
	if hud != null:
		hud.append_chat_message(sender_name, sanitized_message)
	rpc("_push_chat_message", sender_name, sanitized_message)


@rpc("authority", "reliable")
func _push_chat_message(sender_name_value: String, message: String) -> void:
	if hud != null:
		hud.append_chat_message(sender_name_value, message)


@rpc("any_peer", "reliable")
func _request_break_block(cell: Vector3i) -> void:
	if lan_mode != "host" or world == null:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var result := world.break_block(cell)
	if result.is_empty():
		return
	rpc("_sync_block_state", cell, BlockLibrary.AIR, true)
	rpc_id(sender_id, "_grant_loot", result)


@rpc("any_peer", "reliable")
func _request_place_block(cell: Vector3i, block_id: int, player_position: Vector3) -> void:
	if lan_mode != "host" or world == null:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not world.place_block(cell, block_id, player_position):
		return
	rpc("_sync_block_state", cell, block_id, false)
	rpc_id(sender_id, "_confirm_place", block_id)


@rpc("any_peer", "reliable")
func _request_break_prop(prop_key: String) -> void:
	if lan_mode != "host" or world == null:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var result := world.apply_damage_to_prop(prop_key)
	if result.is_empty():
		return
	rpc("_sync_prop_removed", prop_key)
	rpc_id(sender_id, "_grant_loot", result)


@rpc("authority", "reliable")
func _sync_block_state(cell: Vector3i, block_id: int, play_break_effect: bool) -> void:
	if world != null:
		world.set_block_state(cell, block_id, play_break_effect)


@rpc("authority", "reliable")
func _sync_prop_removed(prop_key: String) -> void:
	if world != null:
		world.mark_prop_removed(prop_key)


@rpc("authority", "reliable")
func _grant_loot(result: Dictionary) -> void:
	if player != null:
		player.apply_loot_result(result)
		player.play_break_feedback()


@rpc("authority", "reliable")
func _confirm_place(block_id: int) -> void:
	if player != null:
		player.consume_block_from_inventory(block_id, 1)
		player.play_place_feedback()


@rpc("any_peer", "unreliable_ordered")
func _submit_player_state(state: Dictionary) -> void:
	if lan_mode != "host":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_apply_remote_player_state(sender_id, state)
	rpc("_sync_remote_player_state", sender_id, state)


@rpc("authority", "unreliable_ordered")
func _sync_remote_player_state(peer_id: int, state: Dictionary) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	_apply_remote_player_state(peer_id, state)


@rpc("authority", "reliable")
func _drop_remote_player(peer_id: int) -> void:
	_remove_remote_player(peer_id)


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
