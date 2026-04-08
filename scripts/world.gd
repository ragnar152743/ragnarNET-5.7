extends Node3D
class_name VoxelWorld

const VoxelChunkScript = preload("res://scripts/voxel_chunk.gd")
const DayNightCycleScript = preload("res://scripts/day_night_cycle.gd")

const TREE_SCENE = preload("res://scenes/props/Tree.tscn")
const ROCK_SCENE = preload("res://scenes/props/RockCluster.tscn")
const GRASS_SCENE = preload("res://scenes/props/GrassPatch.tscn")
const TREASURE_CHEST_SCENE = preload("res://scenes/props/TreasureChest.tscn")
const WOODEN_CRATE_SCENE = preload("res://scenes/props/WoodenCrate.tscn")
const TOOL_CHEST_SCENE = preload("res://scenes/props/ToolChest.tscn")
const TREE_STUMP_SCENE = preload("res://scenes/props/TreeStump.tscn")
const SHRUB_SCENE = preload("res://scenes/props/Shrub.tscn")
const WATER_SHADER = preload("res://materials/water.gdshader")

const CHUNK_SIZE := 16
const DEFAULT_MAX_HEIGHT := 42
const DEFAULT_WATER_LEVEL := 8
const DEFAULT_CHUNK_LOAD_RADIUS := 2
const DEFAULT_CHUNK_UNLOAD_RADIUS := 3
const DEFAULT_COLLISION_LOAD_RADIUS := 1
const KILL_PLANE_Y := -28.0
const SPAWN_CLEARANCE_RADIUS := 0.42
const SPAWN_CLEARANCE_HEIGHT := 1.9
const DEFAULT_INITIAL_IMMEDIATE_CHUNK_LOADS := 9
const DEFAULT_MAX_CHUNK_LOADS_PER_FRAME := 2
const DEFAULT_MAX_CHUNK_REBUILDS_PER_FRAME := 2
const DEFAULT_MAX_PROP_CHUNK_BUILDS_PER_FRAME := 1
const DEFAULT_MAX_CHUNK_UNLOADS_PER_FRAME := 3
const DEFAULT_CHUNK_REBUILD_VOXELS_PER_STEP := 2048
const DEFAULT_MAX_CHUNK_REBUILD_VOXELS_PER_STEP := 6144
const DEFAULT_BOOT_CHUNK_LOAD_RADIUS := 1
const DEFAULT_BOOT_PROP_LOAD_RADIUS := 0
const STREAMING_SAMPLE_WINDOW_SECONDS := 0.9
const STREAMING_LOW_FPS := 34.0
const STREAMING_MEDIUM_FPS := 52.0
const STREAMING_HIGH_FPS := 72.0
const DEFAULT_COLUMN_CACHE_LIMIT := 42000
const DEFAULT_RAIN_PARTICLE_AMOUNT := 320
const WEATHER_CHANGE_INTERVAL_MIN := 35.0
const WEATHER_CHANGE_INTERVAL_MAX := 85.0

var mod_loader: ModLoader
var auto_boot_world := true

var max_height := DEFAULT_MAX_HEIGHT
var water_level := DEFAULT_WATER_LEVEL
var chunk_load_radius := DEFAULT_CHUNK_LOAD_RADIUS
var chunk_unload_radius := DEFAULT_CHUNK_UNLOAD_RADIUS
var collision_load_radius := DEFAULT_COLLISION_LOAD_RADIUS
var prop_load_radius := 1
var initial_streaming_active := true
var initial_immediate_chunk_loads := DEFAULT_INITIAL_IMMEDIATE_CHUNK_LOADS
var max_chunk_loads_per_frame := DEFAULT_MAX_CHUNK_LOADS_PER_FRAME
var max_chunk_rebuilds_per_frame := DEFAULT_MAX_CHUNK_REBUILDS_PER_FRAME
var max_prop_chunk_builds_per_frame := DEFAULT_MAX_PROP_CHUNK_BUILDS_PER_FRAME
var max_chunk_unloads_per_frame := DEFAULT_MAX_CHUNK_UNLOADS_PER_FRAME
var adaptive_chunk_loads_per_frame := 1
var adaptive_chunk_rebuilds_per_frame := 1
var adaptive_prop_chunk_builds_per_frame := 1
var adaptive_chunk_unloads_per_frame := 1
var max_chunk_rebuild_voxels_per_step := DEFAULT_MAX_CHUNK_REBUILD_VOXELS_PER_STEP
var adaptive_chunk_rebuild_voxels_per_step := DEFAULT_CHUNK_REBUILD_VOXELS_PER_STEP
var streaming_hardware_factor := 1.0
var streaming_average_fps := 60.0
var streaming_sample_time := 0.0
var streaming_sample_accumulator := 0.0
var streaming_sample_count := 0
var column_cache_limit := DEFAULT_COLUMN_CACHE_LIMIT
var runtime_profile: Dictionary = {}
var world_seed := 0
var world_settings: Dictionary = {}

var modified_blocks: Dictionary = {}
var removed_props: Dictionary = {}
var column_cache: Dictionary = {}
var chunks: Dictionary = {}
var prop_chunks: Dictionary = {}
var pending_chunk_loads: Array[Vector2i] = []
var pending_chunk_load_set: Dictionary = {}
var pending_chunk_unloads: Array[Vector2i] = []
var pending_chunk_unload_set: Dictionary = {}
var pending_chunk_rebuilds: Array[Vector2i] = []
var pending_chunk_rebuild_set: Dictionary = {}
var pending_prop_chunk_builds: Array[Vector2i] = []
var pending_prop_chunk_build_set: Dictionary = {}

var spawn_position := Vector3.ZERO
var spawn_cell := Vector2i.ZERO
var last_loaded_center := Vector2i(99999999, 99999999)
var last_effect_anchor := Vector2(99999999.0, 99999999.0)
var weather_timer := 0.0
var weather_rng := RandomNumberGenerator.new()
var weather_intensity := 0.0
var target_weather_intensity := 0.0
var storm_intensity := 0.0
var target_storm_intensity := 0.0
var lightning_flash := 0.0

var player_anchor: Node3D

var chunks_root: Node3D
var props_root: Node3D
var effects_root: Node3D
var water_mesh: MeshInstance3D
var dust_particles: GPUParticles3D
var rain_particles: GPUParticles3D
var environment_node: WorldEnvironment
var cycle: DayNightCycle

var warp_x_noise: FastNoiseLite
var warp_z_noise: FastNoiseLite
var continental_noise: FastNoiseLite
var hills_noise: FastNoiseLite
var peaks_noise: FastNoiseLite
var erosion_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var temperature_noise: FastNoiseLite
var tree_noise: FastNoiseLite
var rock_noise: FastNoiseLite
var grass_noise: FastNoiseLite


func configure(p_mod_loader: ModLoader) -> void:
	mod_loader = p_mod_loader


func apply_runtime_profile(profile: Dictionary) -> void:
	runtime_profile = profile.duplicate(true)


func refresh_graphics_profile() -> void:
	_apply_runtime_settings()
	_setup_water()
	_setup_weather_effects()
	_sync_loaded_chunks(true)
	for chunk_key_variant in chunks.keys():
		_queue_chunk_rebuild(chunk_key_variant)


func _ready() -> void:
	add_to_group("world")
	_build_structure()
	if auto_boot_world:
		reload_world(true)


func _process(delta: float) -> void:
	if continental_noise == null or warp_x_noise == null or warp_z_noise == null:
		return
	_sync_loaded_chunks()
	_update_streaming_adaptation(delta)
	_process_chunk_queues()
	_update_weather(delta)
	_update_following_effects()


func reload_world(generate_new_seed: bool = true) -> void:
	_build_structure()
	if generate_new_seed or world_seed == 0:
		world_seed = _generate_runtime_seed()

	_apply_runtime_settings()
	_initialize_noise()

	modified_blocks.clear()
	removed_props.clear()
	column_cache.clear()
	last_loaded_center = Vector2i(99999999, 99999999)
	last_effect_anchor = Vector2(99999999.0, 99999999.0)
	initial_streaming_active = true
	_reset_weather_state()
	_clear_chunk_queues()

	_clear_runtime_roots()
	_prepare_spawn_zone()
	_setup_water()
	_setup_particles()
	_setup_weather_effects()
	_setup_optional_ambience()
	_sync_loaded_chunks(true)


func load_from_save(save_state: Dictionary) -> void:
	_build_structure()
	world_seed = int(save_state.get("seed", _generate_runtime_seed()))
	_apply_runtime_settings()
	_initialize_noise()

	modified_blocks.clear()
	removed_props.clear()
	column_cache.clear()
	last_loaded_center = Vector2i(99999999, 99999999)
	last_effect_anchor = Vector2(99999999.0, 99999999.0)
	initial_streaming_active = true
	_reset_weather_state()
	_clear_chunk_queues()
	_clear_runtime_roots()

	for entry_variant in save_state.get("modified_blocks", []):
		if entry_variant is Array and (entry_variant as Array).size() >= 4:
			var entry: Array = entry_variant
			modified_blocks[Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))] = int(entry[3])

	for removed_key in save_state.get("removed_props", []):
		removed_props[String(removed_key)] = true

	var spawn_array: Array = save_state.get("spawn_position", [])
	if spawn_array.size() >= 3:
		spawn_position = Vector3(float(spawn_array[0]), float(spawn_array[1]), float(spawn_array[2]))
		spawn_cell = Vector2i(int(floor(spawn_position.x)), int(floor(spawn_position.z)))
	else:
		_prepare_spawn_zone()

	_setup_water()
	_setup_particles()
	_setup_weather_effects()
	_setup_optional_ambience()
	_sync_loaded_chunks(true)


func attach_player_anchor(p_player_anchor: Node3D) -> void:
	player_anchor = p_player_anchor
	_sync_loaded_chunks(true)
	_update_following_effects()


func finish_initial_streaming() -> void:
	if not initial_streaming_active:
		return
	initial_streaming_active = false
	last_loaded_center = Vector2i(99999999, 99999999)
	_sync_loaded_chunks(true)


func get_spawn_position() -> Vector3:
	return spawn_position


func get_kill_plane_y() -> float:
	return KILL_PLANE_Y


func get_save_state() -> Dictionary:
	var serialized_blocks: Array = []
	for cell_variant in modified_blocks.keys():
		var cell: Vector3i = cell_variant
		serialized_blocks.append([cell.x, cell.y, cell.z, int(modified_blocks[cell_variant])])

	var serialized_removed_props: Array = []
	for prop_key_variant in removed_props.keys():
		serialized_removed_props.append(String(prop_key_variant))

	return {
		"seed": world_seed,
		"spawn_position": [spawn_position.x, spawn_position.y, spawn_position.z],
		"modified_blocks": serialized_blocks,
		"removed_props": serialized_removed_props,
	}


func get_loading_progress() -> float:
	var focus_position := spawn_position if player_anchor == null else player_anchor.global_position
	var center_chunk := _world_position_to_chunk(focus_position)
	var required_chunks := _get_required_chunk_keys(center_chunk, _get_active_chunk_load_radius())
	var required_prop_chunks := _get_required_chunk_keys(center_chunk, _get_active_prop_load_radius())
	var loaded_count := 0
	for chunk_key in required_chunks:
		if chunks.has(chunk_key):
			loaded_count += 1
	var built_prop_count := 0
	for prop_chunk_key in required_prop_chunks:
		if prop_chunks.has(prop_chunk_key):
			built_prop_count += 1

	var terrain_progress := 1.0 if required_chunks.is_empty() else clampf(float(loaded_count) / float(required_chunks.size()), 0.0, 1.0)
	var prop_progress := 1.0 if required_prop_chunks.is_empty() else clampf(float(built_prop_count) / float(required_prop_chunks.size()), 0.0, 1.0)
	return clampf(terrain_progress * 0.8 + prop_progress * 0.2, 0.0, 1.0)


func is_initial_streaming_complete() -> bool:
	var focus_position := spawn_position if player_anchor == null else player_anchor.global_position
	var center_chunk := _world_position_to_chunk(focus_position)
	var required_chunks := _get_required_chunk_keys(center_chunk, _get_active_chunk_load_radius())
	var required_prop_chunks := _get_required_chunk_keys(center_chunk, _get_active_prop_load_radius())
	for chunk_key in required_chunks:
		if not chunks.has(chunk_key):
			return false
	for prop_chunk_key in required_prop_chunks:
		if not prop_chunks.has(prop_chunk_key):
			return false
	return not _has_pending_required_streaming_work(required_chunks, required_prop_chunks)


func get_available_block_ids() -> Array[int]:
	return BlockLibrary.get_placeable_block_ids()


func get_available_block_names() -> Array[String]:
	return BlockLibrary.get_hotbar_display_names()


func get_block(cell: Vector3i) -> int:
	if cell.y < 0:
		return BlockLibrary.STONE
	if cell.y >= max_height:
		return BlockLibrary.AIR
	if modified_blocks.has(cell):
		return int(modified_blocks[cell])

	var column := _get_column_data(Vector2i(cell.x, cell.z))
	var surface_height := int(column.get("height", water_level))
	if cell.y > surface_height:
		return BlockLibrary.AIR

	var base_block := _pick_block_for_height(
		cell.y,
		surface_height,
		int(column.get("steepness", 0)),
		float(column.get("moisture", 0.5)),
		float(column.get("temperature", 0.5))
	)
	return _decorate_generated_block(
		cell,
		base_block,
		surface_height,
		int(column.get("steepness", 0)),
		float(column.get("moisture", 0.5)),
		float(column.get("temperature", 0.5))
	)


func break_block(cell: Vector3i) -> Dictionary:
	if cell.y <= 0:
		return {}

	var block_id := get_block(cell)
	if block_id == BlockLibrary.AIR:
		return {}

	modified_blocks[cell] = BlockLibrary.AIR
	_queue_rebuild_for_cell(cell)
	spawn_block_break_effect(cell, block_id)

	return {
		"block_id": BlockLibrary.get_drop_block_id(block_id),
		"count": 1,
	}


func place_block(cell: Vector3i, block_id: int, player_position: Vector3) -> bool:
	if cell.y <= 0 or cell.y >= max_height:
		return false
	if not BlockLibrary.is_placeable(block_id):
		return false
	if get_block(cell) != BlockLibrary.AIR:
		return false
	if _would_intersect_player(cell, player_position):
		return false

	modified_blocks[cell] = block_id
	_queue_rebuild_for_cell(cell)
	return true


func pick_target(origin: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collision_mask = 3

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}

	var prop_owner := _extract_prop_owner(result.get("collider", null))
	if prop_owner != null:
		return {
			"kind": "prop",
			"prop": prop_owner,
			"display_name": String(prop_owner.call("get_interaction_name")),
		}

	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var cell := world_to_cell(hit_position - hit_normal * 0.05)
	if get_block(cell) == BlockLibrary.AIR:
		return {}

	return {
		"kind": "block",
		"cell": cell,
		"place_cell": world_to_cell(hit_position + hit_normal * 0.05),
		"display_name": BlockLibrary.get_display_name(get_block(cell)),
	}


func world_to_cell(world_position: Vector3) -> Vector3i:
	var local := world_position if chunks_root == null or not chunks_root.is_inside_tree() else chunks_root.to_local(world_position)
	return Vector3i(
		int(floor(local.x)),
		int(floor(local.y)),
		int(floor(local.z))
	)


func cell_to_world(cell: Vector3i) -> Vector3:
	var local := Vector3(cell.x + 0.5, cell.y + 0.5, cell.z + 0.5)
	return local if chunks_root == null or not chunks_root.is_inside_tree() else chunks_root.to_global(local)


func mark_prop_removed(prop_key: String) -> void:
	removed_props[prop_key] = true


func _build_structure() -> void:
	if chunks_root == null:
		chunks_root = Node3D.new()
		chunks_root.name = "Chunks"
		add_child(chunks_root)

	if props_root == null:
		props_root = Node3D.new()
		props_root.name = "Props"
		add_child(props_root)

	if effects_root == null:
		effects_root = Node3D.new()
		effects_root.name = "Effects"
		add_child(effects_root)

	if environment_node == null:
		environment_node = WorldEnvironment.new()
		environment_node.name = "WorldEnvironment"
		add_child(environment_node)

	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.56, 0.98)
	sky_material.sky_horizon_color = Color(0.99, 0.84, 0.62)
	sky_material.ground_horizon_color = Color(0.42, 0.34, 0.26)
	sky_material.ground_bottom_color = Color(0.19, 0.16, 0.14)
	sky_material.energy_multiplier = 1.56
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.52
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.12
	environment.ssr_enabled = true
	_try_set_property(environment, "ssr_max_steps", 96)
	_try_set_property(environment, "ssr_fade_in", 0.1)
	_try_set_property(environment, "ssr_fade_out", 2.2)
	environment.glow_enabled = true
	_try_set_property(environment, "glow_intensity", 0.14)
	_try_set_property(environment, "glow_strength", 0.82)
	_try_set_property(environment, "glow_bloom", 0.18)
	environment.fog_enabled = true
	environment.fog_density = 0.0038
	environment.fog_sun_scatter = 0.42
	environment.fog_light_color = Color(0.99, 0.88, 0.74)
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.009
	environment.volumetric_fog_albedo = Color(0.78, 0.82, 0.86)
	environment.volumetric_fog_emission = Color(0.22, 0.18, 0.14)
	_try_set_property(environment, "ssao_enabled", true)
	_try_set_property(environment, "ssao_radius", 1.6)
	_try_set_property(environment, "ssao_intensity", 1.45)
	_try_set_property(environment, "ssao_power", 1.7)
	_try_set_property(environment, "ssao_detail", 0.65)
	_try_set_property(environment, "ssao_sharpness", 0.96)
	_try_set_property(environment, "ssil_enabled", true)
	_try_set_property(environment, "ssil_radius", 4.2)
	_try_set_property(environment, "ssil_intensity", 1.55)
	_try_set_property(environment, "ssil_sharpness", 0.92)
	_try_set_property(environment, "sdfgi_enabled", true)
	_try_set_property(environment, "sdfgi_energy", 0.95)
	_try_set_property(environment, "sdfgi_use_occlusion", true)
	_try_set_property(environment, "sdfgi_read_sky_light", true)
	environment_node.environment = environment

	if cycle == null:
		cycle = DayNightCycleScript.new()
		add_child(cycle)
	cycle.configure(environment, sky_material)


func _apply_runtime_settings() -> void:
	world_settings = mod_loader.get_enabled_world_settings() if mod_loader != null else {}
	max_height = int(world_settings.get("max_height", DEFAULT_MAX_HEIGHT))
	water_level = int(world_settings.get("water_level", DEFAULT_WATER_LEVEL))
	chunk_load_radius = int(world_settings.get("chunk_load_radius", int(runtime_profile.get("chunk_load_radius", DEFAULT_CHUNK_LOAD_RADIUS))))
	chunk_unload_radius = max(chunk_load_radius + 1, int(world_settings.get("chunk_unload_radius", int(runtime_profile.get("chunk_unload_radius", chunk_load_radius + 1)))))
	collision_load_radius = clampi(int(world_settings.get("collision_load_radius", int(runtime_profile.get("collision_load_radius", DEFAULT_COLLISION_LOAD_RADIUS)))), 0, chunk_load_radius)
	prop_load_radius = max(1, min(chunk_load_radius, int(world_settings.get("prop_load_radius", int(runtime_profile.get("prop_load_radius", max(1, chunk_load_radius - 1)))))))
	initial_immediate_chunk_loads = 1
	max_chunk_loads_per_frame = max(1, int(runtime_profile.get("chunk_loads_per_frame", DEFAULT_MAX_CHUNK_LOADS_PER_FRAME)))
	max_chunk_rebuilds_per_frame = max(1, int(runtime_profile.get("chunk_rebuilds_per_frame", DEFAULT_MAX_CHUNK_REBUILDS_PER_FRAME)))
	max_prop_chunk_builds_per_frame = max(1, int(runtime_profile.get("prop_chunk_builds_per_frame", DEFAULT_MAX_PROP_CHUNK_BUILDS_PER_FRAME)))
	max_chunk_unloads_per_frame = max(1, int(runtime_profile.get("chunk_unloads_per_frame", DEFAULT_MAX_CHUNK_UNLOADS_PER_FRAME)))
	max_chunk_rebuild_voxels_per_step = max(DEFAULT_CHUNK_REBUILD_VOXELS_PER_STEP, int(runtime_profile.get("chunk_rebuild_voxels_per_step", DEFAULT_MAX_CHUNK_REBUILD_VOXELS_PER_STEP)))
	column_cache_limit = max(20000, int(runtime_profile.get("column_cache_limit", DEFAULT_COLUMN_CACHE_LIMIT)))
	streaming_hardware_factor = _compute_streaming_hardware_factor()
	_reset_streaming_adaptation()
	BlockLibrary.set_texture_quality_tier(String(runtime_profile.get("texture_quality_tier", "high")))

	if environment_node == null or environment_node.environment == null:
		return

	environment_node.environment.ambient_light_energy = 1.52 + float(world_settings.get("ambient_light_bonus", 0.0))
	environment_node.environment.fog_density = 0.0038 * float(world_settings.get("fog_density_multiplier", 1.0))
	_try_set_property(environment_node.environment, "ssao_enabled", bool(runtime_profile.get("enable_ssao", true)))
	_try_set_property(environment_node.environment, "ssil_enabled", bool(runtime_profile.get("enable_ssil", true)))
	_try_set_property(environment_node.environment, "sdfgi_enabled", bool(runtime_profile.get("enable_sdfgi", true)))
	if cycle != null:
		cycle.apply_render_profile(runtime_profile)


func _initialize_noise() -> void:
	warp_x_noise = FastNoiseLite.new()
	warp_x_noise.seed = world_seed + 7
	warp_x_noise.frequency = 0.025

	warp_z_noise = FastNoiseLite.new()
	warp_z_noise.seed = world_seed + 13
	warp_z_noise.frequency = 0.025

	continental_noise = FastNoiseLite.new()
	continental_noise.seed = world_seed + 29
	continental_noise.frequency = 0.0065

	hills_noise = FastNoiseLite.new()
	hills_noise.seed = world_seed + 53
	hills_noise.frequency = 0.032

	peaks_noise = FastNoiseLite.new()
	peaks_noise.seed = world_seed + 89
	peaks_noise.frequency = 0.014

	erosion_noise = FastNoiseLite.new()
	erosion_noise.seed = world_seed + 131
	erosion_noise.frequency = 0.06

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 173
	moisture_noise.frequency = 0.012

	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = world_seed + 211
	temperature_noise.frequency = 0.01

	tree_noise = FastNoiseLite.new()
	tree_noise.seed = world_seed + 251
	tree_noise.frequency = 0.08

	rock_noise = FastNoiseLite.new()
	rock_noise.seed = world_seed + 293
	rock_noise.frequency = 0.1

	grass_noise = FastNoiseLite.new()
	grass_noise.seed = world_seed + 337
	grass_noise.frequency = 0.16


func _clear_runtime_roots() -> void:
	for root in [chunks_root, props_root, effects_root]:
		if root == null:
			continue
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()

	chunks.clear()
	prop_chunks.clear()
	water_mesh = null
	dust_particles = null
	rain_particles = null
	_clear_chunk_queues()


func _sync_loaded_chunks(force: bool = false) -> void:
	var focus_position := spawn_position
	if player_anchor != null:
		focus_position = player_anchor.global_position

	var center_chunk := _world_position_to_chunk(focus_position)
	var active_chunk_load_radius := _get_active_chunk_load_radius()
	var active_chunk_unload_radius := _get_active_chunk_unload_radius()
	var active_prop_load_radius := _get_active_prop_load_radius()

	if not force and center_chunk == last_loaded_center:
		return

	last_loaded_center = center_chunk
	var retained_chunks: Dictionary = {}
	var desired_loads: Array[Vector2i] = []
	var desired_prop_chunks: Dictionary = {}

	for offset_x in range(-active_chunk_unload_radius, active_chunk_unload_radius + 1):
		for offset_z in range(-active_chunk_unload_radius, active_chunk_unload_radius + 1):
			var chunk_key := center_chunk + Vector2i(offset_x, offset_z)
			retained_chunks[chunk_key] = true
			if max(abs(offset_x), abs(offset_z)) <= active_chunk_load_radius:
				desired_loads.append(chunk_key)
			if max(abs(offset_x), abs(offset_z)) <= active_prop_load_radius:
				desired_prop_chunks[chunk_key] = true

	_sort_chunk_keys_by_distance(desired_loads, center_chunk)
	var immediate_load_budget := initial_immediate_chunk_loads if force else 0
	for chunk_key in desired_loads:
		_cancel_chunk_unload(chunk_key)
		if chunks.has(chunk_key):
			if desired_prop_chunks.has(chunk_key):
				_queue_prop_chunk_build(chunk_key)
			else:
				_clear_prop_chunk(chunk_key)
			continue
		if immediate_load_budget > 0:
			_load_chunk(chunk_key)
			immediate_load_budget -= 1
		else:
			_queue_chunk_load(chunk_key)

	for existing_key in chunks.keys():
		if retained_chunks.has(existing_key):
			if desired_prop_chunks.has(existing_key):
				_queue_prop_chunk_build(existing_key)
			else:
				_clear_prop_chunk(existing_key)
			continue
		_queue_chunk_unload(existing_key)

	_refresh_loaded_chunk_runtime_state(center_chunk)
	_filter_pending_loads(retained_chunks, center_chunk)
	_filter_pending_prop_builds(desired_prop_chunks, center_chunk)


func _load_chunk(chunk_key: Vector2i) -> void:
	var chunk: VoxelChunk = VoxelChunkScript.new()
	chunk.setup(self, chunk_key, CHUNK_SIZE)
	chunk.set_collision_enabled(_should_chunk_have_collision(chunk_key))
	chunks_root.add_child(chunk)
	chunks[chunk_key] = chunk
	_queue_chunk_rebuild(chunk_key)
	_queue_prop_chunk_build(chunk_key)


func _unload_chunk(chunk_key: Vector2i) -> void:
	if chunks.has(chunk_key):
		var chunk: VoxelChunk = chunks[chunk_key]
		chunks.erase(chunk_key)
		chunks_root.remove_child(chunk)
		chunk.queue_free()

	_cancel_chunk_rebuild(chunk_key)
	_cancel_prop_chunk_build(chunk_key)
	_clear_prop_chunk(chunk_key)


func _queue_rebuild_for_cell(cell: Vector3i) -> void:
	for chunk_key in _get_affected_chunk_keys(cell):
		_queue_chunk_rebuild(chunk_key)


func _cell_to_chunk(cell: Vector3i) -> Vector2i:
	return Vector2i(int(floor(cell.x / float(CHUNK_SIZE))), int(floor(cell.z / float(CHUNK_SIZE))))


func _get_affected_chunk_keys(cell: Vector3i) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var center_key := _cell_to_chunk(cell)
	keys.append(center_key)

	var local_x := posmod(cell.x, CHUNK_SIZE)
	var local_z := posmod(cell.z, CHUNK_SIZE)
	var hit_left := local_x == 0
	var hit_right := local_x == CHUNK_SIZE - 1
	var hit_back := local_z == 0
	var hit_front := local_z == CHUNK_SIZE - 1

	if hit_left:
		keys.append(center_key + Vector2i(-1, 0))
	if hit_right:
		keys.append(center_key + Vector2i(1, 0))
	if hit_back:
		keys.append(center_key + Vector2i(0, -1))
	if hit_front:
		keys.append(center_key + Vector2i(0, 1))
	if hit_left and hit_back:
		keys.append(center_key + Vector2i(-1, -1))
	if hit_left and hit_front:
		keys.append(center_key + Vector2i(-1, 1))
	if hit_right and hit_back:
		keys.append(center_key + Vector2i(1, -1))
	if hit_right and hit_front:
		keys.append(center_key + Vector2i(1, 1))

	return keys


func _should_chunk_have_props(chunk_key: Vector2i, center_chunk: Vector2i = last_loaded_center) -> bool:
	return max(abs(chunk_key.x - center_chunk.x), abs(chunk_key.y - center_chunk.y)) <= _get_active_prop_load_radius()


func _should_chunk_have_collision(chunk_key: Vector2i, center_chunk: Vector2i = last_loaded_center) -> bool:
	return max(abs(chunk_key.x - center_chunk.x), abs(chunk_key.y - center_chunk.y)) <= collision_load_radius


func _refresh_loaded_chunk_runtime_state(center_chunk: Vector2i = last_loaded_center) -> void:
	for chunk_key_variant in chunks.keys():
		var chunk_key: Vector2i = chunk_key_variant
		var chunk: VoxelChunk = chunks[chunk_key_variant]
		chunk.set_collision_enabled(_should_chunk_have_collision(chunk_key, center_chunk))
		chunk.refresh_render_culling()


func _build_prop_chunk(chunk_key: Vector2i) -> void:
	if prop_chunks.has(chunk_key) or not chunks.has(chunk_key):
		return

	var prop_holder := Node3D.new()
	prop_holder.name = "PropChunk_%s_%s" % [chunk_key.x, chunk_key.y]
	props_root.add_child(prop_holder)
	prop_chunks[chunk_key] = prop_holder

	var min_x := chunk_key.x * CHUNK_SIZE
	var min_z := chunk_key.y * CHUNK_SIZE
	var max_x := min_x + CHUNK_SIZE
	var max_z := min_z + CHUNK_SIZE

	var tree_density := float(world_settings.get("tree_density_multiplier", 1.0))
	var rock_density := float(world_settings.get("rock_density_multiplier", 1.0))
	var grass_density := float(world_settings.get("grass_density_multiplier", 1.0))
	var shrub_density := float(world_settings.get("shrub_density_multiplier", 1.0))
	var loot_density := float(world_settings.get("loot_prop_density_multiplier", 1.0))

	for x in range(min_x + 2, max_x - 1, 4):
		for z in range(min_z + 2, max_z - 1, 4):
			var column_key := Vector2i(x, z)
			var column := _get_column_data(column_key)
			var height := int(column.get("height", water_level))
			var moisture := float(column.get("moisture", 0.5))
			var temperature := float(column.get("temperature", 0.5))
			var steepness := int(column.get("steepness", 0))
			var top_block := get_block(Vector3i(x, height, z))
			var top_key := String(BlockLibrary.get_block_definition(top_block).get("key", ""))
			var is_flat_surface := _is_flat_enough(x, z, 1)
			var is_green_surface := top_key in ["grass", "mud", "clay", "moss_tile", "reef_stone", "moss_concrete"]
			var is_sandy_surface := top_key in ["sand", "red_sand", "sandstone", "dune_clay", "canyon_stone", "carved_sandstone", "scarlet_sandstone"]
			var is_rocky_surface := top_key in ["stone", "slate", "granite", "shale", "moon_granite", "basalt", "ash_basalt", "rock_tile", "limestone_brick"]
			var tree_chance := _noise_01(tree_noise.get_noise_2d(float(x), float(z)))
			var grass_chance := _noise_01(grass_noise.get_noise_2d(float(x), float(z)))
			var flora_chance := _noise_01(grass_noise.get_noise_2d(float(x) + 41.0, float(z) - 37.0))
			var stash_hash := _hash_01_3d(x, height, z, 147)

			if _is_spawn_zone(x, z):
				continue
			if height <= water_level + 1:
				continue

			if is_green_surface and is_flat_surface:
				if moisture > 0.46 and temperature > 0.2 and tree_chance > (0.78 / max(tree_density, 0.1)):
					_try_spawn_tree(prop_holder, x, z, height)
					continue

				if stash_hash > (0.992 / max(loot_density, 0.1)):
					_try_spawn_treasure_chest(prop_holder, x, z, height)
					continue

				if stash_hash > (0.983 / max(loot_density, 0.1)) and moisture > 0.34:
					_try_spawn_wooden_crate(prop_holder, x, z, height)
					continue

				if moisture > 0.54 and temperature > 0.28 and flora_chance > (0.83 / max(shrub_density, 0.1)):
					_try_spawn_shrub(prop_holder, x, z, height)
					continue

				if tree_chance > 0.62 and tree_chance < 0.69 and flora_chance > 0.52:
					_try_spawn_tree_stump(prop_holder, x, z, height)
					continue

				if moisture > 0.38 and grass_chance > (0.64 / max(grass_density, 0.1)):
					_try_spawn_grass(prop_holder, x, z, height)

			var rock_chance := _noise_01(rock_noise.get_noise_2d(float(x), float(z)))
			if is_sandy_surface and is_flat_surface and stash_hash > (0.986 / max(loot_density, 0.1)):
				_try_spawn_wooden_crate(prop_holder, x, z, height)
				continue

			if is_rocky_surface and is_flat_surface and stash_hash > (0.989 / max(loot_density, 0.1)):
				_try_spawn_tool_chest(prop_holder, x, z, height)
				continue

			if (steepness >= 2 or top_block == BlockLibrary.STONE) and rock_chance > (0.74 / max(rock_density, 0.1)):
				_try_spawn_rock(prop_holder, x, z, height)


func _try_spawn_tree(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "tree:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var tree = TREE_SCENE.instantiate()
	if tree.has_method("configure"):
		tree.call("configure", self, prop_key, 4 + abs(((x * 73856093) ^ (z * 19349663) ^ world_seed) % 3))
	tree.position = Vector3(x + 0.5, height + 1.0, z + 0.5)
	tree.scale = Vector3.ONE * (1.0 + _noise_01(tree_noise.get_noise_2d(float(x) + 17.0, float(z) - 11.0)) * 0.26)
	tree.rotation.y = _noise_01(tree_noise.get_noise_2d(float(x) - 8.0, float(z) + 21.0)) * TAU
	prop_holder.add_child(tree)


func _try_spawn_rock(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "rock:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var rock = ROCK_SCENE.instantiate()
	rock.position = Vector3(x + 0.5, height + 0.8, z + 0.5)
	rock.scale = Vector3.ONE * (0.82 + _noise_01(rock_noise.get_noise_2d(float(x) + 12.0, float(z) + 9.0)) * 0.22)
	rock.rotation.y = _noise_01(rock_noise.get_noise_2d(float(x) - 6.0, float(z) + 13.0)) * TAU
	prop_holder.add_child(rock)


func _try_spawn_grass(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "grass:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var grass = GRASS_SCENE.instantiate()
	grass.position = Vector3(x + 0.5, height + 1.0, z + 0.5)
	grass.scale = Vector3.ONE * (0.82 + _noise_01(grass_noise.get_noise_2d(float(x) - 19.0, float(z) + 15.0)) * 0.2)
	grass.rotation.y = _noise_01(grass_noise.get_noise_2d(float(x) + 7.0, float(z) + 5.0)) * TAU
	prop_holder.add_child(grass)


func _try_spawn_treasure_chest(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "treasure_chest:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var chest = TREASURE_CHEST_SCENE.instantiate()
	if chest.has_method("configure"):
		chest.call("configure", self, prop_key)
	chest.position = Vector3(x + 0.5, height + 1.0, z + 0.5)
	chest.scale = Vector3.ONE * 0.92
	chest.rotation.y = _hash_01_3d(x, height, z, 201) * TAU
	prop_holder.add_child(chest)


func _try_spawn_wooden_crate(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "wooden_crate:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var crate = WOODEN_CRATE_SCENE.instantiate()
	if crate.has_method("configure"):
		crate.call("configure", self, prop_key)
	crate.position = Vector3(x + 0.5, height + 0.8, z + 0.5)
	crate.scale = Vector3.ONE * (0.86 + _hash_01_3d(x, height, z, 223) * 0.16)
	crate.rotation.y = _hash_01_3d(x, height, z, 227) * TAU
	prop_holder.add_child(crate)


func _try_spawn_tool_chest(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "tool_chest:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var tool_chest = TOOL_CHEST_SCENE.instantiate()
	if tool_chest.has_method("configure"):
		tool_chest.call("configure", self, prop_key)
	tool_chest.position = Vector3(x + 0.5, height + 0.82, z + 0.5)
	tool_chest.scale = Vector3.ONE * 0.88
	tool_chest.rotation.y = _hash_01_3d(x, height, z, 229) * TAU
	prop_holder.add_child(tool_chest)


func _try_spawn_tree_stump(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "tree_stump:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var stump = TREE_STUMP_SCENE.instantiate()
	if stump.has_method("configure"):
		stump.call("configure", self, prop_key)
	stump.position = Vector3(x + 0.5, height + 0.52, z + 0.5)
	stump.scale = Vector3.ONE * (0.92 + _hash_01_3d(x, height, z, 233) * 0.18)
	stump.rotation.y = _hash_01_3d(x, height, z, 239) * TAU
	prop_holder.add_child(stump)


func _try_spawn_shrub(prop_holder: Node3D, x: int, z: int, height: int) -> void:
	var prop_key := "shrub:%s:%s" % [x, z]
	if removed_props.has(prop_key):
		return

	var shrub = SHRUB_SCENE.instantiate()
	shrub.position = Vector3(x + 0.5, height + 1.0, z + 0.5)
	shrub.scale = Vector3.ONE * (0.82 + _hash_01_3d(x, height, z, 241) * 0.24)
	shrub.rotation.y = _hash_01_3d(x, height, z, 251) * TAU
	prop_holder.add_child(shrub)


func _get_column_data(cell: Vector2i) -> Dictionary:
	if column_cache.has(cell):
		return column_cache[cell]

	var height := _sample_height_value(cell.x, cell.y)
	var steepness := _estimate_steepness(cell.x, cell.y, height)
	var moisture := _noise_01(moisture_noise.get_noise_2d(float(cell.x), float(cell.y)))
	var temperature := _noise_01(temperature_noise.get_noise_2d(float(cell.x) + 97.0, float(cell.y) - 83.0))

	var column := {
		"height": height,
		"steepness": steepness,
		"moisture": moisture,
		"temperature": temperature,
	}
	column_cache[cell] = column
	_prune_column_cache_if_needed()
	return column


func _sample_height_value(x: int, z: int) -> int:
	var fx := float(x)
	var fz := float(z)
	var warped_x := fx + warp_x_noise.get_noise_2d(fx, fz) * 12.0
	var warped_z := fz + warp_z_noise.get_noise_2d(fx, fz) * 12.0

	var continental := _noise_01(continental_noise.get_noise_2d(warped_x, warped_z))
	var hills := _noise_01(hills_noise.get_noise_2d(warped_x * 1.1, warped_z * 1.1))
	var peaks := pow(absf(peaks_noise.get_noise_2d(warped_x * 0.86, warped_z * 0.86)), 1.42)
	var erosion := _noise_01(erosion_noise.get_noise_2d(warped_x * 1.24, warped_z * 1.24))

	var terrain_height_bonus := float(world_settings.get("terrain_height_bonus", 0.0))
	var ridge_strength := float(world_settings.get("terrain_ridge_strength", 1.0))

	var broad_land := lerpf(8.0, 20.0, pow(continental, 1.18))
	var rolling_hills := (hills - 0.5) * lerpf(3.0, 8.5, continental)
	var ridge_height := peaks * lerpf(2.5, 15.5, continental) * ridge_strength
	var erosion_drop := erosion * lerpf(1.5, 5.0, continental)

	var height_value := broad_land + rolling_hills + ridge_height - erosion_drop + terrain_height_bonus
	return int(clamp(round(height_value), 4.0, float(max_height - 4)))


func _estimate_steepness(x: int, z: int, center_height: int) -> int:
	var max_delta := 0
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var sample_height := _sample_neighbor_height(x + offset.x, z + offset.y)
		max_delta = max(max_delta, abs(sample_height - center_height))
	return max_delta


func _sample_neighbor_height(x: int, z: int) -> int:
	var cell := Vector2i(x, z)
	if column_cache.has(cell):
		return int(column_cache[cell].get("height", water_level))
	return _sample_height_value(x, z)


func _pick_block_for_height(y: int, surface_height: int, steepness: int, moisture: float, temperature: float) -> int:
	if y == surface_height:
		if surface_height <= water_level + 1:
			return BlockLibrary.SAND
		if steepness >= 4 or (surface_height >= water_level + 14 and steepness >= 2):
			return BlockLibrary.STONE
		if temperature > 0.68 and moisture < 0.34:
			return BlockLibrary.SAND
		return BlockLibrary.GRASS

	if y >= surface_height - 2:
		if surface_height <= water_level + 1:
			return BlockLibrary.SAND
		if steepness >= 5:
			return BlockLibrary.STONE
		return BlockLibrary.DIRT

	return BlockLibrary.STONE


func _decorate_generated_block(
	cell: Vector3i,
	base_block: int,
	surface_height: int,
	steepness: int,
	moisture: float,
	temperature: float
) -> int:
	if base_block == BlockLibrary.AIR:
		return BlockLibrary.AIR

	var surface_depth := surface_height - cell.y
	var surface_hash := _hash_01_3d(cell.x, surface_height, cell.z, 11)
	var strata_hash := _hash_01_3d(cell.x, cell.y, cell.z, 29)
	var relic_hash := _hash_01_3d(cell.x, cell.y, cell.z, 53)

	if cell.y == surface_height:
		if temperature < 0.24 and surface_height > water_level + 4:
			return _pick_block_from_keys(["snow", "ice", "aurora_ice", "frost_marble", "frost_slate", "glacier_tile"], surface_hash, BlockLibrary.SNOW)

		if moisture > 0.8 and temperature < 0.64:
			return _pick_block_from_keys(["mud", "clay", "dune_clay", "reef_stone"], surface_hash, BlockLibrary.MUD)

		if base_block == BlockLibrary.SAND:
			if temperature > 0.82 and surface_hash > 0.94:
				return _pick_block_from_keys(["glass", "prism_glass", "obsidian_glass"], surface_hash, BlockLibrary.GLASS)
			if temperature > 0.72:
				return _pick_block_from_keys(["red_sand", "sandstone", "dune_clay", "canyon_stone", "scarlet_sandstone", "carved_sandstone"], surface_hash, BlockLibrary.RED_SAND)
			if moisture > 0.58:
				return _pick_block_from_keys(["clay", "dune_clay", "sandstone"], surface_hash, BlockLibrary.CLAY)
			return _pick_block_from_keys(["sand", "sandstone", "carved_sandstone"], surface_hash, BlockLibrary.SANDSTONE if steepness >= 2 else BlockLibrary.SAND)

		if base_block == BlockLibrary.STONE:
			if moisture > 0.66:
				return _pick_block_from_keys(["mossy_stone", "moss_tile", "reef_stone", "lichen_rock_block"], surface_hash, BlockLibrary.MOSSY_STONE)
			if surface_height > water_level + 20:
				if temperature < 0.36 and surface_hash > 0.32:
					return _pick_block_from_keys(["marble", "frost_marble", "moon_granite", "marble_tile"], surface_hash, BlockLibrary.MARBLE)
				return _pick_block_from_keys(["granite", "moon_granite", "slate", "shale", "limestone_brick", "travertine_tile"], surface_hash, BlockLibrary.GRANITE)
			return _pick_block_from_keys(["slate", "granite", "shale", "moon_granite"], surface_hash, BlockLibrary.SLATE)

		if base_block == BlockLibrary.GRASS:
			if surface_height > water_level + 22 and temperature < 0.34:
				return _pick_block_from_keys(["snow", "ice", "frost_slate", "frost_marble", "glacier_tile"], surface_hash, BlockLibrary.SNOW)
			if moisture > 0.84:
				return _pick_block_from_keys(["mud", "clay", "moss_tile", "reef_stone"], surface_hash, BlockLibrary.MUD)
			if temperature > 0.74 and moisture < 0.32:
				return _pick_block_from_keys(["red_sand", "sandstone", "dune_clay", "canyon_stone"], surface_hash, BlockLibrary.RED_SAND)

	if surface_depth >= 1 and surface_depth <= 3:
		if base_block == BlockLibrary.DIRT:
			if moisture > 0.72:
				return _pick_block_from_keys(["clay", "mud", "dune_clay", "reef_stone"], strata_hash, BlockLibrary.CLAY)
			if temperature > 0.68 and moisture < 0.34:
				return _pick_block_from_keys(["sandstone", "red_sand", "carved_sandstone", "canyon_stone"], strata_hash, BlockLibrary.SANDSTONE)

		if base_block == BlockLibrary.SAND:
			return _pick_block_from_keys(["sand", "sandstone", "carved_sandstone", "scarlet_sandstone"], strata_hash, BlockLibrary.SANDSTONE)

		if base_block == BlockLibrary.STONE:
			if surface_height > water_level + 20 and temperature < 0.36 and strata_hash > 0.44:
				return _pick_block_from_keys(["marble", "frost_marble", "moon_granite"], strata_hash, BlockLibrary.MARBLE)
			if moisture > 0.66 and strata_hash > 0.52:
				return _pick_block_from_keys(["mossy_stone", "reef_stone", "lichen_rock_block"], strata_hash, BlockLibrary.MOSSY_STONE)
			if steepness >= 3:
				return _pick_block_from_keys(["slate", "granite", "shale", "moon_granite"], strata_hash, BlockLibrary.SLATE)
			if temperature > 0.72 and moisture < 0.28 and strata_hash > 0.58:
				return _pick_block_from_keys(["sandstone", "canyon_stone", "carved_sandstone"], strata_hash, BlockLibrary.SANDSTONE)

	if base_block == BlockLibrary.STONE:
		if cell.y <= 3:
			if relic_hash > 0.996:
				return _pick_block_from_keys(["neon_grid", "industrial_grate"], relic_hash, BlockLibrary.NEON_GRID)
			if relic_hash > 0.986:
				return _pick_block_from_keys(["obsidian", "obsidian_glass", "ancient_metal"], relic_hash, BlockLibrary.OBSIDIAN)
			return _pick_block_from_keys(["basalt", "ash_basalt", "stone"], strata_hash, BlockLibrary.BASALT)

		if cell.y <= 6 and strata_hash > 0.83:
			return _pick_block_from_keys(["obsidian", "obsidian_glass", "ash_basalt"], strata_hash, BlockLibrary.OBSIDIAN)
		if cell.y <= 10 and strata_hash > 0.68:
			return _pick_block_from_keys(["basalt", "ash_basalt", "volcanic_brick"], strata_hash, BlockLibrary.BASALT)
		if cell.y <= 14 and relic_hash > 0.97:
			return _pick_block_from_keys(["amethyst", "ember_crystal", "storm_crystal", "aurora_crystal"], relic_hash, BlockLibrary.AMETHYST)
		if cell.y <= 18 and relic_hash > 0.952:
			return _pick_block_from_keys(["cobalt_block", "navy_steel", "circuit_plate"], relic_hash, BlockLibrary.COBALT_BLOCK)
		if cell.y <= 24 and relic_hash > 0.93:
			return _pick_block_from_keys(["copper_block", "bronze_plate", "rust_steel", "ancient_metal"], relic_hash, BlockLibrary.COPPER_BLOCK)
		if cell.y <= 20 and temperature > 0.68 and moisture < 0.35 and relic_hash > 0.918:
			return _pick_block_from_keys(["terracotta_tile", "kiln_brick", "city_brick", "volcanic_brick"], relic_hash, BlockLibrary.TERRACOTTA_TILE)
		if cell.y <= 22 and moisture > 0.66 and relic_hash > 0.914:
			return _pick_block_from_keys(["mossy_brick", "moss_concrete", "plaster_stone", "moss_tile"], relic_hash, BlockLibrary.MOSSY_BRICK)
		if cell.y <= 26 and steepness >= 2 and relic_hash > 0.925:
			return _pick_block_from_keys(["stone_brick", "kiln_brick", "white_citadel_brick", "limestone_brick", "city_brick"], relic_hash, BlockLibrary.STONE_BRICK)
		if cell.y <= 12 and temperature < 0.28 and relic_hash > 0.978:
			return _pick_block_from_keys(["ice", "aurora_ice", "obsidian_glass", "prism_glass"], relic_hash, BlockLibrary.ICE)
		if cell.y <= 12 and temperature > 0.76 and moisture < 0.28 and relic_hash > 0.964:
			return _pick_block_from_keys(["glass", "prism_glass", "obsidian_glass"], relic_hash, BlockLibrary.GLASS)
		if surface_height > water_level + 24 and strata_hash > 0.66:
			return _pick_block_from_keys(["marble", "frost_marble", "moon_granite", "marble_tile"], strata_hash, BlockLibrary.MARBLE if temperature < 0.42 else BlockLibrary.GRANITE)
		if steepness >= 4 and strata_hash > 0.56:
			return _pick_block_from_keys(["slate", "shale", "ash_basalt", "rock_tile"], strata_hash, BlockLibrary.SLATE)
		if moisture > 0.72 and strata_hash > 0.6:
			return _pick_block_from_keys(["mossy_stone", "reef_stone", "lichen_rock_block", "moss_tile"], strata_hash, BlockLibrary.MOSSY_STONE)

	return base_block


func _prepare_spawn_zone() -> void:
	spawn_cell = _find_spawn_cell()
	var spawn_height := int(_get_column_data(spawn_cell).get("height", water_level + 4))

	for x in range(spawn_cell.x - 3, spawn_cell.x + 4):
		for z in range(spawn_cell.y - 3, spawn_cell.y + 4):
			var distance := Vector2(x - spawn_cell.x, z - spawn_cell.y).length()
			var column_height := int(_get_column_data(Vector2i(x, z)).get("height", spawn_height))
			if distance <= 2.6:
				_set_column_height(x, z, spawn_height)
			elif distance <= 3.5 and abs(column_height - spawn_height) > 1:
				_set_column_height(x, z, spawn_height)

			for clear_y in range(spawn_height + 1, min(max_height, spawn_height + 7)):
				modified_blocks[Vector3i(x, clear_y, z)] = BlockLibrary.AIR

	spawn_position = _resolve_safe_spawn_position(spawn_cell, spawn_height)


func _find_spawn_cell() -> Vector2i:
	var best_cell := Vector2i.ZERO
	var best_score := -1000000.0

	for x in range(-28, 29):
		for z in range(-28, 29):
			var cell := Vector2i(x, z)
			var column := _get_column_data(cell)
			var height := int(column.get("height", water_level))
			var steepness := int(column.get("steepness", 0))
			if height <= water_level + 3:
				continue
			if steepness > 1:
				continue
			if not _is_flat_enough(x, z, 2):
				continue

			var top_block := get_block(Vector3i(x, height, z))
			if top_block != BlockLibrary.GRASS:
				continue

			var moisture := float(column.get("moisture", 0.5))
			var temperature := float(column.get("temperature", 0.5))
			var distance_to_origin := Vector2(x, z).length()
			var score := 42.0 - distance_to_origin * 0.65 + moisture * 6.0 + (1.0 - absf(temperature - 0.5)) * 4.0 + float(height) * 0.38
			if score > best_score:
				best_score = score
				best_cell = cell

	return best_cell


func _resolve_safe_spawn_position(cell: Vector2i, ground_height: int) -> Vector3:
	var fallback := Vector3(cell.x + 0.5, ground_height + 2.75, cell.y + 0.5)

	for radius in range(5):
		for offset_x in range(-radius, radius + 1):
			for offset_z in range(-radius, radius + 1):
				if radius > 0 and abs(offset_x) != radius and abs(offset_z) != radius:
					continue

				var sample_cell := Vector2i(cell.x + offset_x, cell.y + offset_z)
				var sample_ground := int(_get_column_data(sample_cell).get("height", ground_height))
				if abs(sample_ground - ground_height) > 1:
					continue

				for step in range(12):
					var local_feet_y := float(sample_ground) + 1.08 + float(step) * 0.35
					var local_feet := Vector3(sample_cell.x + 0.5, local_feet_y, sample_cell.y + 0.5)
					if _is_spawn_volume_clear(local_feet, SPAWN_CLEARANCE_RADIUS, SPAWN_CLEARANCE_HEIGHT):
						return local_feet if chunks_root == null or not chunks_root.is_inside_tree() else chunks_root.to_global(local_feet)

	return fallback if chunks_root == null or not chunks_root.is_inside_tree() else chunks_root.to_global(fallback)


func _is_spawn_volume_clear(local_feet: Vector3, radius: float, height: float) -> bool:
	var min_x := int(floor(local_feet.x - radius))
	var max_x := int(floor(local_feet.x + radius))
	var min_y := int(floor(local_feet.y))
	var max_y := int(floor(local_feet.y + height - 0.001))
	var min_z := int(floor(local_feet.z - radius))
	var max_z := int(floor(local_feet.z + radius))

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			for z in range(min_z, max_z + 1):
				if get_block(Vector3i(x, y, z)) != BlockLibrary.AIR:
					return false
	return true


func _set_column_height(x: int, z: int, target_height: int) -> void:
	var column_key := Vector2i(x, z)
	column_cache.erase(column_key)
	var moisture := float(_get_column_data(column_key).get("moisture", 0.5))
	var temperature := float(_get_column_data(column_key).get("temperature", 0.5))
	for y in range(0, max_height):
		var cell := Vector3i(x, y, z)
		if y <= target_height:
			var base_block := _pick_block_for_height(
				y,
				target_height,
				0,
				moisture,
				temperature
			)
			modified_blocks[cell] = _decorate_generated_block(cell, base_block, target_height, 0, moisture, temperature)
		else:
			modified_blocks[cell] = BlockLibrary.AIR


func _is_flat_enough(x: int, z: int, radius: int) -> bool:
	var base_height := int(_get_column_data(Vector2i(x, z)).get("height", water_level))
	for offset_x in range(-radius, radius + 1):
		for offset_z in range(-radius, radius + 1):
			var sample_height := int(_get_column_data(Vector2i(x + offset_x, z + offset_z)).get("height", water_level))
			if abs(sample_height - base_height) > 1:
				return false
	return true


func _is_spawn_zone(x: int, z: int) -> bool:
	return Vector2(x, z).distance_to(Vector2(spawn_cell.x, spawn_cell.y)) < 9.0


func _would_intersect_player(cell: Vector3i, player_position: Vector3) -> bool:
	var center := cell_to_world(cell)
	var player_bottom := player_position.y
	var player_top := player_position.y + 1.85
	var horizontal_distance := Vector2(center.x - player_position.x, center.z - player_position.z).length()
	var block_bottom := center.y - 0.5
	var block_top := center.y + 0.5
	var vertical_overlap := player_bottom < block_top and player_top > block_bottom
	return horizontal_distance < 0.72 and vertical_overlap


func _setup_water() -> void:
	if water_mesh != null:
		effects_root.remove_child(water_mesh)
		water_mesh.queue_free()

	water_mesh = MeshInstance3D.new()
	water_mesh.name = "Water"
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(float((chunk_load_radius + 2) * CHUNK_SIZE * 2), float((chunk_load_radius + 2) * CHUNK_SIZE * 2))
	water_mesh.mesh = plane

	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	water_mesh.material_override = material
	water_mesh.position = Vector3(spawn_position.x, water_level + 0.32, spawn_position.z)
	effects_root.add_child(water_mesh)


func _setup_particles() -> void:
	dust_particles = GPUParticles3D.new()
	dust_particles.name = "DustParticles"
	dust_particles.amount = 96
	dust_particles.lifetime = 8.0
	dust_particles.preprocess = 8.0
	dust_particles.emitting = true
	dust_particles.position = Vector3(spawn_position.x, water_level + 4.5, spawn_position.z)

	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.03
	draw_mesh.height = 0.06
	var draw_material := StandardMaterial3D.new()
	draw_material.albedo_color = Color(0.91, 0.96, 1.0, 0.65)
	draw_material.emission_enabled = true
	draw_material.emission = Color(0.2, 0.3, 0.45)
	draw_material.emission_energy_multiplier = 0.25
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.vertex_color_use_as_albedo = true
	draw_mesh.material = draw_material
	dust_particles.draw_pass_1 = draw_mesh

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.02, 0.0)
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.09
	process.scale_min = 0.35
	process.scale_max = 0.8
	process.color = Color(0.8, 0.9, 1.0, 0.5)
	dust_particles.process_material = process

	effects_root.add_child(dust_particles)


func _setup_weather_effects() -> void:
	if rain_particles != null:
		effects_root.remove_child(rain_particles)
		rain_particles.queue_free()

	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.amount = int(runtime_profile.get("rain_particles", DEFAULT_RAIN_PARTICLE_AMOUNT))
	rain_particles.lifetime = 1.6
	rain_particles.preprocess = 0.6
	rain_particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	rain_particles.emitting = false
	rain_particles.position = Vector3(spawn_position.x, water_level + 16.0, spawn_position.z)
	rain_particles.visibility_aabb = AABB(Vector3(-24.0, -18.0, -24.0), Vector3(48.0, 32.0, 48.0))

	var drop_mesh := QuadMesh.new()
	drop_mesh.size = Vector2(0.022, 0.45)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.84, 0.9, 1.0, 0.42)
	drop_material.emission_enabled = true
	drop_material.emission = Color(0.12, 0.18, 0.26)
	drop_material.emission_energy_multiplier = 0.18
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh.material = drop_material
	rain_particles.draw_pass_1 = drop_mesh

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 10.0
	process.gravity = Vector3(0.0, -28.0, 0.0)
	process.initial_velocity_min = 12.0
	process.initial_velocity_max = 18.0
	process.scale_min = 0.72
	process.scale_max = 1.0
	process.color = Color(0.88, 0.94, 1.0, 0.5)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(18.0, 2.0, 18.0)
	rain_particles.process_material = process
	effects_root.add_child(rain_particles)


func _setup_optional_ambience() -> void:
	var ambience_path := "res://assets/audio/ambient_loop.ogg"
	if not ResourceLoader.exists(ambience_path):
		return

	if get_node_or_null("Ambience") != null:
		return

	var ambience := AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.stream = load(ambience_path)
	ambience.volume_db = -13.0
	add_child(ambience)
	ambience.play()


func _update_following_effects() -> void:
	var focus_position := spawn_position
	if player_anchor != null:
		focus_position = player_anchor.global_position
	var focus_anchor := Vector2(focus_position.x, focus_position.z)
	if focus_anchor.distance_to(last_effect_anchor) < 0.75:
		return
	last_effect_anchor = focus_anchor

	if water_mesh != null:
		water_mesh.position.x = focus_position.x
		water_mesh.position.z = focus_position.z

	if dust_particles != null:
		dust_particles.position.x = focus_position.x
		dust_particles.position.z = focus_position.z
	if rain_particles != null:
		rain_particles.position.x = focus_position.x
		rain_particles.position.y = focus_position.y + 14.0
		rain_particles.position.z = focus_position.z


func _reset_weather_state() -> void:
	weather_rng.seed = int(world_seed * 17 + 991)
	weather_timer = weather_rng.randf_range(WEATHER_CHANGE_INTERVAL_MIN, WEATHER_CHANGE_INTERVAL_MAX)
	weather_intensity = 0.0
	target_weather_intensity = clampf(float(world_settings.get("starting_rain_intensity", 0.0)), 0.0, 1.0)
	storm_intensity = 0.0
	target_storm_intensity = 0.0
	lightning_flash = 0.0


func _update_weather(delta: float) -> void:
	if cycle == null:
		return

	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = weather_rng.randf_range(WEATHER_CHANGE_INTERVAL_MIN, WEATHER_CHANGE_INTERVAL_MAX)
		_roll_next_weather_targets()

	weather_intensity = move_toward(weather_intensity, target_weather_intensity, delta * 0.08)
	storm_intensity = move_toward(storm_intensity, target_storm_intensity, delta * 0.1)
	lightning_flash = move_toward(lightning_flash, 0.0, delta * 2.6)

	if storm_intensity > 0.52 and weather_intensity > 0.4 and weather_rng.randf() < delta * (0.015 + storm_intensity * 0.05):
		lightning_flash = 1.0

	if rain_particles != null:
		rain_particles.emitting = weather_intensity > 0.05
		rain_particles.amount = max(1, int(int(runtime_profile.get("rain_particles", DEFAULT_RAIN_PARTICLE_AMOUNT)) * max(weather_intensity, 0.05)))
		rain_particles.speed_scale = lerpf(0.82, 1.28, storm_intensity)

	var environment := environment_node.environment if environment_node != null else null
	if environment != null:
		environment.fog_density = lerpf(0.0032, 0.0068, weather_intensity)
		environment.volumetric_fog_density = lerpf(0.008, 0.016, weather_intensity + storm_intensity * 0.35)
		environment.fog_light_color = Color(1.0, 0.86, 0.72).lerp(Color(0.58, 0.64, 0.72), weather_intensity)
		environment.ambient_light_energy = lerpf(1.62, 1.26, weather_intensity) + lightning_flash * 0.32

	cycle.set_weather_state(weather_intensity, storm_intensity, lightning_flash)


func _roll_next_weather_targets() -> void:
	var rain_roll := weather_rng.randf()
	if rain_roll > 0.7:
		target_weather_intensity = weather_rng.randf_range(0.45, 0.95)
		target_storm_intensity = weather_rng.randf_range(0.18, 0.82) if target_weather_intensity > 0.72 else weather_rng.randf_range(0.0, 0.35)
		return
	target_weather_intensity = weather_rng.randf_range(0.0, 0.22)
	target_storm_intensity = 0.0


func spawn_block_break_effect(cell: Vector3i, block_id: int) -> void:
	if effects_root == null:
		return

	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.amount = 18
	burst.lifetime = 0.55
	burst.preprocess = 0.0
	burst.explosiveness = 0.92
	burst.emitting = true
	burst.position = cell_to_world(cell)
	burst.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3.0, 3.0, 3.0))

	var debris_mesh := BoxMesh.new()
	debris_mesh.size = Vector3.ONE * 0.08
	var debris_material := StandardMaterial3D.new()
	debris_material.albedo_color = BlockLibrary.get_item_color(block_id)
	debris_material.roughness = 0.72
	debris_material.vertex_color_use_as_albedo = true
	debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	debris_mesh.material = debris_material
	burst.draw_pass_1 = debris_mesh

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, -11.0, 0.0)
	process.initial_velocity_min = 1.8
	process.initial_velocity_max = 3.8
	process.scale_min = 0.55
	process.scale_max = 1.25
	process.angular_velocity_min = -18.0
	process.angular_velocity_max = 18.0
	process.color = BlockLibrary.get_item_color(block_id)
	burst.process_material = process

	effects_root.add_child(burst)
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(burst):
				burst.queue_free()
	)


func _extract_prop_owner(collider: Object) -> Node:
	if collider == null or not (collider is Node):
		return null

	var node: Node = collider
	while node != null:
		if node.has_method("apply_damage") and node.has_method("get_interaction_name"):
			return node
		node = node.get_parent()
	return null


func _generate_runtime_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483646)


func _noise_01(value: float) -> float:
	return clampf(value * 0.5 + 0.5, 0.0, 1.0)


func _hash_01_3d(x: int, y: int, z: int, salt: int) -> float:
	var hash_value := int(x * 73856093) ^ int(y * 19349663) ^ int(z * 83492791) ^ int(world_seed + salt * 2654435761)
	hash_value = (hash_value << 13) ^ hash_value
	var normalized := int((hash_value * (hash_value * hash_value * 15731 + 789221) + 1376312589) & 0x7fffffff)
	return float(normalized) / 2147483647.0


func _pick_block_from_keys(block_keys: Array[String], hash_value: float, fallback_block_id: int) -> int:
	var candidate_ids: Array[int] = []
	for block_key in block_keys:
		var block_id := BlockLibrary.get_block_id_by_key(block_key)
		if block_id != BlockLibrary.AIR:
			candidate_ids.append(block_id)

	if candidate_ids.is_empty():
		return fallback_block_id

	var normalized_hash := clampf(hash_value, 0.0, 0.999999)
	var index := mini(int(floor(normalized_hash * float(candidate_ids.size()))), candidate_ids.size() - 1)
	return candidate_ids[index]


func _world_position_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / float(CHUNK_SIZE))),
		int(floor(world_position.z / float(CHUNK_SIZE)))
	)


func _get_required_chunk_keys(center_chunk: Vector2i, radius: int) -> Array[Vector2i]:
	var chunk_keys: Array[Vector2i] = []
	for offset_x in range(-radius, radius + 1):
		for offset_z in range(-radius, radius + 1):
			if max(abs(offset_x), abs(offset_z)) > radius:
				continue
			chunk_keys.append(center_chunk + Vector2i(offset_x, offset_z))
	return chunk_keys


func _get_required_prop_chunk_keys(center_chunk: Vector2i) -> Array[Vector2i]:
	return _get_required_chunk_keys(center_chunk, prop_load_radius)


func _get_active_chunk_load_radius() -> int:
	if not initial_streaming_active:
		return chunk_load_radius
	return min(chunk_load_radius, max(0, int(runtime_profile.get("boot_chunk_load_radius", DEFAULT_BOOT_CHUNK_LOAD_RADIUS))))


func _get_active_chunk_unload_radius() -> int:
	var active_chunk_radius := _get_active_chunk_load_radius()
	if not initial_streaming_active:
		return chunk_unload_radius
	return max(active_chunk_radius + 1, min(chunk_unload_radius, active_chunk_radius + 1))


func _get_active_prop_load_radius() -> int:
	if not initial_streaming_active:
		return prop_load_radius
	return min(prop_load_radius, max(0, int(runtime_profile.get("boot_prop_load_radius", DEFAULT_BOOT_PROP_LOAD_RADIUS))))


func _has_pending_required_streaming_work(required_chunks: Array[Vector2i], required_prop_chunks: Array[Vector2i]) -> bool:
	var required_chunk_set: Dictionary = {}
	for chunk_key in required_chunks:
		required_chunk_set[chunk_key] = true

	var required_prop_chunk_set: Dictionary = {}
	for prop_chunk_key in required_prop_chunks:
		required_prop_chunk_set[prop_chunk_key] = true

	for chunk_key in pending_chunk_loads:
		if required_chunk_set.has(chunk_key):
			return true

	for chunk_key in pending_chunk_rebuilds:
		if required_chunk_set.has(chunk_key):
			return true

	for prop_chunk_key in pending_prop_chunk_builds:
		if required_prop_chunk_set.has(prop_chunk_key):
			return true

	return false


func _update_streaming_adaptation(delta: float) -> void:
	var fps := float(Engine.get_frames_per_second())
	if fps > 0.0:
		streaming_sample_time += delta
		streaming_sample_accumulator += fps
		streaming_sample_count += 1
		if streaming_sample_time >= STREAMING_SAMPLE_WINDOW_SECONDS:
			streaming_average_fps = streaming_sample_accumulator / max(1.0, float(streaming_sample_count))
			streaming_sample_time = 0.0
			streaming_sample_accumulator = 0.0
			streaming_sample_count = 0

	adaptive_chunk_loads_per_frame = _resolve_streaming_budget(max_chunk_loads_per_frame, pending_chunk_loads.size(), true)
	adaptive_chunk_rebuilds_per_frame = _resolve_streaming_budget(max_chunk_rebuilds_per_frame, pending_chunk_rebuilds.size(), true)
	adaptive_prop_chunk_builds_per_frame = _resolve_streaming_budget(max_prop_chunk_builds_per_frame, pending_prop_chunk_builds.size(), false)
	adaptive_chunk_unloads_per_frame = _resolve_streaming_budget(max_chunk_unloads_per_frame, pending_chunk_unloads.size(), false)
	adaptive_chunk_rebuild_voxels_per_step = _resolve_rebuild_voxel_budget(pending_chunk_rebuilds.size())


func _reset_streaming_adaptation() -> void:
	adaptive_chunk_loads_per_frame = 1
	adaptive_chunk_rebuilds_per_frame = 1
	adaptive_prop_chunk_builds_per_frame = 1
	adaptive_chunk_unloads_per_frame = 1
	adaptive_chunk_rebuild_voxels_per_step = DEFAULT_CHUNK_REBUILD_VOXELS_PER_STEP
	streaming_average_fps = 60.0
	streaming_sample_time = 0.0
	streaming_sample_accumulator = 0.0
	streaming_sample_count = 0


func _compute_streaming_hardware_factor() -> float:
	var cpu_factor := clampf(float(runtime_profile.get("cpu_count", 4)) / 8.0, 0.5, 1.6)
	var ram_factor := clampf(float(runtime_profile.get("system_ram_mb", 8192)) / 16384.0, 0.5, 1.5)
	var gpu_factor := clampf(float(runtime_profile.get("gpu_vram_mb", 3072)) / 6144.0, 0.5, 1.5)
	return clampf(cpu_factor * 0.52 + ram_factor * 0.28 + gpu_factor * 0.20, 0.75, 1.4)


func _resolve_streaming_budget(max_budget: int, backlog: int, prioritize_backlog: bool) -> int:
	if backlog <= 0:
		return 0
	if max_budget <= 1:
		return 1

	var fps_factor := 0.0
	if streaming_average_fps >= STREAMING_HIGH_FPS:
		fps_factor = 1.0
	elif streaming_average_fps >= STREAMING_MEDIUM_FPS:
		fps_factor = 0.55
	elif streaming_average_fps >= STREAMING_LOW_FPS:
		fps_factor = 0.2

	var backlog_factor := 0.0
	if backlog >= 24:
		backlog_factor = 1.0
	elif backlog >= 12:
		backlog_factor = 0.65
	elif backlog >= 6:
		backlog_factor = 0.35

	var backlog_bias: float = 0.95 if prioritize_backlog else 0.75
	var desired_factor: float = maxf(fps_factor, backlog_factor * backlog_bias)
	if initial_streaming_active and prioritize_backlog:
		desired_factor = max(desired_factor, 0.35)
	desired_factor = clampf(desired_factor * streaming_hardware_factor, 0.0, 1.0)

	var budget := 1 + int(floor(desired_factor * float(max_budget - 1)))
	return clampi(budget, 1, max_budget)


func _resolve_rebuild_voxel_budget(backlog: int) -> int:
	var budget := DEFAULT_CHUNK_REBUILD_VOXELS_PER_STEP
	if streaming_average_fps >= STREAMING_HIGH_FPS:
		budget = 4096
	elif streaming_average_fps >= STREAMING_MEDIUM_FPS:
		budget = 2304
	elif streaming_average_fps >= STREAMING_LOW_FPS:
		budget = 1280
	else:
		budget = 384

	if backlog >= 24:
		budget = int(round(float(budget) * 1.45))
	elif backlog >= 12:
		budget = int(round(float(budget) * 1.2))
	elif backlog <= 2:
		budget = int(round(float(budget) * 0.85))

	if initial_streaming_active:
		budget = max(budget, 1536)

	budget = int(round(float(budget) * streaming_hardware_factor))
	return clampi(budget, 192, max_chunk_rebuild_voxels_per_step)


func _process_chunk_queues() -> void:
	for _step in range(adaptive_chunk_rebuilds_per_frame):
		if pending_chunk_rebuilds.is_empty():
			break
		var rebuild_key: Vector2i = pending_chunk_rebuilds.pop_front()
		if not chunks.has(rebuild_key):
			pending_chunk_rebuild_set.erase(rebuild_key)
			continue
		var rebuild_chunk: VoxelChunk = chunks[rebuild_key]
		rebuild_chunk.set_collision_enabled(_should_chunk_have_collision(rebuild_key))
		if rebuild_chunk.process_rebuild_step(adaptive_chunk_rebuild_voxels_per_step):
			pending_chunk_rebuild_set.erase(rebuild_key)
		else:
			pending_chunk_rebuilds.append(rebuild_key)

	for _step in range(adaptive_chunk_loads_per_frame):
		if pending_chunk_loads.is_empty():
			break
		var load_key: Vector2i = pending_chunk_loads.pop_front()
		pending_chunk_load_set.erase(load_key)
		if not chunks.has(load_key):
			_load_chunk(load_key)

	for _step in range(adaptive_prop_chunk_builds_per_frame):
		if pending_prop_chunk_builds.is_empty():
			break
		var prop_key: Vector2i = pending_prop_chunk_builds.pop_front()
		pending_prop_chunk_build_set.erase(prop_key)
		if chunks.has(prop_key) and _should_chunk_have_props(prop_key) and not prop_chunks.has(prop_key):
			_build_prop_chunk(prop_key)

	for _step in range(adaptive_chunk_unloads_per_frame):
		if pending_chunk_unloads.is_empty():
			break
		var unload_key: Vector2i = pending_chunk_unloads.pop_front()
		pending_chunk_unload_set.erase(unload_key)
		if chunks.has(unload_key):
			_unload_chunk(unload_key)


func _queue_chunk_load(chunk_key: Vector2i) -> void:
	if chunks.has(chunk_key) or pending_chunk_load_set.has(chunk_key):
		return
	pending_chunk_loads.append(chunk_key)
	pending_chunk_load_set[chunk_key] = true


func _queue_chunk_unload(chunk_key: Vector2i) -> void:
	if not chunks.has(chunk_key):
		return
	if pending_chunk_unload_set.has(chunk_key):
		return
	pending_chunk_unloads.append(chunk_key)
	pending_chunk_unload_set[chunk_key] = true


func _cancel_chunk_unload(chunk_key: Vector2i) -> void:
	if not pending_chunk_unload_set.has(chunk_key):
		return
	pending_chunk_unload_set.erase(chunk_key)
	var filtered: Array[Vector2i] = []
	for existing_key in pending_chunk_unloads:
		if existing_key != chunk_key:
			filtered.append(existing_key)
	pending_chunk_unloads = filtered


func _queue_chunk_rebuild(chunk_key: Vector2i) -> void:
	if not chunks.has(chunk_key):
		return
	var chunk: VoxelChunk = chunks[chunk_key]
	chunk.request_rebuild()
	if pending_chunk_rebuild_set.has(chunk_key):
		return
	pending_chunk_rebuilds.append(chunk_key)
	pending_chunk_rebuild_set[chunk_key] = true


func _cancel_chunk_rebuild(chunk_key: Vector2i) -> void:
	if not pending_chunk_rebuild_set.has(chunk_key):
		return
	pending_chunk_rebuild_set.erase(chunk_key)
	var filtered: Array[Vector2i] = []
	for existing_key in pending_chunk_rebuilds:
		if existing_key != chunk_key:
			filtered.append(existing_key)
	pending_chunk_rebuilds = filtered


func _filter_pending_loads(retained_chunks: Dictionary, center_chunk: Vector2i) -> void:
	var filtered: Array[Vector2i] = []
	var keys_to_sort: Array[Vector2i] = []
	for chunk_key in pending_chunk_loads:
		if retained_chunks.has(chunk_key):
			keys_to_sort.append(chunk_key)
		else:
			pending_chunk_load_set.erase(chunk_key)
	_sort_chunk_keys_by_distance(keys_to_sort, center_chunk)
	for chunk_key in keys_to_sort:
		filtered.append(chunk_key)
	pending_chunk_loads = filtered


func _queue_prop_chunk_build(chunk_key: Vector2i) -> void:
	if not chunks.has(chunk_key):
		return
	if prop_chunks.has(chunk_key) or pending_prop_chunk_build_set.has(chunk_key):
		return
	if not _should_chunk_have_props(chunk_key):
		return
	pending_prop_chunk_builds.append(chunk_key)
	pending_prop_chunk_build_set[chunk_key] = true


func _cancel_prop_chunk_build(chunk_key: Vector2i) -> void:
	if not pending_prop_chunk_build_set.has(chunk_key):
		return
	pending_prop_chunk_build_set.erase(chunk_key)
	var filtered: Array[Vector2i] = []
	for existing_key in pending_prop_chunk_builds:
		if existing_key != chunk_key:
			filtered.append(existing_key)
	pending_prop_chunk_builds = filtered


func _clear_prop_chunk(chunk_key: Vector2i) -> void:
	if not prop_chunks.has(chunk_key):
		return
	var prop_holder: Node3D = prop_chunks[chunk_key]
	prop_chunks.erase(chunk_key)
	props_root.remove_child(prop_holder)
	prop_holder.queue_free()


func _filter_pending_prop_builds(retained_prop_chunks: Dictionary, center_chunk: Vector2i) -> void:
	var filtered: Array[Vector2i] = []
	var keys_to_sort: Array[Vector2i] = []
	for chunk_key in pending_prop_chunk_builds:
		if retained_prop_chunks.has(chunk_key):
			keys_to_sort.append(chunk_key)
		else:
			pending_prop_chunk_build_set.erase(chunk_key)
	_sort_chunk_keys_by_distance(keys_to_sort, center_chunk)
	for chunk_key in keys_to_sort:
		filtered.append(chunk_key)
	pending_prop_chunk_builds = filtered


func _sort_chunk_keys_by_distance(chunk_keys: Array[Vector2i], center_chunk: Vector2i) -> void:
	chunk_keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var distance_a := maxi(abs(a.x - center_chunk.x), abs(a.y - center_chunk.y))
			var distance_b := maxi(abs(b.x - center_chunk.x), abs(b.y - center_chunk.y))
			if distance_a == distance_b:
				if a.x == b.x:
					return a.y < b.y
				return a.x < b.x
			return distance_a < distance_b
	)


func _clear_chunk_queues() -> void:
	pending_chunk_loads.clear()
	pending_chunk_load_set.clear()
	pending_chunk_unloads.clear()
	pending_chunk_unload_set.clear()
	pending_chunk_rebuilds.clear()
	pending_chunk_rebuild_set.clear()
	pending_prop_chunk_builds.clear()
	pending_prop_chunk_build_set.clear()


func _prune_column_cache_if_needed() -> void:
	if column_cache.size() <= column_cache_limit:
		return

	var focus := spawn_cell
	if player_anchor != null:
		focus = Vector2i(int(floor(player_anchor.global_position.x)), int(floor(player_anchor.global_position.z)))

	var cache_keys: Array[Vector2i] = []
	for key_variant in column_cache.keys():
		cache_keys.append(key_variant)

	cache_keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(focus) > b.distance_squared_to(focus)
	)

	var remove_count := mini(cache_keys.size(), maxi(32, column_cache.size() - column_cache_limit))
	for index in range(remove_count):
		column_cache.erase(cache_keys[index])


func _try_set_property(target: Object, property_name: String, value) -> void:
	if target == null:
		return
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return
