extends RefCounted
class_name LaunchSecurity

const CONTRACT_PATH := "res://security/launch_contract.json"
const ARG_KEY_PREFIX := "--launcher-key="
const ARG_NONCE_PREFIX := "--launcher-nonce="
const ARG_TOKEN_PREFIX := "--launcher-token="
const ENV_LAUNCH_KEY := "VOXELRTX_LAUNCHER_KEY"
const ENV_LAUNCH_NONCE := "VOXELRTX_LAUNCHER_NONCE"
const ENV_LAUNCH_TOKEN := "VOXELRTX_LAUNCHER_TOKEN"
const FALLBACK_LAUNCHER_NAME := "VoxelRTXLauncher.exe"

static var _contract_cache: Dictionary = {}


static func validate_runtime_launch() -> Dictionary:
	if OS.has_feature("editor"):
		return {
			"authorized": true,
			"code": "",
			"message": "",
		}

	var contract := get_contract()
	var args := OS.get_cmdline_user_args()
	var launch_key := _sanitize_value(OS.get_environment(ENV_LAUNCH_KEY))
	var launch_nonce := _sanitize_value(OS.get_environment(ENV_LAUNCH_NONCE))
	var launch_token := _sanitize_value(OS.get_environment(ENV_LAUNCH_TOKEN))

	for arg_variant in args:
		var arg: String = String(arg_variant)
		if launch_key.is_empty() and arg.begins_with(ARG_KEY_PREFIX):
			launch_key = _sanitize_value(arg.trim_prefix(ARG_KEY_PREFIX))
		elif launch_nonce.is_empty() and arg.begins_with(ARG_NONCE_PREFIX):
			launch_nonce = _sanitize_value(arg.trim_prefix(ARG_NONCE_PREFIX))
		elif launch_token.is_empty() and arg.begins_with(ARG_TOKEN_PREFIX):
			launch_token = _sanitize_value(arg.trim_prefix(ARG_TOKEN_PREFIX))

	if launch_key.is_empty():
		return _failure(String(contract.get("error_missing_key", "GAME-AUTH-001")), "Launcher key missing.")

	if launch_key != String(contract.get("launch_key", "")):
		return _failure(String(contract.get("error_invalid_key", "GAME-AUTH-002")), "Launcher key invalid.")

	if launch_nonce.is_empty():
		return _failure(String(contract.get("error_missing_nonce", "GAME-AUTH-004")), "Launcher nonce missing.")

	var expected_token: String = build_session_token(launch_key, launch_nonce, String(contract.get("launch_salt", "")))
	if launch_token.is_empty() or launch_token != expected_token:
		return _failure(String(contract.get("error_invalid_token", "GAME-AUTH-003")), "Launcher token invalid.")

	return {
		"authorized": true,
		"code": "",
		"message": "",
	}


static func build_session_token(launch_key: String, launch_nonce: String, launch_salt: String = "") -> String:
	var salt := launch_salt
	if salt.is_empty():
		salt = String(get_contract().get("launch_salt", "VoxelRTXStudio.Security.v1"))

	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s|%s|%s" % [launch_key, launch_nonce, salt]).to_utf8_buffer())
	return context.finish().hex_encode()


static func get_contract() -> Dictionary:
	if not _contract_cache.is_empty():
		return _contract_cache

	if not FileAccess.file_exists(CONTRACT_PATH):
		_contract_cache = {
			"product_name": "Voxel RTX Game",
			"game_executable": "VoxelRTXGame.exe",
			"launch_key": "",
			"launch_salt": "VoxelRTXStudio.Security.v1",
			"error_missing_key": "GAME-AUTH-001",
			"error_invalid_key": "GAME-AUTH-002",
			"error_invalid_token": "GAME-AUTH-003",
			"error_missing_nonce": "GAME-AUTH-004",
		}
		return _contract_cache

	var file := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if file == null:
		return get_contract()

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_contract_cache = (parsed as Dictionary).duplicate(true)
	else:
		_contract_cache = {}
	return _contract_cache


static func get_product_name() -> String:
	return String(get_contract().get("product_name", "Voxel RTX Game"))


static func get_game_executable_name() -> String:
	return String(get_contract().get("game_executable", "VoxelRTXGame.exe"))


static func try_open_launcher() -> bool:
	if OS.has_feature("editor"):
		return false

	var launcher_path := _resolve_launcher_path()
	if launcher_path.is_empty():
		return false

	var current_path := OS.get_executable_path().to_lower()
	if not current_path.is_empty() and launcher_path.to_lower() == current_path:
		return false

	var error: Error = OS.create_process(launcher_path, PackedStringArray(), false)
	if error == OK:
		return true

	return OS.shell_open(launcher_path) == OK


static func _failure(code: String, message: String) -> Dictionary:
	return {
		"authorized": false,
		"code": code,
		"message": message,
	}


static func _sanitize_value(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.length() >= 2 and sanitized.begins_with("\"") and sanitized.ends_with("\""):
		sanitized = sanitized.substr(1, sanitized.length() - 2)
	return sanitized


static func _resolve_launcher_path() -> String:
	var candidates: PackedStringArray = []
	var current_executable := OS.get_executable_path()
	if not current_executable.is_empty():
		candidates.append(current_executable.get_base_dir().path_join(FALLBACK_LAUNCHER_NAME))

	var local_app_data := OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		candidates.append(local_app_data.path_join("Programs").path_join("VoxelRTX").path_join(FALLBACK_LAUNCHER_NAME))

	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate

	return ""
