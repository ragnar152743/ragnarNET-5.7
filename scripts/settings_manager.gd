extends RefCounted
class_name SettingsManager

const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {
	"graphics_preset": "auto",
	"auto_fallback": true,
	"github_repo": "",
	"player_name": "",
}
const GRAPHICS_PRESET_ORDER := ["auto", "8k", "4k", "2k", "1080p", "low"]

var _settings: Dictionary = {}


func load_settings() -> Dictionary:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return _settings.duplicate(true)

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return _settings.duplicate(true)

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_settings.merge(parsed, true)
	_settings["graphics_preset"] = normalize_graphics_preset(String(_settings.get("graphics_preset", "auto")))
	_settings["auto_fallback"] = bool(_settings.get("auto_fallback", true))
	_settings["github_repo"] = normalize_repo_slug(String(_settings.get("github_repo", "")))
	_settings["player_name"] = normalize_player_name(String(_settings.get("player_name", "")))
	return _settings.duplicate(true)


func get_settings() -> Dictionary:
	if _settings.is_empty():
		return load_settings()
	return _settings.duplicate(true)


func save_settings(next_settings: Dictionary) -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	_settings.merge(next_settings, true)
	_settings["graphics_preset"] = normalize_graphics_preset(String(_settings.get("graphics_preset", "auto")))
	_settings["auto_fallback"] = bool(_settings.get("auto_fallback", true))
	_settings["github_repo"] = normalize_repo_slug(String(_settings.get("github_repo", "")))
	_settings["player_name"] = normalize_player_name(String(_settings.get("player_name", "")))

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_settings, "\t"))


func normalize_graphics_preset(preset: String) -> String:
	var normalized := preset.strip_edges().to_lower()
	if GRAPHICS_PRESET_ORDER.has(normalized):
		return normalized
	return "auto"


func get_preset_index(preset: String) -> int:
	return GRAPHICS_PRESET_ORDER.find(normalize_graphics_preset(preset))


func get_next_lower_preset(preset: String) -> String:
	var normalized := normalize_graphics_preset(preset)
	var index := get_preset_index(normalized)
	if index < 0:
		return "low"
	if normalized == "auto":
		return "2k"
	return GRAPHICS_PRESET_ORDER[min(index + 1, GRAPHICS_PRESET_ORDER.size() - 1)]


func get_preset_label(preset: String) -> String:
	match normalize_graphics_preset(preset):
		"auto":
			return "Auto"
		"8k":
			return "8K"
		"4k":
			return "4K"
		"2k":
			return "2K"
		"1080p":
			return "1080p"
		"low":
			return "Low"
	return "Auto"


func normalize_repo_slug(repo_slug: String) -> String:
	var normalized := repo_slug.strip_edges()
	while normalized.begins_with("/"):
		normalized = normalized.trim_prefix("/")
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	return normalized


func normalize_player_name(player_name: String) -> String:
	var normalized := player_name.strip_edges()
	if normalized.is_empty():
		normalized = OS.get_environment("USERNAME").strip_edges()
	if normalized.is_empty():
		normalized = OS.get_environment("COMPUTERNAME").strip_edges()
	if normalized.is_empty():
		normalized = "Player"
	if normalized.length() > 24:
		normalized = normalized.substr(0, 24)
	return normalized


func get_preset_labels() -> Array[String]:
	var labels: Array[String] = []
	for preset in GRAPHICS_PRESET_ORDER:
		labels.append(get_preset_label(preset))
	return labels
