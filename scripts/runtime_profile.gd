extends RefCounted
class_name RuntimeProfile

var _cached_profile: Dictionary = {}
const PRESET_TO_TIER := {
	"8k": "ultra",
	"4k": "high",
	"2k": "balanced",
	"1080p": "full_hd",
	"low": "low",
}


func get_profile() -> Dictionary:
	if _cached_profile.is_empty():
		_cached_profile = _probe_profile()
	return _cached_profile.duplicate(true)


func build_profile(graphics_preset: String = "auto") -> Dictionary:
	var profile := get_profile()
	return _apply_graphics_preset(profile, graphics_preset)


func _probe_profile() -> Dictionary:
	var cpu_count: int = max(2, OS.get_processor_count())
	var system_ram_mb := 8192
	var free_ram_mb := 4096
	var gpu_vram_mb := 3072

	var windows_probe := _probe_windows_hardware()
	if not windows_probe.is_empty():
		system_ram_mb = int(windows_probe.get("system_ram_mb", system_ram_mb))
		free_ram_mb = int(windows_probe.get("free_ram_mb", free_ram_mb))
		gpu_vram_mb = int(windows_probe.get("gpu_vram_mb", gpu_vram_mb))

	var streaming_budget_mb := clampi(int(system_ram_mb * 0.5), 1536, max(1536, system_ram_mb - 2048))
	var texture_quality_tier := "balanced"
	if system_ram_mb >= 16384 and free_ram_mb >= 8192 and gpu_vram_mb >= 6144:
		texture_quality_tier = "ultra"
	elif system_ram_mb >= 12288 and gpu_vram_mb >= 4096:
		texture_quality_tier = "high"

	var chunk_load_radius := 2
	if streaming_budget_mb >= 8192 and cpu_count >= 8:
		chunk_load_radius = 4
	elif streaming_budget_mb >= 6144 and cpu_count >= 8:
		chunk_load_radius = 3

	var prop_load_radius: int = 1 if texture_quality_tier == "balanced" else min(chunk_load_radius, 2)
	var collision_load_radius: int = 1 if cpu_count < 8 else min(2, chunk_load_radius)
	var initial_immediate_chunk_loads := 6 if texture_quality_tier == "balanced" else 10
	var chunk_loads_per_frame := clampi(int(round(cpu_count / 3.0)), 2, 5)
	var chunk_rebuilds_per_frame := clampi(int(round(cpu_count / 4.0)), 2, 5)
	var prop_builds_per_frame := 1 if texture_quality_tier == "balanced" else 2 if texture_quality_tier == "high" else 3
	var chunk_unloads_per_frame := clampi(int(round(cpu_count / 2.0)), 3, 6)
	var column_cache_limit := clampi(streaming_budget_mb * 18, 28000, 180000)
	var chunk_unload_radius := chunk_load_radius + 2
	var shadow_distance := 130.0 if texture_quality_tier == "balanced" else 180.0 if texture_quality_tier == "high" else 220.0
	var rain_particles := 220 if texture_quality_tier == "balanced" else 420 if texture_quality_tier == "high" else 560
	var enable_sdfgi := gpu_vram_mb >= 3072 and system_ram_mb >= 12288
	var enable_ssil := gpu_vram_mb >= 3072
	var enable_ssao := true

	return {
		"cpu_count": cpu_count,
		"system_ram_mb": system_ram_mb,
		"free_ram_mb": free_ram_mb,
		"gpu_vram_mb": gpu_vram_mb,
		"streaming_budget_mb": streaming_budget_mb,
		"texture_quality_tier": texture_quality_tier,
		"chunk_load_radius": chunk_load_radius,
		"chunk_unload_radius": chunk_unload_radius,
		"prop_load_radius": prop_load_radius,
		"collision_load_radius": collision_load_radius,
		"initial_immediate_chunk_loads": initial_immediate_chunk_loads,
		"chunk_loads_per_frame": chunk_loads_per_frame,
		"chunk_rebuilds_per_frame": chunk_rebuilds_per_frame,
		"prop_chunk_builds_per_frame": prop_builds_per_frame,
		"chunk_unloads_per_frame": chunk_unloads_per_frame,
		"column_cache_limit": column_cache_limit,
		"shadow_distance": shadow_distance,
		"rain_particles": rain_particles,
		"enable_ssao": enable_ssao,
		"enable_ssil": enable_ssil,
		"enable_sdfgi": enable_sdfgi,
	}


func _apply_graphics_preset(profile: Dictionary, graphics_preset: String) -> Dictionary:
	var normalized_preset := graphics_preset.strip_edges().to_lower()
	if normalized_preset.is_empty() or normalized_preset == "auto":
		return profile

	var tier := String(PRESET_TO_TIER.get(normalized_preset, profile.get("texture_quality_tier", "balanced")))
	profile["texture_quality_tier"] = tier

	match normalized_preset:
		"8k":
			profile["chunk_load_radius"] = max(int(profile.get("chunk_load_radius", 3)), 3)
			profile["chunk_unload_radius"] = max(int(profile.get("chunk_unload_radius", 5)), int(profile["chunk_load_radius"]) + 2)
			profile["prop_load_radius"] = max(int(profile.get("prop_load_radius", 2)), 2)
			profile["shadow_distance"] = 220.0
			profile["enable_ssao"] = true
			profile["enable_ssil"] = true
			profile["enable_sdfgi"] = true
			profile["rain_particles"] = 560
		"4k":
			profile["chunk_load_radius"] = clampi(int(profile.get("chunk_load_radius", 3)), 2, 3)
			profile["chunk_unload_radius"] = max(int(profile.get("chunk_unload_radius", 4)), int(profile["chunk_load_radius"]) + 2)
			profile["prop_load_radius"] = min(int(profile.get("prop_load_radius", 2)), 2)
			profile["shadow_distance"] = 180.0
			profile["enable_ssao"] = true
			profile["enable_ssil"] = true
			profile["enable_sdfgi"] = int(profile.get("gpu_vram_mb", 0)) >= 4096
			profile["rain_particles"] = 420
		"2k":
			profile["chunk_load_radius"] = 2
			profile["chunk_unload_radius"] = 4
			profile["prop_load_radius"] = 1
			profile["shadow_distance"] = 140.0
			profile["enable_ssao"] = true
			profile["enable_ssil"] = false
			profile["enable_sdfgi"] = false
			profile["rain_particles"] = 240
		"1080p":
			profile["chunk_load_radius"] = 2
			profile["chunk_unload_radius"] = 4
			profile["prop_load_radius"] = 1
			profile["collision_load_radius"] = 1
			profile["initial_immediate_chunk_loads"] = 6
			profile["chunk_loads_per_frame"] = 2
			profile["chunk_rebuilds_per_frame"] = 2
			profile["shadow_distance"] = 110.0
			profile["enable_ssao"] = true
			profile["enable_ssil"] = false
			profile["enable_sdfgi"] = false
			profile["rain_particles"] = 160
		"low":
			profile["chunk_load_radius"] = 1
			profile["chunk_unload_radius"] = 3
			profile["prop_load_radius"] = 1
			profile["collision_load_radius"] = 1
			profile["initial_immediate_chunk_loads"] = 4
			profile["chunk_loads_per_frame"] = 2
			profile["chunk_rebuilds_per_frame"] = 1
			profile["prop_chunk_builds_per_frame"] = 1
			profile["shadow_distance"] = 85.0
			profile["enable_ssao"] = false
			profile["enable_ssil"] = false
			profile["enable_sdfgi"] = false
			profile["rain_particles"] = 80

	profile["column_cache_limit"] = max(int(profile.get("column_cache_limit", 28000)), int(profile.get("streaming_budget_mb", 2048)) * 22)
	return profile


func _probe_windows_hardware() -> Dictionary:
	if OS.get_name() != "Windows":
		return {}

	var output: Array = []
	var command := "$os = Get-CimInstance Win32_OperatingSystem; $gpu = Get-CimInstance Win32_VideoController | Sort-Object AdapterRAM -Descending | Select-Object -First 1; [pscustomobject]@{system_ram_mb=[math]::Round([int64]$os.TotalVisibleMemorySize / 1024); free_ram_mb=[math]::Round([int64]$os.FreePhysicalMemory / 1024); gpu_vram_mb=[math]::Round([int64]$gpu.AdapterRAM / 1MB)} | ConvertTo-Json -Compress"
	var exit_code := OS.execute("powershell", PackedStringArray(["-NoProfile", "-Command", command]), output, true, false)
	if exit_code != 0 or output.is_empty():
		return {}

	var payload := "\n".join(output)
	var parsed = JSON.parse_string(payload)
	if parsed is Dictionary:
		return parsed
	return {}
