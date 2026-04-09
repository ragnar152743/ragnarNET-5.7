extends CanvasLayer
class_name MainMenuLayer

signal slot_new_requested(slot_id: int)
signal slot_load_requested(slot_id: int)
signal slot_delete_requested(slot_id: int)
signal lan_join_requested(session: Dictionary)
signal quit_requested()
signal graphics_settings_changed(settings: Dictionary)

var root: Control
var slot_list: VBoxContainer
var loading_panel: PanelContainer
var loading_title: Label
var loading_detail: Label
var loading_bar: ProgressBar
var graphics_option: OptionButton
var auto_checkbox: CheckBox
var graphics_status: Label
var app_name_label: Label
var app_version_label: Label
var system_profile_label: Label
var lan_status_label: Label
var lan_session_list: VBoxContainer

var busy := false


func _ready() -> void:
	_build_ui()


func set_slots(slot_entries: Array[Dictionary]) -> void:
	if slot_list == null:
		return

	for child in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()

	for entry in slot_entries:
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.add_theme_stylebox_override("panel", _card_style())
		slot_list.add_child(slot_panel)

		var slot_margin: MarginContainer = MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 20)
		slot_margin.add_theme_constant_override("margin_right", 20)
		slot_margin.add_theme_constant_override("margin_top", 18)
		slot_margin.add_theme_constant_override("margin_bottom", 18)
		slot_panel.add_child(slot_margin)

		var slot_row: HBoxContainer = HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 18)
		slot_margin.add_child(slot_row)

		var text_stack: VBoxContainer = VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.add_theme_constant_override("separation", 6)
		slot_row.add_child(text_stack)

		var title: Label = Label.new()
		title.text = String(entry.get("title", "World"))
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		text_stack.add_child(title)

		var subtitle: Label = Label.new()
		subtitle.text = String(entry.get("subtitle", ""))
		subtitle.add_theme_color_override("font_color", Color(0.58, 0.78, 0.9))
		text_stack.add_child(subtitle)

		var details: Label = Label.new()
		details.text = String(entry.get("details", ""))
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_theme_color_override("font_color", Color(0.72, 0.8, 0.88))
		text_stack.add_child(details)

		var button_row: VBoxContainer = VBoxContainer.new()
		button_row.add_theme_constant_override("separation", 8)
		slot_row.add_child(button_row)

		var slot_id := int(entry.get("slot_id", 0))
		var exists := bool(entry.get("exists", false))

		var primary: Button = Button.new()
		primary.custom_minimum_size = Vector2(176.0, 40.0)
		primary.text = "Load World" if exists else "Create World"
		primary.disabled = busy
		primary.pressed.connect((_on_load_pressed if exists else _on_new_pressed).bind(slot_id))
		button_row.add_child(primary)

		var secondary: Button = Button.new()
		secondary.custom_minimum_size = Vector2(176.0, 36.0)
		secondary.text = "Overwrite Slot" if exists else "Reserved"
		secondary.disabled = busy or not exists
		secondary.pressed.connect(_on_new_pressed.bind(slot_id))
		button_row.add_child(secondary)

		var delete_button: Button = Button.new()
		delete_button.custom_minimum_size = Vector2(176.0, 36.0)
		delete_button.text = "Delete"
		delete_button.disabled = busy or not exists
		delete_button.pressed.connect(_on_delete_pressed.bind(slot_id))
		button_row.add_child(delete_button)


func set_launcher_context(context: Dictionary) -> void:
	if app_name_label != null:
		app_name_label.text = String(context.get("app_name", "Voxel RTX Game"))
	if app_version_label != null:
		app_version_label.text = "Build %s" % String(context.get("version", "1.0.0"))
	if context.has("system_profile"):
		set_system_profile(context.get("system_profile", {}))


func set_system_profile(profile: Dictionary) -> void:
	if system_profile_label == null:
		return

	var cpu_count := int(profile.get("cpu_count", 0))
	var ram_gb := snappedf(float(profile.get("system_ram_mb", 0)) / 1024.0, 0.1)
	var vram_gb := snappedf(float(profile.get("gpu_vram_mb", 0)) / 1024.0, 0.1)
	var budget_gb := snappedf(float(profile.get("streaming_budget_mb", 0)) / 1024.0, 0.1)
	var texture_tier := String(profile.get("texture_quality_tier", "balanced")).capitalize()
	system_profile_label.text = "CPU threads: %s\nSystem RAM: %s GB\nGPU VRAM: %s GB\nWorld cache target: %s GB\nTexture tier: %s" % [
		cpu_count,
		ram_gb,
		vram_gb,
		budget_gb,
		texture_tier,
	]


func set_lan_sessions(session_entries: Array[Dictionary]) -> void:
	if lan_session_list == null or lan_status_label == null:
		return

	for child in lan_session_list.get_children():
		lan_session_list.remove_child(child)
		child.queue_free()

	if session_entries.is_empty():
		lan_status_label.text = "Aucun monde LAN detecte pour le moment."
		return

	lan_status_label.text = "%s monde(s) LAN detecte(s)." % session_entries.size()
	for entry in session_entries:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _card_style())
		lan_session_list.add_child(panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)

		var text_stack := VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.add_theme_constant_override("separation", 4)
		row.add_child(text_stack)

		var title := Label.new()
		title.text = String(entry.get("world_name", "LAN World"))
		title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		text_stack.add_child(title)

		var subtitle := Label.new()
		subtitle.text = "%s  |  %s:%s" % [
			String(entry.get("host_name", "Unknown Host")),
			String(entry.get("address", "0.0.0.0")),
			int(entry.get("port", 0)),
		]
		subtitle.add_theme_color_override("font_color", Color(0.62, 0.8, 0.96))
		text_stack.add_child(subtitle)

		var details := Label.new()
		details.text = "Seed %s  |  %s/%s joueurs  |  %s" % [
			int(entry.get("seed", 0)),
			int(entry.get("player_count", 1)),
			int(entry.get("max_players", 4)),
			String(entry.get("biome", "mixed")).capitalize(),
		]
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
		text_stack.add_child(details)

		var join_button := Button.new()
		join_button.text = "Join"
		join_button.custom_minimum_size = Vector2(86.0, 34.0)
		join_button.disabled = busy
		join_button.pressed.connect(_on_join_lan_pressed.bind(entry.duplicate(true)))
		row.add_child(join_button)


func show_menu() -> void:
	visible = true
	if loading_panel != null:
		loading_panel.visible = false
	busy = false


func show_loading(title_text: String, detail_text: String) -> void:
	visible = true
	busy = true
	loading_panel.visible = true
	loading_title.text = title_text
	loading_detail.text = detail_text
	loading_bar.value = 0.0


func set_loading_progress(progress: float, detail_text: String) -> void:
	loading_panel.visible = true
	loading_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	loading_detail.text = detail_text


func set_graphics_settings(settings: Dictionary) -> void:
	if graphics_option == null or auto_checkbox == null:
		return

	var preset := String(settings.get("graphics_preset", "auto")).to_lower()
	var option_index := 0
	for index in range(graphics_option.item_count):
		if String(graphics_option.get_item_metadata(index)) == preset:
			option_index = index
			break
	graphics_option.select(option_index)
	auto_checkbox.button_pressed = bool(settings.get("auto_fallback", true))
	_update_graphics_status()


func hide_menu() -> void:
	visible = false
	busy = false


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.035, 0.055, 1.0)
	root.add_child(background)

	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.03, 0.08, 0.12, 0.72)
	root.add_child(overlay)

	var shell: MarginContainer = MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("margin_left", 46)
	shell.add_theme_constant_override("margin_right", 46)
	shell.add_theme_constant_override("margin_top", 32)
	shell.add_theme_constant_override("margin_bottom", 32)
	root.add_child(shell)

	var page_stack: VBoxContainer = VBoxContainer.new()
	page_stack.add_theme_constant_override("separation", 22)
	shell.add_child(page_stack)

	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _accent_card_style())
	page_stack.add_child(header_panel)

	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 26)
	header_margin.add_theme_constant_override("margin_right", 26)
	header_margin.add_theme_constant_override("margin_top", 22)
	header_margin.add_theme_constant_override("margin_bottom", 22)
	header_panel.add_child(header_margin)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 18)
	header_margin.add_child(header_row)

	var header_copy: VBoxContainer = VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 6)
	header_row.add_child(header_copy)

	var eyebrow: Label = Label.new()
	eyebrow.text = "World Control Center"
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", Color(0.55, 0.84, 0.98))
	header_copy.add_child(eyebrow)

	app_name_label = Label.new()
	app_name_label.text = "Voxel RTX Game"
	app_name_label.add_theme_font_size_override("font_size", 44)
	app_name_label.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0))
	header_copy.add_child(app_name_label)

	var header_summary: Label = Label.new()
	header_summary.text = "Gestion des mondes sauvegardes, chargement progressif et reglages graphiques adaptes a la machine."
	header_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_summary.add_theme_color_override("font_color", Color(0.79, 0.87, 0.94))
	header_copy.add_child(header_summary)

	app_version_label = Label.new()
	app_version_label.text = "Build 1.0.0"
	app_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	app_version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	app_version_label.add_theme_font_size_override("font_size", 20)
	app_version_label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	header_row.add_child(app_version_label)

	var body_row: HBoxContainer = HBoxContainer.new()
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.add_theme_constant_override("separation", 22)
	page_stack.add_child(body_row)

	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(440.0, 0.0)
	sidebar.add_theme_constant_override("separation", 18)
	body_row.add_child(sidebar)

	var graphics_panel: PanelContainer = PanelContainer.new()
	graphics_panel.add_theme_stylebox_override("panel", _card_style())
	sidebar.add_child(graphics_panel)

	var graphics_margin: MarginContainer = MarginContainer.new()
	graphics_margin.add_theme_constant_override("margin_left", 22)
	graphics_margin.add_theme_constant_override("margin_right", 22)
	graphics_margin.add_theme_constant_override("margin_top", 20)
	graphics_margin.add_theme_constant_override("margin_bottom", 20)
	graphics_panel.add_child(graphics_margin)

	var graphics_stack: VBoxContainer = VBoxContainer.new()
	graphics_stack.add_theme_constant_override("separation", 10)
	graphics_margin.add_child(graphics_stack)

	graphics_stack.add_child(_section_title("Graphics Runtime"))

	var graphics_row: HBoxContainer = HBoxContainer.new()
	graphics_row.add_theme_constant_override("separation", 12)
	graphics_stack.add_child(graphics_row)

	graphics_option = OptionButton.new()
	graphics_option.custom_minimum_size = Vector2(180.0, 38.0)
	for preset in ["auto", "8k", "4k", "2k", "1080p", "low"]:
		var label := "Auto"
		if preset == "8k":
			label = "8K"
		elif preset == "4k":
			label = "4K"
		elif preset == "2k":
			label = "2K"
		elif preset == "1080p":
			label = "1080p"
		elif preset == "low":
			label = "Low"
		var index := graphics_option.item_count
		graphics_option.add_item(label)
		graphics_option.set_item_metadata(index, preset)
	graphics_option.item_selected.connect(_on_graphics_option_selected)
	graphics_row.add_child(graphics_option)

	auto_checkbox = CheckBox.new()
	auto_checkbox.text = "Auto FPS fallback"
	auto_checkbox.button_pressed = true
	auto_checkbox.toggled.connect(_on_auto_fallback_toggled)
	graphics_row.add_child(auto_checkbox)

	graphics_status = Label.new()
	graphics_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	graphics_status.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	graphics_stack.add_child(graphics_status)

	var system_panel: PanelContainer = PanelContainer.new()
	system_panel.add_theme_stylebox_override("panel", _card_style())
	sidebar.add_child(system_panel)

	var system_margin: MarginContainer = MarginContainer.new()
	system_margin.add_theme_constant_override("margin_left", 22)
	system_margin.add_theme_constant_override("margin_right", 22)
	system_margin.add_theme_constant_override("margin_top", 20)
	system_margin.add_theme_constant_override("margin_bottom", 20)
	system_panel.add_child(system_margin)

	var system_stack: VBoxContainer = VBoxContainer.new()
	system_stack.add_theme_constant_override("separation", 10)
	system_margin.add_child(system_stack)

	system_stack.add_child(_section_title("Hardware Profile"))

	system_profile_label = Label.new()
	system_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	system_profile_label.add_theme_color_override("font_color", Color(0.74, 0.82, 0.9))
	system_stack.add_child(system_profile_label)

	var launcher_note: Label = Label.new()
	launcher_note.text = "Les mises a jour et les installations sont gerees uniquement par le launcher Windows externe."
	launcher_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	launcher_note.add_theme_color_override("font_color", Color(0.62, 0.74, 0.84))
	system_stack.add_child(launcher_note)

	var lan_panel: PanelContainer = PanelContainer.new()
	lan_panel.add_theme_stylebox_override("panel", _card_style())
	sidebar.add_child(lan_panel)

	var lan_margin: MarginContainer = MarginContainer.new()
	lan_margin.add_theme_constant_override("margin_left", 22)
	lan_margin.add_theme_constant_override("margin_right", 22)
	lan_margin.add_theme_constant_override("margin_top", 20)
	lan_margin.add_theme_constant_override("margin_bottom", 20)
	lan_panel.add_child(lan_margin)

	var lan_stack: VBoxContainer = VBoxContainer.new()
	lan_stack.add_theme_constant_override("separation", 10)
	lan_margin.add_child(lan_stack)

	lan_stack.add_child(_section_title("LAN Worlds"))

	lan_status_label = Label.new()
	lan_status_label.text = "Recherche des mondes reseau..."
	lan_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	lan_stack.add_child(lan_status_label)

	var lan_scroll := ScrollContainer.new()
	lan_scroll.custom_minimum_size = Vector2(0.0, 220.0)
	lan_stack.add_child(lan_scroll)

	lan_session_list = VBoxContainer.new()
	lan_session_list.add_theme_constant_override("separation", 10)
	lan_scroll.add_child(lan_session_list)

	var quit_button: Button = Button.new()
	quit_button.text = "Quitter"
	quit_button.custom_minimum_size = Vector2(0.0, 40.0)
	quit_button.pressed.connect(_on_quit_pressed)
	sidebar.add_child(quit_button)

	var worlds_panel: PanelContainer = PanelContainer.new()
	worlds_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worlds_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worlds_panel.add_theme_stylebox_override("panel", _card_style())
	body_row.add_child(worlds_panel)

	var worlds_margin: MarginContainer = MarginContainer.new()
	worlds_margin.add_theme_constant_override("margin_left", 24)
	worlds_margin.add_theme_constant_override("margin_right", 24)
	worlds_margin.add_theme_constant_override("margin_top", 22)
	worlds_margin.add_theme_constant_override("margin_bottom", 22)
	worlds_panel.add_child(worlds_margin)

	var worlds_stack: VBoxContainer = VBoxContainer.new()
	worlds_stack.add_theme_constant_override("separation", 14)
	worlds_margin.add_child(worlds_stack)

	worlds_stack.add_child(_section_title("Saved Worlds"))

	var worlds_summary: Label = Label.new()
	worlds_summary.text = "Creer, charger, ecraser ou supprimer des mondes persistants. Le jeu attend la premiere zone sure avant de te laisser jouer."
	worlds_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	worlds_summary.add_theme_color_override("font_color", Color(0.72, 0.8, 0.88))
	worlds_stack.add_child(worlds_summary)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worlds_stack.add_child(scroll)

	slot_list = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 14)
	scroll.add_child(slot_list)

	loading_panel = PanelContainer.new()
	loading_panel.visible = false
	loading_panel.anchor_left = 0.5
	loading_panel.anchor_right = 0.5
	loading_panel.anchor_top = 0.5
	loading_panel.anchor_bottom = 0.5
	loading_panel.offset_left = -310.0
	loading_panel.offset_right = 310.0
	loading_panel.offset_top = -96.0
	loading_panel.offset_bottom = 96.0
	loading_panel.add_theme_stylebox_override("panel", _accent_card_style())
	root.add_child(loading_panel)

	var loading_margin: MarginContainer = MarginContainer.new()
	loading_margin.add_theme_constant_override("margin_left", 20)
	loading_margin.add_theme_constant_override("margin_right", 20)
	loading_margin.add_theme_constant_override("margin_top", 20)
	loading_margin.add_theme_constant_override("margin_bottom", 20)
	loading_panel.add_child(loading_margin)

	var loading_stack: VBoxContainer = VBoxContainer.new()
	loading_stack.add_theme_constant_override("separation", 12)
	loading_margin.add_child(loading_stack)

	loading_title = Label.new()
	loading_title.text = "Loading World"
	loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_title.add_theme_font_size_override("font_size", 28)
	loading_title.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0))
	loading_stack.add_child(loading_title)

	loading_detail = Label.new()
	loading_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_detail.add_theme_color_override("font_color", Color(0.79, 0.87, 0.94))
	loading_stack.add_child(loading_detail)

	loading_bar = ProgressBar.new()
	loading_bar.max_value = 100.0
	loading_bar.show_percentage = true
	loading_bar.custom_minimum_size = Vector2(0.0, 32.0)
	loading_stack.add_child(loading_bar)

	_update_graphics_status()


func _section_title(text: String) -> Label:
	var title: Label = Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	return title


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.1, 0.9)
	style.border_color = Color(0.19, 0.34, 0.46, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.01, 0.03, 0.05, 0.42)
	style.shadow_size = 14
	return style


func _accent_card_style() -> StyleBoxFlat:
	var style := _card_style()
	style.bg_color = Color(0.06, 0.1, 0.14, 0.96)
	style.border_color = Color(0.45, 0.78, 0.94, 1.0)
	style.shadow_color = Color(0.06, 0.18, 0.26, 0.5)
	style.shadow_size = 18
	return style


func _on_new_pressed(slot_id: int) -> void:
	slot_new_requested.emit(slot_id)


func _on_load_pressed(slot_id: int) -> void:
	slot_load_requested.emit(slot_id)


func _on_delete_pressed(slot_id: int) -> void:
	slot_delete_requested.emit(slot_id)


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _on_join_lan_pressed(session: Dictionary) -> void:
	lan_join_requested.emit(session)


func _on_graphics_option_selected(_index: int) -> void:
	_emit_graphics_settings()


func _on_auto_fallback_toggled(_enabled: bool) -> void:
	_emit_graphics_settings()


func _emit_graphics_settings() -> void:
	_update_graphics_status()
	graphics_settings_changed.emit(
		{
			"graphics_preset": String(graphics_option.get_item_metadata(graphics_option.get_selected_id())),
			"auto_fallback": auto_checkbox.button_pressed,
		}
	)


func _update_graphics_status() -> void:
	if graphics_status == null or graphics_option == null or auto_checkbox == null:
		return

	var preset_label := graphics_option.get_item_text(graphics_option.get_selected_id())
	var auto_label := "ON" if auto_checkbox.button_pressed else "OFF"
	graphics_status.text = "Preset: %s  |  Auto fallback: %s. Si les FPS chutent pendant quelques secondes, le jeu reduit le niveau vers 4K, 2K, 1080p puis Low." % [
		preset_label,
		auto_label,
	]
