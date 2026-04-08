extends Node
class_name GitHubUpdater

signal check_completed(success: bool, payload: Dictionary)
signal download_progress(progress: float, status: String)
signal download_completed(success: bool, payload: Dictionary)

const API_TEMPLATE := "https://api.github.com/repos/%s/releases/latest"
const USER_AGENT := "VoxelRTXStudioLauncher/1.0"
const UPDATE_DIR := "user://updates"

var current_version := "1.0.0"
var current_repo := ""
var latest_release: Dictionary = {}
var latest_asset: Dictionary = {}
var pending_download_path := ""

var _metadata_request: HTTPRequest
var _download_request: HTTPRequest


func _ready() -> void:
	_metadata_request = HTTPRequest.new()
	_metadata_request.timeout = 15.0
	_metadata_request.request_completed.connect(_on_metadata_request_completed)
	add_child(_metadata_request)

	_download_request = HTTPRequest.new()
	_download_request.timeout = 0.0
	_download_request.use_threads = true
	_download_request.request_completed.connect(_on_download_request_completed)
	add_child(_download_request)


func configure(version: String, repo_slug: String) -> void:
	current_version = _normalize_version(version)
	current_repo = normalize_repo_slug(repo_slug)


func check_for_updates(repo_slug: String = "", version: String = "") -> void:
	if not version.is_empty():
		current_version = _normalize_version(version)
	if not repo_slug.is_empty():
		current_repo = normalize_repo_slug(repo_slug)

	latest_release.clear()
	latest_asset.clear()
	pending_download_path = ""

	if current_repo.is_empty():
		check_completed.emit(
			false,
			{
				"status": "No GitHub repository configured.",
				"summary": "Set a repository in owner/repo format to enable launcher updates.",
				"repo": current_repo,
			}
		)
		return

	var headers := PackedStringArray(
		[
			"User-Agent: %s" % USER_AGENT,
			"Accept: application/vnd.github+json",
			"X-GitHub-Api-Version: 2022-11-28",
		]
	)
	var error: Error = _metadata_request.request(API_TEMPLATE % current_repo, headers)
	if error != OK:
		check_completed.emit(
			false,
			{
				"status": "GitHub check failed.",
				"summary": "Launcher could not start the GitHub API request.",
				"repo": current_repo,
			}
		)


func download_latest_release() -> void:
	if latest_release.is_empty() or latest_asset.is_empty():
		download_completed.emit(
			false,
			{
				"status": "No downloadable update.",
				"summary": "Check GitHub releases first.",
			}
		)
		return

	var asset_name := String(latest_asset.get("name", "VoxelRTXGame.exe"))
	var asset_url := String(latest_asset.get("browser_download_url", ""))
	if asset_url.is_empty():
		download_completed.emit(
			false,
			{
				"status": "Release asset is invalid.",
				"summary": "Latest GitHub release does not expose a browser download URL.",
			}
		)
		return

	var absolute_update_dir := ProjectSettings.globalize_path(UPDATE_DIR)
	if not DirAccess.dir_exists_absolute(absolute_update_dir):
		DirAccess.make_dir_recursive_absolute(absolute_update_dir)

	var user_target_path := "%s/%s" % [UPDATE_DIR, asset_name]
	var absolute_target_path := ProjectSettings.globalize_path(user_target_path)
	if FileAccess.file_exists(user_target_path):
		DirAccess.remove_absolute(absolute_target_path)

	_download_request.download_file = absolute_target_path
	var headers := PackedStringArray(
		[
			"User-Agent: %s" % USER_AGENT,
			"Accept: application/octet-stream",
		]
	)
	var error: Error = _download_request.request(asset_url, headers)
	if error != OK:
		download_completed.emit(
			false,
			{
				"status": "Download failed to start.",
				"summary": "Launcher could not open the GitHub asset download.",
			}
		)
		return

	pending_download_path = user_target_path
	download_progress.emit(0.0, "Downloading %s..." % asset_name)


func has_pending_download() -> bool:
	return not pending_download_path.is_empty() and FileAccess.file_exists(pending_download_path)


func prepare_install() -> Dictionary:
	if not has_pending_download():
		return {
			"success": false,
			"message": "No downloaded update is ready to install.",
		}

	if OS.has_feature("editor"):
		return {
			"success": false,
			"message": "Self-update is only available from the exported launcher build.",
		}

	var target_path := OS.get_executable_path()
	if target_path.is_empty():
		return {
			"success": false,
			"message": "Launcher could not resolve the current executable path.",
		}

	var source_path := ProjectSettings.globalize_path(pending_download_path)
	var source_extension := source_path.get_extension().to_lower()
	if source_extension != "exe":
		return {
			"success": false,
			"message": "Launcher currently expects a .exe asset in the latest GitHub release.",
		}

	var script_user_path := "%s/apply_update.bat" % UPDATE_DIR
	var script_absolute_path := ProjectSettings.globalize_path(script_user_path)
	var file := FileAccess.open(script_user_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"message": "Launcher could not write the updater script.",
		}

	file.store_string(_build_update_script(source_path, target_path))
	file.close()

	var error: Error = OS.create_process("cmd.exe", PackedStringArray(["/c", script_absolute_path]), false)
	if error != OK:
		return {
			"success": false,
			"message": "Launcher could not start the updater process.",
		}

	return {
		"success": true,
		"message": "Update prepared. The launcher will close, replace the executable, then restart.",
	}


func get_latest_release_summary() -> Dictionary:
	return {
		"repo": current_repo,
		"current_version": current_version,
		"latest_version": String(latest_release.get("tag_name", "")),
		"asset_name": String(latest_asset.get("name", "")),
		"download_ready": has_pending_download(),
	}


static func normalize_repo_slug(repo_slug: String) -> String:
	var normalized := repo_slug.strip_edges()
	while normalized.begins_with("/"):
		normalized = normalized.trim_prefix("/")
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	return normalized


func _on_metadata_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		check_completed.emit(
			false,
			{
				"status": "GitHub check failed.",
				"summary": "Latest release metadata could not be fetched from GitHub.",
				"repo": current_repo,
			}
		)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is not Dictionary:
		check_completed.emit(
			false,
			{
				"status": "GitHub response is invalid.",
				"summary": "Latest release metadata could not be parsed.",
				"repo": current_repo,
			}
		)
		return

	latest_release = (parsed as Dictionary).duplicate(true)
	latest_asset = _select_release_asset(latest_release)

	if latest_asset.is_empty():
		check_completed.emit(
			false,
			{
				"status": "Latest release has no installable asset.",
				"summary": "Upload a Windows .exe asset for launcher delivery.",
				"repo": current_repo,
				"latest_version": String(latest_release.get("tag_name", "")),
				"notes": _sanitize_release_notes(String(latest_release.get("body", ""))),
			}
		)
		return

	var latest_tag := _normalize_version(String(latest_release.get("tag_name", "")))
	var update_available := _is_version_newer(latest_tag, current_version)
	var asset_name := String(latest_asset.get("name", ""))
	var summary := "Installed: %s  |  Latest: %s  |  Asset: %s" % [current_version, latest_tag, asset_name]

	check_completed.emit(
		true,
		{
			"status": "Update available." if update_available else "Launcher is up to date.",
			"summary": summary,
			"repo": current_repo,
			"current_version": current_version,
			"latest_version": latest_tag,
			"notes": _sanitize_release_notes(String(latest_release.get("body", ""))),
			"update_available": update_available,
			"asset_name": asset_name,
		}
	)


func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or not has_pending_download():
		pending_download_path = ""
		download_completed.emit(
			false,
			{
				"status": "Download failed.",
				"summary": "Launcher could not download the update asset from GitHub.",
			}
		)
		return

	download_progress.emit(1.0, "Download complete. Ready to install on restart.")
	download_completed.emit(
		true,
		{
			"status": "Update downloaded.",
			"summary": "The launcher can install %s on the next restart." % String(latest_asset.get("name", "update")),
			"latest_version": _normalize_version(String(latest_release.get("tag_name", ""))),
			"download_path": pending_download_path,
		}
	)


func _select_release_asset(release: Dictionary) -> Dictionary:
	var assets_variant = release.get("assets", [])
	if assets_variant is not Array:
		return {}

	var assets: Array = assets_variant
	var current_executable_name := ""
	var executable_path := OS.get_executable_path()
	if not executable_path.is_empty():
		current_executable_name = executable_path.get_file().to_lower()

	for asset_variant in assets:
		if asset_variant is Dictionary:
			var asset: Dictionary = asset_variant
			var asset_name := String(asset.get("name", "")).to_lower()
			if not current_executable_name.is_empty() and asset_name == current_executable_name:
				return asset.duplicate(true)

	for asset_variant in assets:
		if asset_variant is Dictionary:
			var asset: Dictionary = asset_variant
			var asset_name := String(asset.get("name", "")).to_lower()
			if asset_name.ends_with(".exe"):
				return asset.duplicate(true)

	return {}


func _normalize_version(version: String) -> String:
	var normalized := version.strip_edges()
	if normalized.begins_with("v") or normalized.begins_with("V"):
		normalized = normalized.substr(1)
	return normalized


func _sanitize_release_notes(notes: String) -> String:
	var cleaned := notes.strip_edges()
	if cleaned.is_empty():
		return "No release notes were attached to the latest GitHub release."
	if cleaned.length() > 520:
		return "%s..." % cleaned.substr(0, 520)
	return cleaned


func _is_version_newer(candidate: String, current: String) -> bool:
	var candidate_parts: PackedInt32Array = _extract_version_parts(candidate)
	var current_parts: PackedInt32Array = _extract_version_parts(current)
	var longest: int = maxi(candidate_parts.size(), current_parts.size())

	for index in range(longest):
		var candidate_part: int = candidate_parts[index] if index < candidate_parts.size() else 0
		var current_part: int = current_parts[index] if index < current_parts.size() else 0
		if candidate_part > current_part:
			return true
		if candidate_part < current_part:
			return false

	return candidate != current and not candidate.is_empty()


func _extract_version_parts(version: String) -> PackedInt32Array:
	var parts := PackedInt32Array()
	var current_digits := ""
	for character in version:
		if character >= "0" and character <= "9":
			current_digits += character
		elif not current_digits.is_empty():
			parts.append(int(current_digits))
			current_digits = ""

	if not current_digits.is_empty():
		parts.append(int(current_digits))

	if parts.is_empty():
		parts.append(0)
	return parts


func _build_update_script(source_path: String, target_path: String) -> String:
	var executable_name := target_path.get_file()
	return "@echo off\r\n" \
		+ "setlocal\r\n" \
		+ "set \"SOURCE=%s\"\r\n" % source_path \
		+ "set \"TARGET=%s\"\r\n" % target_path \
		+ "set \"EXENAME=%s\"\r\n" % executable_name \
		+ ":waitloop\r\n" \
		+ "tasklist /FI \"IMAGENAME eq %EXENAME%\" | find /I \"%EXENAME%\" >nul\r\n" \
		+ "if not errorlevel 1 (\r\n" \
		+ "\ttimeout /t 1 /nobreak >nul\r\n" \
		+ "\tgoto waitloop\r\n" \
		+ ")\r\n" \
		+ "copy /Y \"%SOURCE%\" \"%TARGET%\" >nul\r\n" \
		+ "start \"\" \"%TARGET%\"\r\n" \
		+ "exit /b 0\r\n"
