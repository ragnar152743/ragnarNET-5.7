extends Node3D
class_name DayNightCycle

var environment: Environment
var sky_material: ProceduralSkyMaterial

var sun: DirectionalLight3D
var moon: DirectionalLight3D

var day_length_seconds := 300.0
var time_of_day := 0.47
var rain_intensity := 0.0
var storm_intensity := 0.0
var lightning_flash := 0.0
var shadow_distance := 180.0


func _ready() -> void:
	_build_lights()
	_apply_lighting()


func configure(p_environment: Environment, p_sky_material: ProceduralSkyMaterial) -> void:
	environment = p_environment
	sky_material = p_sky_material
	_apply_lighting()


func apply_render_profile(profile: Dictionary) -> void:
	shadow_distance = float(profile.get("shadow_distance", shadow_distance))
	_apply_shadow_quality()
	_apply_lighting()


func set_weather_state(rain: float, storm: float, lightning: float) -> void:
	rain_intensity = clampf(rain, 0.0, 1.0)
	storm_intensity = clampf(storm, 0.0, 1.0)
	lightning_flash = clampf(lightning, 0.0, 1.0)


func _process(delta: float) -> void:
	time_of_day = wrapf(time_of_day + delta / day_length_seconds, 0.0, 1.0)
	lightning_flash = move_toward(lightning_flash, 0.0, delta * 2.5)
	_apply_lighting()


func _build_lights() -> void:
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		sun.shadow_enabled = true
		sun.light_volumetric_fog_energy = 1.9
		add_child(sun)

	if moon == null:
		moon = DirectionalLight3D.new()
		moon.name = "Moon"
		moon.shadow_enabled = true
		moon.light_volumetric_fog_energy = 0.6
		add_child(moon)

	_apply_shadow_quality()


func _apply_shadow_quality() -> void:
	if sun == null or moon == null:
		return

	for light in [sun, moon]:
		_try_set_property(light, "shadow_blur", 0.55)
		_try_set_property(light, "shadow_bias", 0.02)
		_try_set_property(light, "shadow_normal_bias", 1.15)
		_try_set_property(light, "light_angular_distance", 0.6 if light == sun else 0.25)
		_try_set_property(light, "directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
		_try_set_property(light, "directional_shadow_blend_splits", true)
		_try_set_property(light, "directional_shadow_fade_start", 0.88)
		_try_set_property(light, "directional_shadow_max_distance", shadow_distance)
		_try_set_property(light, "directional_shadow_split_1", 0.08)
		_try_set_property(light, "directional_shadow_split_2", 0.22)
		_try_set_property(light, "directional_shadow_split_3", 0.5)


func _apply_lighting() -> void:
	if sun == null or moon == null:
		return

	var sun_angle := time_of_day * TAU - PI * 0.5
	var sun_height := sin(sun_angle)
	var daylight: float = clampf((sun_height + 0.16) / 1.16, 0.0, 1.0)
	var night_factor: float = 1.0 - daylight
	var dusk_weight := 1.0 - absf(daylight * 2.0 - 1.0)
	var storm_darkness := rain_intensity * 0.24 + storm_intensity * 0.32

	sun.rotation = Vector3(sun_angle, deg_to_rad(-28.0), 0.0)
	moon.rotation = Vector3(sun_angle + PI, deg_to_rad(24.0), 0.0)

	sun.light_energy = max(0.0, lerpf(0.16, 4.85, daylight) * (1.0 - storm_darkness) + lightning_flash * 1.8)
	sun.light_color = Color(1.0, 0.74, 0.58).lerp(Color(1.0, 0.97, 0.93), daylight).lerp(Color(0.78, 0.82, 0.88), storm_intensity * 0.7)
	moon.light_energy = lerpf(0.78, 0.08, daylight) * (1.0 - rain_intensity * 0.2) + lightning_flash * 0.35
	moon.light_color = Color(0.52, 0.62, 0.9).lerp(Color(0.62, 0.72, 0.98), night_factor * 0.45 + storm_intensity * 0.25)

	if environment == null or sky_material == null:
		return

	environment.ambient_light_energy = lerpf(1.18, 1.82, daylight) * (1.0 - storm_darkness * 0.4) + lightning_flash * 0.26
	environment.tonemap_exposure = lerpf(1.1, 1.18, daylight) - storm_intensity * 0.03 + lightning_flash * 0.05
	environment.fog_density = lerpf(0.0056, 0.003, daylight) + rain_intensity * 0.0015
	environment.fog_light_color = Color(0.16, 0.22, 0.32).lerp(Color(1.0, 0.82, 0.62), daylight).lerp(Color(0.56, 0.64, 0.74), storm_intensity)
	environment.volumetric_fog_density = lerpf(0.0105, 0.0082, daylight) + rain_intensity * 0.0034 + night_factor * 0.0006
	environment.volumetric_fog_emission = Color(0.12, 0.16, 0.22).lerp(Color(0.28, 0.22, 0.15), daylight).lerp(Color(0.14, 0.16, 0.18), storm_intensity)

	sky_material.sky_top_color = Color(0.08, 0.12, 0.2).lerp(Color(0.22, 0.56, 0.98), daylight).lerp(Color(0.38, 0.36, 0.4), storm_intensity * 0.65)
	sky_material.sky_horizon_color = Color(0.3, 0.28, 0.4).lerp(Color(0.99, 0.84, 0.62), daylight).lerp(Color(0.54, 0.58, 0.64), storm_intensity * 0.72 + dusk_weight * 0.08)
	sky_material.ground_horizon_color = Color(0.14, 0.14, 0.18).lerp(Color(0.42, 0.34, 0.26), daylight)
	sky_material.ground_bottom_color = Color(0.08, 0.08, 0.1).lerp(Color(0.19, 0.16, 0.14), daylight)
	sky_material.energy_multiplier = lerpf(1.18, 1.82, daylight) * (1.0 - storm_darkness * 0.3) + lightning_flash * 0.08


func _try_set_property(target: Object, property_name: String, value) -> void:
	if target == null:
		return
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return
