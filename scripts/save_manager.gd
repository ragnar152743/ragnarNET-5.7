extends RefCounted
class_name SaveManager

const SAVE_ROOT := "user://saves"
const SLOT_COUNT := 4


func list_slots() -> Array[Dictionary]:
	_ensure_save_root()
	var slots: Array[Dictionary] = []
	for slot_id in range(1, SLOT_COUNT + 1):
		var slot_data := load_slot(slot_id)
		if slot_data.is_empty():
			slots.append(
				{
					"slot_id": slot_id,
					"exists": false,
					"title": "World %s" % slot_id,
					"subtitle": "Empty slot",
					"details": "Create a new saved world in this slot.",
				}
			)
			continue

		var meta: Dictionary = slot_data.get("meta", {})
		var world_data: Dictionary = slot_data.get("world", {})
		var block_changes := int(meta.get("modified_block_count", (world_data.get("modified_blocks", []) as Array).size()))
		var details := "Seed %s  |  %s edits  |  %s mods" % [
			int(world_data.get("seed", 0)),
			block_changes,
			(meta.get("enabled_mod_ids", []) as Array).size(),
		]
		slots.append(
			{
				"slot_id": slot_id,
				"exists": true,
				"title": String(meta.get("title", "World %s" % slot_id)),
				"subtitle": String(meta.get("updated_at", "Saved world")),
				"details": details,
			}
		)
	return slots


func load_slot(slot_id: int) -> Dictionary:
	var path := _get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func save_slot(slot_id: int, save_data: Dictionary) -> bool:
	if slot_id < 1 or slot_id > SLOT_COUNT:
		return false

	_ensure_save_root()
	var path := _get_slot_path(slot_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	return true


func delete_slot(slot_id: int) -> void:
	var absolute_path := ProjectSettings.globalize_path(_get_slot_path(slot_id))
	if FileAccess.file_exists(_get_slot_path(slot_id)):
		DirAccess.remove_absolute(absolute_path)


func _ensure_save_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(SAVE_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		return
	DirAccess.make_dir_recursive_absolute(absolute_root)


func _get_slot_path(slot_id: int) -> String:
	return "%s/slot_%s.json" % [SAVE_ROOT, slot_id]
