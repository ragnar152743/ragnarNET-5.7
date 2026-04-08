extends RefCounted
class_name ModLoader

const USER_STATE_PATH := "user://mod_state.cfg"
const PACKED_MODS_PATH := "res://mods"
const EXTERNAL_MODS_FOLDER := "mods"

var mods: Array[Dictionary] = []
var _saved_enabled_state: Dictionary = {}


func load_mods() -> void:
	mods.clear()
	_saved_enabled_state = _load_saved_state()

	var discovered_paths: Dictionary = {}
	for root_path in _get_scan_roots():
		_collect_mods_from_path(root_path, discovered_paths)

	var mod_ids: Array[String] = []
	for mod_id in discovered_paths.keys():
		mod_ids.append(String(mod_id))
	mod_ids.sort()

	for mod_id in mod_ids:
		var mod_path := String(discovered_paths[mod_id])
		var parsed_mod := _read_mod_file(mod_path)
		if parsed_mod.is_empty():
			continue

		var resolved_id := String(parsed_mod.get("id", mod_id)).strip_edges()
		if resolved_id.is_empty():
			resolved_id = mod_id

		var enabled := bool(parsed_mod.get("enabled", false))
		if _saved_enabled_state.has(resolved_id):
			enabled = bool(_saved_enabled_state[resolved_id])

		mods.append(
			{
				"id": resolved_id,
				"name": String(parsed_mod.get("name", resolved_id.capitalize())),
				"description": String(parsed_mod.get("description", "")),
				"enabled": enabled,
				"path": mod_path,
				"blocks": parsed_mod.get("blocks", []),
				"world": parsed_mod.get("world", {}),
			}
		)

	_save_state()


func get_mod_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	for mod in mods:
		descriptors.append(
			{
				"id": String(mod.get("id", "")),
				"name": String(mod.get("name", "")),
				"description": String(mod.get("description", "")),
				"enabled": bool(mod.get("enabled", false)),
			}
		)
	return descriptors


func get_enabled_block_definitions() -> Array[Dictionary]:
	var block_entries: Array[Dictionary] = []
	for mod in mods:
		if not bool(mod.get("enabled", false)):
			continue
		for entry in mod.get("blocks", []):
			if entry is Dictionary:
				block_entries.append((entry as Dictionary).duplicate(true))
	return block_entries


func get_enabled_mod_ids() -> Array[String]:
	var enabled_ids: Array[String] = []
	for mod in mods:
		if bool(mod.get("enabled", false)):
			enabled_ids.append(String(mod.get("id", "")))
	return enabled_ids


func get_enabled_world_settings() -> Dictionary:
	var merged := {
		"chunk_load_radius": 2,
		"chunk_unload_radius": 3,
		"max_height": 42,
		"water_level": 8,
		"terrain_height_bonus": 0.0,
		"terrain_ridge_strength": 1.0,
		"tree_density_multiplier": 1.0,
		"rock_density_multiplier": 1.0,
		"grass_density_multiplier": 1.0,
		"ambient_light_bonus": 0.0,
		"fog_density_multiplier": 1.0,
	}

	for mod in mods:
		if not bool(mod.get("enabled", false)):
			continue

		var world_settings: Dictionary = mod.get("world", {})
		for key in world_settings.keys():
			var value = world_settings[key]
			if merged.has(key):
				var current_value = merged[key]
				if current_value is float or current_value is int:
					if String(key).ends_with("_multiplier"):
						merged[key] = float(current_value) * float(value)
					elif String(key).ends_with("_bonus") or String(key).ends_with("_offset"):
						merged[key] = float(current_value) + float(value)
					else:
						merged[key] = value
				else:
					merged[key] = value
			else:
				merged[key] = value

	return merged


func toggle_mod(mod_id: String) -> void:
	for mod in mods:
		if String(mod.get("id", "")) != mod_id:
			continue
		mod["enabled"] = not bool(mod.get("enabled", false))
		break
	_save_state()


func set_enabled_mods(enabled_mod_ids: Array[String]) -> void:
	var enabled_lookup := {}
	for mod_id in enabled_mod_ids:
		enabled_lookup[String(mod_id)] = true

	for mod in mods:
		var mod_id := String(mod.get("id", ""))
		mod["enabled"] = enabled_lookup.has(mod_id)

	_save_state()


func is_mod_enabled(mod_id: String) -> bool:
	for mod in mods:
		if String(mod.get("id", "")) == mod_id:
			return bool(mod.get("enabled", false))
	return false


func _get_scan_roots() -> Array[String]:
	var roots: Array[String] = []
	var executable_mods := OS.get_executable_path().get_base_dir().path_join(EXTERNAL_MODS_FOLDER)
	var user_mods := ProjectSettings.globalize_path("user://mods")

	for candidate in [PACKED_MODS_PATH, executable_mods, user_mods]:
		if candidate.is_empty():
			continue
		if roots.has(candidate):
			continue
		roots.append(candidate)

	_ensure_directory_exists(executable_mods)
	_ensure_directory_exists(user_mods)
	return roots


func _collect_mods_from_path(root_path: String, discovered_paths: Dictionary) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var entry_path := root_path.path_join(entry_name)
		if dir.current_is_dir():
			var mod_file_path := entry_path.path_join("mod.json")
			if FileAccess.file_exists(mod_file_path):
				discovered_paths[entry_name.to_lower()] = mod_file_path
			continue

		if entry_name.to_lower() == "mod.json":
			discovered_paths[root_path.get_file().to_lower()] = entry_path
	dir.list_dir_end()


func _read_mod_file(mod_path: String) -> Dictionary:
	if not FileAccess.file_exists(mod_path):
		return {}

	var file := FileAccess.open(mod_path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _load_saved_state() -> Dictionary:
	var config := ConfigFile.new()
	var error := config.load(USER_STATE_PATH)
	if error != OK:
		return {}
	return config.get_value("mods", "enabled_state", {})


func _save_state() -> void:
	var enabled_state := {}
	for mod in mods:
		enabled_state[String(mod.get("id", ""))] = bool(mod.get("enabled", false))

	var config := ConfigFile.new()
	config.set_value("mods", "enabled_state", enabled_state)
	config.save(USER_STATE_PATH)


func _ensure_directory_exists(target_path: String) -> void:
	if target_path.is_empty():
		return
	if DirAccess.dir_exists_absolute(target_path):
		return
	DirAccess.make_dir_recursive_absolute(target_path)
