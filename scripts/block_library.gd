extends RefCounted
class_name BlockLibrary

const AIR := -1
const GRASS := 0
const DIRT := 1
const STONE := 2
const SAND := 3
const GLOW := 4
const WOOD := 5
const SNOW := 6
const MUD := 7
const CLAY := 8
const MOSSY_STONE := 9
const SLATE := 10
const GRANITE := 11
const MARBLE := 12
const SANDSTONE := 13
const RED_SAND := 14
const BASALT := 15
const OBSIDIAN := 16
const COPPER_BLOCK := 17
const COBALT_BLOCK := 18
const AMETHYST := 19
const STONE_BRICK := 20
const MOSSY_BRICK := 21
const TERRACOTTA_TILE := 22
const ICE := 23
const NEON_GRID := 24
const GLASS := 25

const DEFAULT_STACK_LIMIT := 64
const DEFAULT_HOTBAR_SIZE := 8

static var _registry_ready := false
static var _terrain_materials := {}
static var _prop_materials := {}
static var _block_definitions := {}
static var _key_to_block_id := {}
static var _display_order := []
static var _next_runtime_block_id := 100
static var _texture_quality_tier := "high"


static func reset_runtime_content() -> void:
	_registry_ready = true
	_terrain_materials.clear()
	_prop_materials.clear()
	_block_definitions.clear()
	_key_to_block_id.clear()
	_display_order.clear()
	_next_runtime_block_id = 100

	_register_builtin_block(GRASS, "grass", "Grass", Color(0.42, 0.72, 0.38), "grass")
	_register_builtin_block(DIRT, "dirt", "Dirt", Color(0.48, 0.33, 0.22), "dirt")
	_register_builtin_block(STONE, "stone", "Stone", Color(0.58, 0.62, 0.68), "stone")
	_register_builtin_block(SAND, "sand", "Sand", Color(0.9, 0.82, 0.62), "sand")
	_register_builtin_block(GLOW, "glow", "Glow Block", Color(0.65, 0.86, 1.0), "glow", 32)
	_register_builtin_block(WOOD, "wood", "Wood", Color(0.63, 0.45, 0.26), "wood")
	_register_builtin_block(SNOW, "snow", "Snow", Color(0.93, 0.96, 1.0), "snow")
	_register_builtin_block(MUD, "mud", "Mud", Color(0.36, 0.28, 0.2), "mud")
	_register_builtin_block(CLAY, "clay", "Clay", Color(0.73, 0.62, 0.56), "clay")
	_register_builtin_block(MOSSY_STONE, "mossy_stone", "Mossy Stone", Color(0.42, 0.53, 0.4), "mossy_stone")
	_register_builtin_block(SLATE, "slate", "Slate", Color(0.29, 0.33, 0.39), "slate")
	_register_builtin_block(GRANITE, "granite", "Granite", Color(0.56, 0.54, 0.52), "granite")
	_register_builtin_block(MARBLE, "marble", "Marble", Color(0.87, 0.87, 0.9), "marble")
	_register_builtin_block(SANDSTONE, "sandstone", "Sandstone", Color(0.92, 0.86, 0.73), "sandstone")
	_register_builtin_block(RED_SAND, "red_sand", "Red Sand", Color(0.83, 0.48, 0.31), "red_sand")
	_register_builtin_block(BASALT, "basalt", "Basalt", Color(0.18, 0.19, 0.22), "basalt")
	_register_builtin_block(OBSIDIAN, "obsidian", "Obsidian", Color(0.09, 0.06, 0.12), "obsidian", 48)
	_register_builtin_block(COPPER_BLOCK, "copper_block", "Copper Alloy", Color(0.81, 0.49, 0.28), "copper", 48)
	_register_builtin_block(COBALT_BLOCK, "cobalt_block", "Cobalt Alloy", Color(0.23, 0.5, 0.84), "cobalt", 48)
	_register_builtin_block(AMETHYST, "amethyst", "Amethyst", Color(0.65, 0.45, 0.94), "amethyst", 48)
	_register_builtin_block(STONE_BRICK, "stone_brick", "Stone Brick", Color(0.63, 0.62, 0.61), "stone_brick")
	_register_builtin_block(MOSSY_BRICK, "mossy_brick", "Mossy Brick", Color(0.45, 0.53, 0.44), "mossy_brick")
	_register_builtin_block(TERRACOTTA_TILE, "terracotta_tile", "Terracotta Tile", Color(0.79, 0.46, 0.31), "terracotta_tile")
	_register_builtin_block(ICE, "ice", "Ice", Color(0.73, 0.88, 1.0), "ice", 48)
	_register_builtin_block(NEON_GRID, "neon_grid", "Neon Grid", Color(0.14, 0.93, 0.98), "neon_grid", 32)
	_register_builtin_block(GLASS, "glass", "Glass", Color(0.75, 0.88, 0.96), "glass", 48)
	_register_builtin_block(26, "frost_marble", "Frost Marble", Color(0.88, 0.94, 1.0), "frost_marble")
	_register_builtin_block(27, "aurora_ice", "Aurora Ice", Color(0.63, 0.96, 0.98), "aurora_ice", 48)
	_register_builtin_block(28, "shale", "Shale", Color(0.27, 0.31, 0.33), "shale")
	_register_builtin_block(29, "moon_granite", "Moon Granite", Color(0.69, 0.72, 0.78), "moon_granite")
	_register_builtin_block(30, "limestone_brick", "Limestone Brick", Color(0.92, 0.9, 0.82), "limestone_brick")
	_register_builtin_block(31, "travertine_tile", "Travertine Tile", Color(0.88, 0.83, 0.76), "travertine_tile")
	_register_builtin_block(32, "cobble_road", "Cobble Road", Color(0.5, 0.53, 0.54), "cobble_road")
	_register_builtin_block(33, "ancient_cobble", "Ancient Cobble", Color(0.43, 0.38, 0.32), "ancient_cobble")
	_register_builtin_block(34, "moss_tile", "Moss Tile", Color(0.36, 0.51, 0.42), "moss_tile")
	_register_builtin_block(35, "lichen_rock_block", "Lichen Rock", Color(0.41, 0.46, 0.4), "lichen_rock_block")
	_register_builtin_block(36, "quartz_ceramic", "Quartz Ceramic", Color(0.91, 0.93, 0.95), "quartz_ceramic")
	_register_builtin_block(37, "ivory_plaster", "Ivory Plaster", Color(0.93, 0.89, 0.82), "ivory_plaster")
	_register_builtin_block(38, "kiln_brick", "Kiln Brick", Color(0.72, 0.35, 0.25), "kiln_brick")
	_register_builtin_block(39, "royal_mosaic", "Royal Mosaic", Color(0.72, 0.78, 0.88), "royal_mosaic")
	_register_builtin_block(40, "terrazzo_lux", "Terrazzo Lux", Color(0.86, 0.83, 0.82), "terrazzo_lux")
	_register_builtin_block(41, "concrete_panel", "Concrete Panel", Color(0.59, 0.61, 0.64), "concrete_panel")
	_register_builtin_block(42, "polished_concrete", "Polished Concrete", Color(0.7, 0.7, 0.71), "polished_concrete")
	_register_builtin_block(43, "rust_steel", "Rust Steel", Color(0.67, 0.36, 0.24), "rust_steel", 48)
	_register_builtin_block(44, "navy_steel", "Navy Steel", Color(0.21, 0.38, 0.61), "navy_steel", 48)
	_register_builtin_block(45, "circuit_plate", "Circuit Plate", Color(0.18, 0.68, 0.67), "circuit_plate", 48)
	_register_builtin_block(46, "bronze_plate", "Bronze Plate", Color(0.7, 0.48, 0.27), "bronze_plate", 48)
	_register_builtin_block(47, "obsidian_glass", "Obsidian Glass", Color(0.22, 0.14, 0.3), "obsidian_glass", 48)
	_register_builtin_block(48, "prism_glass", "Prism Glass", Color(0.72, 0.94, 1.0), "prism_glass", 48)
	_register_builtin_block(49, "ember_crystal", "Ember Crystal", Color(1.0, 0.54, 0.22), "ember_crystal", 32)
	_register_builtin_block(50, "storm_crystal", "Storm Crystal", Color(0.3, 0.68, 1.0), "storm_crystal", 32)
	_register_builtin_block(51, "aurora_crystal", "Aurora Crystal", Color(0.34, 1.0, 0.78), "aurora_crystal", 32)
	_register_builtin_block(52, "dune_clay", "Dune Clay", Color(0.82, 0.66, 0.49), "dune_clay")
	_register_builtin_block(53, "canyon_stone", "Canyon Stone", Color(0.77, 0.42, 0.28), "canyon_stone")
	_register_builtin_block(54, "reef_stone", "Reef Stone", Color(0.31, 0.45, 0.41), "reef_stone")
	_register_builtin_block(55, "ash_basalt", "Ash Basalt", Color(0.22, 0.22, 0.24), "ash_basalt")
	_register_builtin_block(56, "volcanic_brick", "Volcanic Brick", Color(0.41, 0.18, 0.16), "volcanic_brick")
	_register_builtin_block(57, "frost_slate", "Frost Slate", Color(0.55, 0.63, 0.71), "frost_slate")
	_register_builtin_block(58, "glacier_tile", "Glacier Tile", Color(0.67, 0.88, 0.98), "glacier_tile")
	_register_builtin_block(59, "bark_block", "Bark Block", Color(0.38, 0.26, 0.18), "bark_block")
	_register_builtin_block(60, "dark_timber", "Dark Timber", Color(0.26, 0.18, 0.13), "dark_timber")
	_register_builtin_block(61, "old_planks", "Old Planks", Color(0.55, 0.44, 0.34), "old_planks")
	_register_builtin_block(62, "moss_wood_block", "Moss Wood", Color(0.32, 0.36, 0.24), "moss_wood_block")
	_register_builtin_block(63, "carved_sandstone", "Carved Sandstone", Color(0.89, 0.78, 0.59), "carved_sandstone")
	_register_builtin_block(64, "scarlet_sandstone", "Scarlet Sandstone", Color(0.83, 0.47, 0.31), "scarlet_sandstone")
	_register_builtin_block(65, "white_citadel_brick", "White Citadel Brick", Color(0.92, 0.93, 0.9), "white_citadel_brick")
	_register_builtin_block(66, "checkered_tile", "Checkered Tile", Color(0.8, 0.79, 0.75), "checkered_tile")
	_register_builtin_block(67, "industrial_grate", "Industrial Grate", Color(0.51, 0.45, 0.39), "industrial_grate", 48)
	_register_builtin_block(68, "ancient_metal", "Ancient Metal", Color(0.46, 0.33, 0.24), "ancient_metal", 48)
	_register_builtin_block(69, "ceramic_blue", "Ceramic Blue", Color(0.37, 0.66, 0.9), "ceramic_blue")
	_register_builtin_block(70, "ceramic_brown", "Ceramic Brown", Color(0.63, 0.47, 0.34), "ceramic_brown")
	_register_builtin_block(71, "plaster_stone", "Plaster Stone", Color(0.78, 0.75, 0.69), "plaster_stone")
	_register_builtin_block(72, "moss_concrete", "Moss Concrete", Color(0.42, 0.49, 0.43), "moss_concrete")
	_register_builtin_block(73, "rock_tile", "Rock Tile", Color(0.48, 0.49, 0.46), "rock_tile")
	_register_builtin_block(74, "marble_tile", "Marble Tile", Color(0.94, 0.94, 0.96), "marble_tile")
	_register_builtin_block(75, "city_brick", "City Brick", Color(0.61, 0.4, 0.34), "city_brick")


static func set_texture_quality_tier(tier: String) -> void:
	var normalized_tier := tier.strip_edges().to_lower()
	if normalized_tier.is_empty():
		normalized_tier = "high"
	if _texture_quality_tier == normalized_tier:
		return
	_texture_quality_tier = normalized_tier
	_terrain_materials.clear()
	_prop_materials.clear()


static func apply_mod_blocks(block_entries: Array) -> void:
	reset_runtime_content()

	for entry_variant in block_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var block_key := String(entry.get("key", "")).strip_edges().to_lower()
		if block_key.is_empty() or _key_to_block_id.has(block_key):
			continue

		var block_id := _next_runtime_block_id
		_next_runtime_block_id += 1

		_block_definitions[block_id] = {
			"id": block_id,
			"key": block_key,
			"display_name": String(entry.get("display_name", block_key.capitalize())),
			"stack_limit": max(1, int(entry.get("stack_limit", DEFAULT_STACK_LIMIT))),
			"item_color": _parse_color(entry.get("item_color", entry.get("color", "#c9d1d9")), Color(0.78, 0.82, 0.85)),
			"material_profile": String(entry.get("base", "custom")).to_lower(),
			"material_color": _parse_color(entry.get("color", "#c9d1d9"), Color(0.78, 0.82, 0.85)),
			"roughness": clampf(float(entry.get("roughness", 0.6)), 0.02, 1.0),
			"metallic": clampf(float(entry.get("metallic", 0.0)), 0.0, 1.0),
			"emission_color": _parse_color(entry.get("emission_color", "#000000"), Color.BLACK),
			"emission_energy": max(0.0, float(entry.get("emission_energy", 0.0))),
			"placeable": bool(entry.get("placeable", true)),
			"drop_block_id": block_id,
		}
		_key_to_block_id[block_key] = block_id
		_display_order.append(block_id)


static func get_hotbar_size() -> int:
	return DEFAULT_HOTBAR_SIZE


static func get_hotbar_block_ids() -> Array:
	return get_placeable_block_ids()


static func get_hotbar_display_names() -> Array:
	var names := []
	for block_id in get_placeable_block_ids():
		names.append(get_display_name(int(block_id)))
	return names


static func get_placeable_block_ids() -> Array:
	_ensure_registry()
	var block_ids := []
	for block_id_variant in _display_order:
		var block_id := int(block_id_variant)
		if is_placeable(block_id):
			block_ids.append(block_id)
	return block_ids


static func get_renderable_block_ids() -> Array:
	_ensure_registry()
	var block_ids := []
	for block_id_variant in _display_order:
		block_ids.append(int(block_id_variant))
	return block_ids


static func get_all_block_ids() -> Array:
	return get_renderable_block_ids()


static func get_display_name(block_id: int) -> String:
	_ensure_registry()
	var definition: Dictionary = _block_definitions.get(block_id, {})
	return String(definition.get("display_name", "Unknown"))


static func get_item_color(block_id: int) -> Color:
	_ensure_registry()
	var definition: Dictionary = _block_definitions.get(block_id, {})
	return definition.get("item_color", Color(0.78, 0.82, 0.85))


static func get_stack_limit(block_id: int) -> int:
	_ensure_registry()
	var definition: Dictionary = _block_definitions.get(block_id, {})
	return max(1, int(definition.get("stack_limit", DEFAULT_STACK_LIMIT)))


static func is_placeable(block_id: int) -> bool:
	_ensure_registry()
	var definition: Dictionary = _block_definitions.get(block_id, {})
	return bool(definition.get("placeable", true))


static func get_drop_block_id(block_id: int) -> int:
	_ensure_registry()
	var definition: Dictionary = _block_definitions.get(block_id, {})
	return int(definition.get("drop_block_id", block_id))


static func get_block_definition(block_id: int) -> Dictionary:
	_ensure_registry()
	return (_block_definitions.get(block_id, {}) as Dictionary).duplicate(true)


static func get_block_key(block_id: int) -> String:
	_ensure_registry()
	var definition: Dictionary = _block_definitions.get(block_id, {})
	return String(definition.get("key", ""))


static func get_break_duration(block_id: int) -> float:
	var block_key := get_block_key(block_id)
	if block_key.is_empty():
		return 0.7

	if block_key in ["grass", "dirt", "sand", "snow", "mud", "clay", "dune_clay", "red_sand"]:
		return 0.35
	if block_key in ["wood", "bark_block", "dark_timber", "old_planks", "moss_wood_block"]:
		return 0.55
	if block_key.contains("glass") or block_key.contains("ice"):
		return 0.3
	if block_key.contains("crystal") or block_key == "amethyst":
		return 0.7
	if (
		block_key.contains("metal")
		or block_key.contains("steel")
		or block_key.contains("plate")
		or block_key.contains("alloy")
		or block_key.contains("circuit")
	):
		return 1.05
	if (
		block_key.contains("stone")
		or block_key.contains("brick")
		or block_key.contains("slate")
		or block_key.contains("granite")
		or block_key.contains("marble")
		or block_key.contains("basalt")
		or block_key.contains("shale")
		or block_key.contains("rock")
		or block_key.contains("concrete")
		or block_key.contains("sandstone")
		or block_key.contains("terracotta")
		or block_key.contains("mosaic")
		or block_key.contains("tile")
	):
		return 0.85
	return 0.65


static func get_block_id_by_key(block_key: String) -> int:
	_ensure_registry()
	return int(_key_to_block_id.get(block_key.to_lower(), AIR))


static func create_terrain_materials() -> Dictionary:
	_ensure_registry()
	if not _terrain_materials.is_empty():
		return _terrain_materials

	var profile_materials := {}
	profile_materials["grass"] = _make_material_set(
		_make_polyhaven_material("leafy_grass", Color(0.96, 1.0, 0.96), 0.82, 0.0, 0.18, 0.35, "hero"),
		_make_polyhaven_material("dirt", Color(0.87, 0.91, 0.83), 0.96, 0.0, 0.2, 0.3, "hero"),
		_make_polyhaven_material("dirt", Color(0.97, 0.95, 0.93), 0.96, 0.0, 0.18, 0.28, "hero")
	)
	profile_materials["dirt"] = _make_material_set(
		_make_polyhaven_material("dirt", Color(0.97, 0.95, 0.93), 0.96, 0.0, 0.18, 0.28, "hero")
	)
	profile_materials["stone"] = _make_material_set(
		_make_polyhaven_material("rock_wall_10", Color(0.96, 0.97, 1.0), 0.76, 0.0, 0.2, 0.32, "hero")
	)
	profile_materials["sand"] = _make_material_set(
		_make_polyhaven_material("sand_02", Color(1.0, 0.99, 0.95), 0.9, 0.0, 0.22, 0.24, "hero")
	)
	profile_materials["glow"] = _make_material_set(
		_make_standard_material(Color(0.78, 0.89, 1.0), 0.1, 0.18, Color(0.42, 0.77, 1.0), 2.4)
	)
	profile_materials["wood"] = _make_material_set(
		_make_polyhaven_material("bark_platanus", Color(0.98, 0.96, 0.92), 0.94, 0.0, 0.24, 0.34, "hero")
	)
	profile_materials["snow"] = _make_material_set(
		_make_polyhaven_material("snow_03", Color(1.0, 1.0, 1.0), 0.76, 0.0, 0.28, 0.22, "hero")
	)
	profile_materials["mud"] = _make_material_set(
		_make_polyhaven_material("brown_mud_02", Color(0.95, 0.92, 0.9), 0.92, 0.0, 0.2, 0.38)
	)
	profile_materials["clay"] = _make_material_set(
		_make_polyhaven_material("clay_floor_001", Color(0.95, 0.93, 0.92), 0.9, 0.0, 0.22, 0.26, "4k")
	)
	profile_materials["mossy_stone"] = _make_material_set(
		_make_polyhaven_material("mossy_cobblestone", Color(0.96, 1.0, 0.96), 0.84, 0.02, 0.22, 0.28)
	)
	profile_materials["slate"] = _make_material_set(
		_make_polyhaven_material("slate_floor_03", Color(0.95, 0.97, 1.0), 0.72, 0.04, 0.24, 0.32, "hero")
	)
	profile_materials["granite"] = _make_material_set(
		_make_polyhaven_material("granite_wall", Color(0.97, 0.95, 0.94), 0.7, 0.02, 0.22, 0.32)
	)
	profile_materials["marble"] = _make_material_set(
		_make_polyhaven_material("marble_01", Color(1.0, 1.0, 1.0), 0.42, 0.05, 0.26, 0.18, "hero")
	)
	profile_materials["sandstone"] = _make_material_set(
		_make_polyhaven_material("white_sandstone_blocks_02", Color(0.99, 0.97, 0.95), 0.88, 0.0, 0.22, 0.26)
	)
	profile_materials["red_sand"] = _make_material_set(
		_make_polyhaven_material("sand_02", Color(0.94, 0.62, 0.44), 0.9, 0.0, 0.22, 0.24, "hero")
	)
	profile_materials["basalt"] = _make_material_set(
		_make_polyhaven_material("rock_wall_10", Color(0.5, 0.52, 0.56), 0.86, 0.04, 0.2, 0.3, "4k")
	)
	profile_materials["obsidian"] = _make_material_set(_make_obsidian_material())
	profile_materials["copper"] = _make_material_set(
		_make_polyhaven_material("metal_plate_02", Color(1.0, 0.72, 0.55), 0.36, 0.78, 0.3, 0.2)
	)
	profile_materials["cobalt"] = _make_material_set(
		_make_polyhaven_material("metal_plate_02", Color(0.66, 0.84, 1.0), 0.32, 0.82, 0.3, 0.22)
	)
	profile_materials["amethyst"] = _make_material_set(
		_make_energy_material(Color(0.32, 0.17, 0.58, 0.95), Color(0.84, 0.58, 1.0, 1.0), 0.18, 0.12, 2.25, 5.5, 1.3)
	)
	profile_materials["stone_brick"] = _make_material_set(
		_make_polyhaven_material("stone_brick_wall_001", Color(0.97, 0.98, 1.0), 0.74, 0.02, 0.24, 0.28)
	)
	profile_materials["mossy_brick"] = _make_material_set(
		_make_polyhaven_material("mossy_brick", Color(0.96, 0.98, 0.94), 0.8, 0.02, 0.24, 0.28)
	)
	profile_materials["terracotta_tile"] = _make_material_set(
		_make_polyhaven_material("clay_roof_tiles_02", Color(0.99, 0.95, 0.92), 0.84, 0.0, 0.22, 0.24)
	)
	profile_materials["ice"] = _make_material_set(
		_make_translucent_material(Color(0.56, 0.76, 0.96, 1.0), Color(0.92, 0.98, 1.0, 1.0), 0.68, 0.08, 0.02, 1.1)
	)
	profile_materials["neon_grid"] = _make_material_set(
		_make_energy_material(Color(0.04, 0.08, 0.14, 0.96), Color(0.16, 0.96, 1.0, 1.0), 0.16, 0.25, 3.2, 8.0, 1.8)
	)
	profile_materials["glass"] = _make_material_set(
		_make_translucent_material(Color(0.82, 0.92, 0.98, 1.0), Color(1.0, 1.0, 1.0, 1.0), 0.38, 0.05, 0.0, 0.6)
	)
	profile_materials["frost_marble"] = _make_material_set(
		_make_polyhaven_material("marble_tiles", Color(0.9, 0.96, 1.0), 0.36, 0.04, 0.2, 0.26, "hero")
	)
	profile_materials["aurora_ice"] = _make_material_set(
		_make_translucent_material(Color(0.54, 0.94, 0.96, 1.0), Color(0.92, 1.0, 1.0, 1.0), 0.6, 0.06, 0.0, 1.4)
	)
	profile_materials["shale"] = _make_material_set(
		_make_polyhaven_material("slate_floor_03", Color(0.74, 0.74, 0.76), 0.86, 0.0, 0.22, 0.28, "4k")
	)
	profile_materials["moon_granite"] = _make_material_set(
		_make_polyhaven_material("granite_tile_03", Color(0.92, 0.96, 1.0), 0.62, 0.05, 0.24, 0.28, "4k")
	)
	profile_materials["limestone_brick"] = _make_material_set(
		_make_polyhaven_material("white_sandstone_bricks_03", Color(0.99, 0.96, 0.91), 0.74, 0.0, 0.24, 0.26, "4k")
	)
	profile_materials["travertine_tile"] = _make_material_set(
		_make_polyhaven_material("marble_tiles", Color(1.0, 0.92, 0.82), 0.5, 0.04, 0.22, 0.22, "hero")
	)
	profile_materials["cobble_road"] = _make_material_set(
		_make_polyhaven_material("cobblestone_01", Color(0.96, 0.97, 0.98), 0.8, 0.0, 0.24, 0.3, "4k")
	)
	profile_materials["ancient_cobble"] = _make_material_set(
		_make_polyhaven_material("cobblestone_01", Color(0.82, 0.74, 0.62), 0.86, 0.0, 0.24, 0.3, "4k")
	)
	profile_materials["moss_tile"] = _make_material_set(
		_make_polyhaven_material("concrete_moss", Color(0.94, 1.0, 0.95), 0.84, 0.0, 0.24, 0.26, "4k")
	)
	profile_materials["lichen_rock_block"] = _make_material_set(
		_make_polyhaven_material("lichen_rock", Color(0.96, 1.0, 0.96), 0.82, 0.0, 0.24, 0.28, "4k")
	)
	profile_materials["quartz_ceramic"] = _make_material_set(
		_make_polyhaven_material("marble_tiles", Color(1.0, 1.0, 1.0), 0.36, 0.02, 0.2, 0.2, "4k")
	)
	profile_materials["ivory_plaster"] = _make_material_set(
		_make_polyhaven_material("plaster_stone_wall_01", Color(1.0, 0.96, 0.88), 0.72, 0.0, 0.24, 0.22, "4k")
	)
	profile_materials["kiln_brick"] = _make_material_set(
		_make_polyhaven_material("brick_wall_09", Color(0.98, 0.92, 0.9), 0.76, 0.0, 0.24, 0.26, "4k")
	)
	profile_materials["royal_mosaic"] = _make_material_set(
		_make_polyhaven_material("marble_mosaic_tiles", Color(0.94, 0.97, 1.0), 0.44, 0.04, 0.2, 0.22, "4k")
	)
	profile_materials["terrazzo_lux"] = _make_material_set(
		_make_polyhaven_material("terrazzo_tiles", Color(1.0, 0.98, 0.98), 0.4, 0.03, 0.2, 0.22, "4k")
	)
	profile_materials["concrete_panel"] = _make_material_set(
		_make_polyhaven_material("concrete_block_wall", Color(0.98, 0.99, 1.0), 0.84, 0.0, 0.22, 0.24, "4k")
	)
	profile_materials["polished_concrete"] = _make_material_set(
		_make_polyhaven_material("concrete_floor_worn_001", Color(1.0, 1.0, 1.0), 0.58, 0.02, 0.22, 0.22, "4k")
	)
	profile_materials["rust_steel"] = _make_material_set(
		_make_polyhaven_material("rusty_metal_04", Color(0.98, 0.96, 0.94), 0.42, 0.72, 0.22, 0.26, "4k")
	)
	profile_materials["navy_steel"] = _make_material_set(
		_make_polyhaven_material("blue_metal_plate", Color(0.96, 1.0, 1.0), 0.3, 0.84, 0.2, 0.24, "4k")
	)
	profile_materials["circuit_plate"] = _make_material_set(
		_make_circuit_material(Color(0.08, 0.14, 0.18, 1.0), Color(0.42, 1.0, 0.86, 1.0), 0.2, 0.88, 2.8, 6.2, 1.7)
	)
	profile_materials["bronze_plate"] = _make_material_set(
		_make_polyhaven_material("metal_plate", Color(1.0, 0.82, 0.62), 0.3, 0.86, 0.2, 0.22, "4k")
	)
	profile_materials["obsidian_glass"] = _make_material_set(
		_make_translucent_material(Color(0.2, 0.12, 0.28, 1.0), Color(0.72, 0.56, 0.96, 1.0), 0.46, 0.08, 0.02, 0.9)
	)
	profile_materials["prism_glass"] = _make_material_set(
		_make_translucent_material(Color(0.7, 0.92, 1.0, 1.0), Color(1.0, 0.96, 1.0, 1.0), 0.34, 0.04, 0.0, 1.5)
	)
	profile_materials["ember_crystal"] = _make_material_set(
		_make_energy_material(Color(0.22, 0.08, 0.04, 0.95), Color(1.0, 0.52, 0.18, 1.0), 0.14, 0.14, 2.6, 6.5, 1.4)
	)
	profile_materials["storm_crystal"] = _make_material_set(
		_make_energy_material(Color(0.06, 0.12, 0.28, 0.95), Color(0.38, 0.8, 1.0, 1.0), 0.14, 0.16, 2.8, 7.2, 1.8)
	)
	profile_materials["aurora_crystal"] = _make_material_set(
		_make_energy_material(Color(0.06, 0.18, 0.14, 0.95), Color(0.36, 1.0, 0.76, 1.0), 0.14, 0.16, 2.9, 7.8, 1.6)
	)
	profile_materials["dune_clay"] = _make_material_set(
		_make_polyhaven_material("clay_floor_001", Color(1.0, 0.92, 0.78), 0.84, 0.0, 0.24, 0.24, "4k")
	)
	profile_materials["canyon_stone"] = _make_material_set(
		_make_polyhaven_material("red_sandstone_wall", Color(1.0, 0.95, 0.92), 0.8, 0.0, 0.24, 0.26, "4k")
	)
	profile_materials["reef_stone"] = _make_material_set(
		_make_polyhaven_material("lichen_rock", Color(0.98, 1.0, 0.98), 0.82, 0.02, 0.24, 0.28, "4k")
	)
	profile_materials["ash_basalt"] = _make_material_set(
		_make_polyhaven_material("rock_wall_10", Color(0.44, 0.45, 0.48), 0.88, 0.02, 0.22, 0.28, "4k")
	)
	profile_materials["volcanic_brick"] = _make_material_set(
		_make_polyhaven_material("brick_wall_09", Color(0.58, 0.42, 0.42), 0.82, 0.0, 0.24, 0.26, "4k")
	)
	profile_materials["frost_slate"] = _make_material_set(
		_make_polyhaven_material("slate_floor_03", Color(0.88, 0.96, 1.0), 0.74, 0.02, 0.24, 0.28, "hero")
	)
	profile_materials["glacier_tile"] = _make_material_set(
		_make_polyhaven_material("blue_floor_tiles_01", Color(0.96, 1.0, 1.0), 0.42, 0.02, 0.22, 0.22, "4k")
	)
	profile_materials["bark_block"] = _make_material_set(
		_make_polyhaven_material("bark_platanus", Color(0.96, 0.94, 0.9), 0.9, 0.0, 0.22, 0.34, "hero")
	)
	profile_materials["dark_timber"] = _make_material_set(
		_make_polyhaven_material("dark_wooden_planks", Color(0.58, 0.48, 0.42), 0.82, 0.0, 0.24, 0.22, "4k")
	)
	profile_materials["old_planks"] = _make_material_set(
		_make_polyhaven_material("old_wood_floor", Color(0.98, 0.98, 0.98), 0.84, 0.0, 0.24, 0.22, "4k")
	)
	profile_materials["moss_wood_block"] = _make_material_set(
		_make_polyhaven_material("moss_wood", Color(0.98, 1.0, 0.98), 0.86, 0.0, 0.24, 0.24, "4k")
	)
	profile_materials["carved_sandstone"] = _make_material_set(
		_make_polyhaven_material("sandstone_brick_wall_01", Color(1.0, 0.97, 0.92), 0.84, 0.0, 0.24, 0.24, "4k")
	)
	profile_materials["scarlet_sandstone"] = _make_material_set(
		_make_polyhaven_material("red_sandstone_wall", Color(1.0, 0.9, 0.84), 0.82, 0.0, 0.24, 0.24, "4k")
	)
	profile_materials["white_citadel_brick"] = _make_material_set(
		_make_polyhaven_material("white_sandstone_bricks_03", Color(0.98, 0.99, 1.0), 0.76, 0.0, 0.24, 0.24, "4k")
	)
	profile_materials["checkered_tile"] = _make_material_set(
		_make_polyhaven_material("checkered_pavement_tiles", Color(1.0, 0.99, 0.98), 0.62, 0.02, 0.22, 0.22, "4k")
	)
	profile_materials["industrial_grate"] = _make_material_set(
		_make_polyhaven_material("metal_grate_rusty", Color(0.98, 0.98, 0.98), 0.4, 0.8, 0.2, 0.26, "4k")
	)
	profile_materials["ancient_metal"] = _make_material_set(
		_make_polyhaven_material("rusty_metal_grid", Color(0.96, 0.94, 0.92), 0.46, 0.76, 0.22, 0.26, "4k")
	)
	profile_materials["ceramic_blue"] = _make_material_set(
		_make_polyhaven_material("blue_floor_tiles_01", Color(1.0, 1.0, 1.0), 0.48, 0.02, 0.22, 0.22, "4k")
	)
	profile_materials["ceramic_brown"] = _make_material_set(
		_make_polyhaven_material("brown_floor_tiles", Color(1.0, 0.98, 0.96), 0.56, 0.02, 0.22, 0.22, "4k")
	)
	profile_materials["plaster_stone"] = _make_material_set(
		_make_polyhaven_material("plaster_stone_wall_01", Color(0.98, 0.98, 0.96), 0.74, 0.0, 0.24, 0.22, "4k")
	)
	profile_materials["moss_concrete"] = _make_material_set(
		_make_polyhaven_material("concrete_moss", Color(0.92, 0.98, 0.94), 0.84, 0.0, 0.24, 0.24, "4k")
	)
	profile_materials["rock_tile"] = _make_material_set(
		_make_polyhaven_material("rock_tile_floor", Color(0.98, 0.98, 0.98), 0.74, 0.0, 0.24, 0.26, "4k")
	)
	profile_materials["marble_tile"] = _make_material_set(
		_make_polyhaven_material("marble_tiles", Color(1.0, 1.0, 1.0), 0.4, 0.04, 0.2, 0.22, "hero")
	)
	profile_materials["city_brick"] = _make_material_set(
		_make_polyhaven_material("brick_floor_003", Color(0.98, 0.98, 0.96), 0.78, 0.0, 0.22, 0.24, "4k")
	)

	for block_id_variant in _display_order:
		var block_id := int(block_id_variant)
		var definition: Dictionary = _block_definitions.get(block_id, {})
		var material_profile := String(definition.get("material_profile", "custom"))
		if profile_materials.has(material_profile):
			_terrain_materials[block_id] = profile_materials[material_profile]
			continue

		var custom_material := _make_standard_material(
			definition.get("material_color", Color(0.78, 0.82, 0.85)),
			float(definition.get("roughness", 0.6)),
			float(definition.get("metallic", 0.0)),
			definition.get("emission_color", Color.BLACK),
			float(definition.get("emission_energy", 0.0))
		)
		_terrain_materials[block_id] = _make_material_set(custom_material)

	return _terrain_materials


static func create_prop_materials() -> Dictionary:
	_ensure_registry()
	if not _prop_materials.is_empty():
		return _prop_materials

	_prop_materials = {
		"trunk": _make_polyhaven_material("bark_platanus", Color(0.96, 0.94, 0.92), 0.94, 0.0, 0.26, 0.34, "hero"),
		"rock": _make_polyhaven_material("granite_wall", Color(0.97, 0.96, 0.95), 0.68, 0.04, 0.26, 0.28),
		"crystal": _make_energy_material(Color(0.2, 0.28, 0.52, 0.95), Color(0.6, 0.9, 1.0, 1.0), 0.12, 0.18, 2.8, 6.0, 1.1),
		"leaf": _make_foliage_material(Color(0.18, 0.39, 0.2), Color(0.59, 0.88, 0.49), 0.08),
		"grass": _make_foliage_material(Color(0.22, 0.52, 0.25), Color(0.78, 0.97, 0.62), 0.12),
	}
	return _prop_materials


static func get_face_key_from_normal(normal: Vector3) -> StringName:
	if normal.y > 0.5:
		return &"top"
	if normal.y < -0.5:
		return &"bottom"
	return &"side"


static func get_terrain_material(block_id: int, face_key: StringName) -> Material:
	var face_materials := _get_or_create_terrain_material_set(block_id)
	if face_materials.has(face_key):
		return face_materials[face_key]
	return face_materials.get(&"side", null)


static func _get_or_create_terrain_material_set(block_id: int) -> Dictionary:
	_ensure_registry()
	if _terrain_materials.has(block_id):
		return _terrain_materials[block_id]

	var definition: Dictionary = _block_definitions.get(block_id, {})
	var material_set := _build_terrain_material_set(definition)
	_terrain_materials[block_id] = material_set
	return material_set


static func _build_terrain_material_set(definition: Dictionary) -> Dictionary:
	var material_profile := String(definition.get("material_profile", "custom"))

	match material_profile:
		"grass":
			return _make_material_set(
				_make_polyhaven_material("leafy_grass", Color(0.96, 1.0, 0.96), 0.82, 0.0, 0.18, 0.35, "hero"),
				_make_polyhaven_material("dirt", Color(0.87, 0.91, 0.83), 0.96, 0.0, 0.2, 0.3, "hero"),
				_make_polyhaven_material("dirt", Color(0.97, 0.95, 0.93), 0.96, 0.0, 0.18, 0.28, "hero")
			)
		"dirt":
			return _make_material_set(
				_make_polyhaven_material("dirt", Color(0.97, 0.95, 0.93), 0.96, 0.0, 0.18, 0.28, "hero")
			)
		"stone":
			return _make_material_set(
				_make_polyhaven_material("rock_wall_10", Color(0.96, 0.97, 1.0), 0.76, 0.0, 0.2, 0.32, "hero")
			)
		"sand":
			return _make_material_set(
				_make_polyhaven_material("sand_02", Color(1.0, 0.99, 0.95), 0.9, 0.0, 0.22, 0.24, "hero")
			)
		"glow":
			return _make_material_set(
				_make_standard_material(Color(0.78, 0.89, 1.0), 0.1, 0.18, Color(0.42, 0.77, 1.0), 2.4)
			)
		"wood":
			return _make_material_set(
				_make_polyhaven_material("bark_platanus", Color(0.98, 0.96, 0.92), 0.94, 0.0, 0.24, 0.34, "hero")
			)
		"snow":
			return _make_material_set(
				_make_polyhaven_material("snow_03", Color(1.0, 1.0, 1.0), 0.76, 0.0, 0.28, 0.22, "hero")
			)
		"mud":
			return _make_material_set(
				_make_polyhaven_material("brown_mud_02", Color(0.95, 0.92, 0.9), 0.92, 0.0, 0.2, 0.38)
			)
		"clay":
			return _make_material_set(
				_make_polyhaven_material("clay_floor_001", Color(0.95, 0.93, 0.92), 0.9, 0.0, 0.22, 0.26, "4k")
			)
		"mossy_stone":
			return _make_material_set(
				_make_polyhaven_material("mossy_cobblestone", Color(0.96, 1.0, 0.96), 0.84, 0.02, 0.22, 0.28)
			)
		"slate":
			return _make_material_set(
				_make_polyhaven_material("slate_floor_03", Color(0.95, 0.97, 1.0), 0.72, 0.04, 0.24, 0.32, "hero")
			)
		"granite":
			return _make_material_set(
				_make_polyhaven_material("granite_wall", Color(0.97, 0.95, 0.94), 0.7, 0.02, 0.22, 0.32)
			)
		"marble":
			return _make_material_set(
				_make_polyhaven_material("marble_01", Color(1.0, 1.0, 1.0), 0.42, 0.05, 0.26, 0.18, "hero")
			)
		"sandstone":
			return _make_material_set(
				_make_polyhaven_material("white_sandstone_blocks_02", Color(0.99, 0.97, 0.95), 0.88, 0.0, 0.22, 0.26)
			)
		"red_sand":
			return _make_material_set(
				_make_polyhaven_material("sand_02", Color(0.94, 0.62, 0.44), 0.9, 0.0, 0.22, 0.24, "hero")
			)
		"basalt":
			return _make_material_set(
				_make_polyhaven_material("rock_wall_10", Color(0.5, 0.52, 0.56), 0.86, 0.04, 0.2, 0.3, "4k")
			)
		"obsidian":
			return _make_material_set(_make_obsidian_material())
		"copper":
			return _make_material_set(
				_make_polyhaven_material("metal_plate_02", Color(1.0, 0.72, 0.55), 0.36, 0.78, 0.3, 0.2)
			)
		"cobalt":
			return _make_material_set(
				_make_polyhaven_material("metal_plate_02", Color(0.66, 0.84, 1.0), 0.32, 0.82, 0.3, 0.22)
			)
		"amethyst":
			return _make_material_set(
				_make_energy_material(Color(0.32, 0.17, 0.58, 0.95), Color(0.84, 0.58, 1.0, 1.0), 0.18, 0.12, 2.25, 5.5, 1.3)
			)
		"stone_brick":
			return _make_material_set(
				_make_polyhaven_material("stone_brick_wall_001", Color(0.97, 0.98, 1.0), 0.74, 0.02, 0.24, 0.28)
			)
		"mossy_brick":
			return _make_material_set(
				_make_polyhaven_material("mossy_brick", Color(0.96, 0.98, 0.94), 0.8, 0.02, 0.24, 0.28)
			)
		"terracotta_tile":
			return _make_material_set(
				_make_polyhaven_material("clay_roof_tiles_02", Color(0.99, 0.95, 0.92), 0.84, 0.0, 0.22, 0.24)
			)
		"ice":
			return _make_material_set(
				_make_translucent_material(Color(0.56, 0.76, 0.96, 1.0), Color(0.92, 0.98, 1.0, 1.0), 0.68, 0.08, 0.02, 1.1)
			)
		"neon_grid":
			return _make_material_set(
				_make_energy_material(Color(0.04, 0.08, 0.14, 0.96), Color(0.16, 0.96, 1.0, 1.0), 0.16, 0.25, 3.2, 8.0, 1.8)
			)
		"glass":
			return _make_material_set(
				_make_translucent_material(Color(0.82, 0.92, 0.98, 1.0), Color(1.0, 1.0, 1.0, 1.0), 0.38, 0.05, 0.0, 0.6)
			)
		"frost_marble":
			return _make_material_set(
				_make_polyhaven_material("marble_tiles", Color(0.9, 0.96, 1.0), 0.36, 0.04, 0.2, 0.26, "hero")
			)
		"aurora_ice":
			return _make_material_set(
				_make_translucent_material(Color(0.54, 0.94, 0.96, 1.0), Color(0.92, 1.0, 1.0, 1.0), 0.6, 0.06, 0.0, 1.4)
			)
		"shale":
			return _make_material_set(
				_make_polyhaven_material("slate_floor_03", Color(0.74, 0.74, 0.76), 0.86, 0.0, 0.22, 0.28, "4k")
			)
		"moon_granite":
			return _make_material_set(
				_make_polyhaven_material("granite_tile_03", Color(0.92, 0.96, 1.0), 0.62, 0.05, 0.24, 0.28, "4k")
			)
		"limestone_brick":
			return _make_material_set(
				_make_polyhaven_material("white_sandstone_bricks_03", Color(0.99, 0.96, 0.91), 0.74, 0.0, 0.24, 0.26, "4k")
			)
		"travertine_tile":
			return _make_material_set(
				_make_polyhaven_material("marble_tiles", Color(1.0, 0.92, 0.82), 0.5, 0.04, 0.22, 0.22, "hero")
			)
		"cobble_road":
			return _make_material_set(
				_make_polyhaven_material("cobblestone_01", Color(0.96, 0.97, 0.98), 0.8, 0.0, 0.24, 0.3, "4k")
			)
		"ancient_cobble":
			return _make_material_set(
				_make_polyhaven_material("cobblestone_01", Color(0.82, 0.74, 0.62), 0.86, 0.0, 0.24, 0.3, "4k")
			)
		"moss_tile":
			return _make_material_set(
				_make_polyhaven_material("concrete_moss", Color(0.94, 1.0, 0.95), 0.84, 0.0, 0.24, 0.26, "4k")
			)
		"lichen_rock_block":
			return _make_material_set(
				_make_polyhaven_material("lichen_rock", Color(0.96, 1.0, 0.96), 0.82, 0.0, 0.24, 0.28, "4k")
			)
		"quartz_ceramic":
			return _make_material_set(
				_make_polyhaven_material("marble_tiles", Color(1.0, 1.0, 1.0), 0.36, 0.02, 0.2, 0.2, "4k")
			)
		"ivory_plaster":
			return _make_material_set(
				_make_polyhaven_material("plaster_stone_wall_01", Color(1.0, 0.96, 0.88), 0.72, 0.0, 0.24, 0.22, "4k")
			)
		"kiln_brick":
			return _make_material_set(
				_make_polyhaven_material("brick_wall_09", Color(0.98, 0.92, 0.9), 0.76, 0.0, 0.24, 0.26, "4k")
			)
		"royal_mosaic":
			return _make_material_set(
				_make_polyhaven_material("marble_mosaic_tiles", Color(0.94, 0.97, 1.0), 0.44, 0.04, 0.2, 0.22, "4k")
			)
		"terrazzo_lux":
			return _make_material_set(
				_make_polyhaven_material("terrazzo_tiles", Color(1.0, 0.98, 0.98), 0.4, 0.03, 0.2, 0.22, "4k")
			)
		"concrete_panel":
			return _make_material_set(
				_make_polyhaven_material("concrete_block_wall", Color(0.98, 0.99, 1.0), 0.84, 0.0, 0.22, 0.24, "4k")
			)
		"polished_concrete":
			return _make_material_set(
				_make_polyhaven_material("concrete_floor_worn_001", Color(1.0, 1.0, 1.0), 0.58, 0.02, 0.22, 0.22, "4k")
			)
		"rust_steel":
			return _make_material_set(
				_make_polyhaven_material("rusty_metal_04", Color(0.98, 0.96, 0.94), 0.42, 0.72, 0.22, 0.26, "4k")
			)
		"navy_steel":
			return _make_material_set(
				_make_polyhaven_material("blue_metal_plate", Color(0.96, 1.0, 1.0), 0.3, 0.84, 0.2, 0.24, "4k")
			)
		"circuit_plate":
			return _make_material_set(
				_make_circuit_material(Color(0.08, 0.14, 0.18, 1.0), Color(0.42, 1.0, 0.86, 1.0), 0.2, 0.88, 2.8, 6.2, 1.7)
			)
		"bronze_plate":
			return _make_material_set(
				_make_polyhaven_material("metal_plate", Color(1.0, 0.82, 0.62), 0.3, 0.86, 0.2, 0.22, "4k")
			)
		"obsidian_glass":
			return _make_material_set(
				_make_translucent_material(Color(0.2, 0.12, 0.28, 1.0), Color(0.72, 0.56, 0.96, 1.0), 0.46, 0.08, 0.02, 0.9)
			)
		"prism_glass":
			return _make_material_set(
				_make_translucent_material(Color(0.7, 0.92, 1.0, 1.0), Color(1.0, 0.96, 1.0, 1.0), 0.34, 0.04, 0.0, 1.5)
			)
		"ember_crystal":
			return _make_material_set(
				_make_energy_material(Color(0.22, 0.08, 0.04, 0.95), Color(1.0, 0.52, 0.18, 1.0), 0.14, 0.14, 2.6, 6.5, 1.4)
			)
		"storm_crystal":
			return _make_material_set(
				_make_energy_material(Color(0.06, 0.12, 0.28, 0.95), Color(0.38, 0.8, 1.0, 1.0), 0.14, 0.16, 2.8, 7.2, 1.8)
			)
		"aurora_crystal":
			return _make_material_set(
				_make_energy_material(Color(0.06, 0.18, 0.14, 0.95), Color(0.36, 1.0, 0.76, 1.0), 0.14, 0.16, 2.9, 7.8, 1.6)
			)
		"dune_clay":
			return _make_material_set(
				_make_polyhaven_material("clay_floor_001", Color(1.0, 0.92, 0.78), 0.84, 0.0, 0.24, 0.24, "4k")
			)
		"canyon_stone":
			return _make_material_set(
				_make_polyhaven_material("red_sandstone_wall", Color(1.0, 0.95, 0.92), 0.8, 0.0, 0.24, 0.26, "4k")
			)
		"reef_stone":
			return _make_material_set(
				_make_polyhaven_material("lichen_rock", Color(0.98, 1.0, 0.98), 0.82, 0.02, 0.24, 0.28, "4k")
			)
		"ash_basalt":
			return _make_material_set(
				_make_polyhaven_material("rock_wall_10", Color(0.44, 0.45, 0.48), 0.88, 0.02, 0.22, 0.28, "4k")
			)
		"volcanic_brick":
			return _make_material_set(
				_make_polyhaven_material("brick_wall_09", Color(0.58, 0.42, 0.42), 0.82, 0.0, 0.24, 0.26, "4k")
			)
		"frost_slate":
			return _make_material_set(
				_make_polyhaven_material("slate_floor_03", Color(0.88, 0.96, 1.0), 0.74, 0.02, 0.24, 0.28, "hero")
			)
		"glacier_tile":
			return _make_material_set(
				_make_polyhaven_material("blue_floor_tiles_01", Color(0.96, 1.0, 1.0), 0.42, 0.02, 0.22, 0.22, "4k")
			)
		"bark_block":
			return _make_material_set(
				_make_polyhaven_material("bark_platanus", Color(0.96, 0.94, 0.9), 0.9, 0.0, 0.22, 0.34, "hero")
			)
		"dark_timber":
			return _make_material_set(
				_make_polyhaven_material("dark_wooden_planks", Color(0.58, 0.48, 0.42), 0.82, 0.0, 0.24, 0.22, "4k")
			)
		"old_planks":
			return _make_material_set(
				_make_polyhaven_material("old_wood_floor", Color(0.98, 0.98, 0.98), 0.84, 0.0, 0.24, 0.22, "4k")
			)
		"moss_wood_block":
			return _make_material_set(
				_make_polyhaven_material("moss_wood", Color(0.98, 1.0, 0.98), 0.86, 0.0, 0.24, 0.24, "4k")
			)
		"carved_sandstone":
			return _make_material_set(
				_make_polyhaven_material("sandstone_brick_wall_01", Color(1.0, 0.97, 0.92), 0.84, 0.0, 0.24, 0.24, "4k")
			)
		"scarlet_sandstone":
			return _make_material_set(
				_make_polyhaven_material("red_sandstone_wall", Color(1.0, 0.9, 0.84), 0.82, 0.0, 0.24, 0.24, "4k")
			)
		"white_citadel_brick":
			return _make_material_set(
				_make_polyhaven_material("white_sandstone_bricks_03", Color(0.98, 0.99, 1.0), 0.76, 0.0, 0.24, 0.24, "4k")
			)
		"checkered_tile":
			return _make_material_set(
				_make_polyhaven_material("checkered_pavement_tiles", Color(1.0, 0.99, 0.98), 0.62, 0.02, 0.22, 0.22, "4k")
			)
		"industrial_grate":
			return _make_material_set(
				_make_polyhaven_material("metal_grate_rusty", Color(0.98, 0.98, 0.98), 0.4, 0.8, 0.2, 0.26, "4k")
			)
		"ancient_metal":
			return _make_material_set(
				_make_polyhaven_material("rusty_metal_grid", Color(0.96, 0.94, 0.92), 0.46, 0.76, 0.22, 0.26, "4k")
			)
		"ceramic_blue":
			return _make_material_set(
				_make_polyhaven_material("blue_floor_tiles_01", Color(1.0, 1.0, 1.0), 0.48, 0.02, 0.22, 0.22, "4k")
			)
		"ceramic_brown":
			return _make_material_set(
				_make_polyhaven_material("brown_floor_tiles", Color(1.0, 0.98, 0.96), 0.56, 0.02, 0.22, 0.22, "4k")
			)
		"plaster_stone":
			return _make_material_set(
				_make_polyhaven_material("plaster_stone_wall_01", Color(0.98, 0.98, 0.96), 0.74, 0.0, 0.24, 0.22, "4k")
			)
		"moss_concrete":
			return _make_material_set(
				_make_polyhaven_material("concrete_moss", Color(0.92, 0.98, 0.94), 0.84, 0.0, 0.24, 0.24, "4k")
			)
		"rock_tile":
			return _make_material_set(
				_make_polyhaven_material("rock_tile_floor", Color(0.98, 0.98, 0.98), 0.74, 0.0, 0.24, 0.26, "4k")
			)
		"marble_tile":
			return _make_material_set(
				_make_polyhaven_material("marble_tiles", Color(1.0, 1.0, 1.0), 0.4, 0.04, 0.2, 0.22, "hero")
			)
		"city_brick":
			return _make_material_set(
				_make_polyhaven_material("brick_floor_003", Color(0.98, 0.98, 0.96), 0.78, 0.0, 0.22, 0.24, "4k")
			)
		_:
			var custom_material := _make_standard_material(
				definition.get("material_color", Color(0.78, 0.82, 0.85)),
				float(definition.get("roughness", 0.6)),
				float(definition.get("metallic", 0.0)),
				definition.get("emission_color", Color.BLACK),
				float(definition.get("emission_energy", 0.0))
			)
			return _make_material_set(custom_material)


static func _register_builtin_block(
	block_id: int,
	block_key: String,
	display_name: String,
	item_color: Color,
	material_profile: String,
	stack_limit: int = DEFAULT_STACK_LIMIT
) -> void:
	_block_definitions[block_id] = {
		"id": block_id,
		"key": block_key,
		"display_name": display_name,
		"stack_limit": stack_limit,
		"item_color": item_color,
		"material_profile": material_profile,
		"material_color": item_color,
		"roughness": 0.6,
		"metallic": 0.0,
		"emission_color": Color.BLACK,
		"emission_energy": 0.0,
		"placeable": true,
		"drop_block_id": block_id,
	}
	_key_to_block_id[block_key] = block_id
	_display_order.append(block_id)


static func _ensure_registry() -> void:
	if not _registry_ready:
		reset_runtime_content()


static func _make_material_set(top_material: Material, side_material: Material = null, bottom_material: Material = null) -> Dictionary:
	var resolved_side := side_material if side_material != null else top_material
	var resolved_bottom := bottom_material if bottom_material != null else resolved_side
	return {
		"top": top_material,
		"side": resolved_side,
		"bottom": resolved_bottom,
	}


static func _make_standard_material(
	color: Color,
	roughness: float,
	metallic: float,
	emission_color: Color = Color.BLACK,
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material


static func _make_obsidian_material() -> StandardMaterial3D:
	var material := _make_standard_material(Color(0.08, 0.06, 0.12), 0.08, 0.14, Color(0.12, 0.08, 0.2), 0.28)
	material.clearcoat_enabled = true
	material.clearcoat = 0.8
	material.clearcoat_roughness = 0.12
	return material


static func _make_polyhaven_material(
	asset_slug: String,
	color_tint: Color,
	roughness: float,
	metallic: float,
	texture_scale: float,
	normal_scale: float = 0.35,
	size_label: String = "2k"
) -> Material:
	var resolved_size := _resolve_polyhaven_size(asset_slug, size_label)
	var base_path := "res://assets/textures/polyhaven/%s/%s" % [asset_slug, asset_slug]
	return _make_pbr_terrain_material(
		"%s_diff_%s.jpg" % [base_path, resolved_size],
		"%s_nor_gl_%s.png" % [base_path, resolved_size],
		"%s_rough_%s.jpg" % [base_path, resolved_size],
		color_tint,
		roughness,
		metallic,
		texture_scale,
		normal_scale
	)


static func _make_pbr_terrain_material(
	albedo_path: String,
	normal_path: String,
	roughness_path: String,
	color_tint: Color,
	roughness: float,
	metallic: float,
	texture_scale: float,
	normal_scale: float = 0.35
) -> Material:
	if not ResourceLoader.exists(albedo_path):
		return _make_standard_material(color_tint, roughness, metallic)

	var material := _make_standard_material(color_tint, roughness, metallic)
	material.vertex_color_use_as_albedo = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3(texture_scale, texture_scale, texture_scale)
	material.normal_enabled = true
	material.normal_scale = normal_scale

	var albedo_texture := _load_texture(albedo_path)
	var normal_texture := _load_texture(normal_path)
	var rough_texture := _load_texture(roughness_path)

	if albedo_texture != null:
		material.albedo_texture = albedo_texture
	if normal_texture != null:
		material.normal_texture = normal_texture
	if rough_texture != null:
		material.roughness_texture = rough_texture

	return material


static func _make_foliage_material(color_a: Color, color_b: Color, sway_strength: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://materials/foliage.gdshader")
	material.set_shader_parameter("color_a", color_a)
	material.set_shader_parameter("color_b", color_b)
	material.set_shader_parameter("sway_strength", sway_strength)
	return material


static func _make_energy_material(
	base_color: Color,
	pulse_color: Color,
	roughness: float,
	metallic: float,
	emission_energy: float,
	grid_scale: float,
	pulse_speed: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://materials/energy_block.gdshader")
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("pulse_color", pulse_color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("emission_energy", emission_energy)
	material.set_shader_parameter("grid_scale", grid_scale)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	return material


static func _make_circuit_material(
	base_color: Color,
	line_color: Color,
	roughness: float,
	metallic: float,
	emission_energy: float,
	line_scale: float,
	pulse_speed: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://materials/circuit_block.gdshader")
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("line_color", line_color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("emission_energy", emission_energy)
	material.set_shader_parameter("line_scale", line_scale)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	return material


static func _make_translucent_material(
	tint_color: Color,
	rim_color: Color,
	alpha: float,
	roughness: float,
	metallic: float,
	shimmer_speed: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://materials/translucent_block.gdshader")
	material.set_shader_parameter("tint_color", tint_color)
	material.set_shader_parameter("rim_color", rim_color)
	material.set_shader_parameter("alpha_strength", alpha)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("shimmer_speed", shimmer_speed)
	return material


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


static func _resolve_polyhaven_size(asset_slug: String, requested_size: String) -> String:
	var normalized_requested := requested_size.strip_edges().to_lower()
	var candidates: Array[String] = []

	match normalized_requested:
		"hero":
			if _texture_quality_tier == "ultra":
				candidates = ["8k", "4k", "2k"]
			elif _texture_quality_tier == "balanced":
				candidates = ["4k", "2k", "8k"]
			else:
				candidates = ["8k", "4k", "2k"]
		"ultra":
			candidates = ["8k", "4k", "2k"]
		"high":
			candidates = ["4k", "2k", "8k"]
		"balanced":
			candidates = ["2k", "4k", "8k"]
		"full_hd":
			candidates = ["1k", "2k", "4k", "8k"]
		"low":
			candidates = ["1k", "2k", "4k", "8k"]
		_:
			candidates = [normalized_requested, "4k", "2k"]

	for candidate in candidates:
		var jpg_path := "res://assets/textures/polyhaven/%s/%s_diff_%s.jpg" % [asset_slug, asset_slug, candidate]
		var png_path := "res://assets/textures/polyhaven/%s/%s_diff_%s.png" % [asset_slug, asset_slug, candidate]
		if ResourceLoader.exists(jpg_path) or ResourceLoader.exists(png_path):
			return candidate

	return "2k"


static func _parse_color(raw_value, fallback: Color) -> Color:
	if raw_value is Color:
		return raw_value

	var text := String(raw_value).strip_edges()
	if text.is_empty():
		return fallback

	return Color.from_string(text, fallback)
