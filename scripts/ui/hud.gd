extends CanvasLayer
class_name HUDLayer

signal mod_toggle_requested(mod_id)
signal world_regenerate_requested()
signal overlay_mode_changed(interactive)

var slot_panels: Array[PanelContainer] = []
var slot_name_labels: Array[Label] = []
var slot_count_labels: Array[Label] = []
var slot_accents: Array[ColorRect] = []

var selected_label: Label
var target_label: Label
var help_label: Label
var mod_panel: PanelContainer
var mod_list: VBoxContainer
var mods_visible := false


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mod_menu") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		_toggle_mod_panel()
		get_viewport().set_input_as_handled()


func set_inventory(slot_view: Array[Dictionary]) -> void:
	for index in range(min(slot_view.size(), slot_panels.size())):
		var slot: Dictionary = slot_view[index]
		var is_empty := bool(slot.get("empty", true))
		slot_name_labels[index].text = String(slot.get("name", "Empty"))
		slot_count_labels[index].text = "" if is_empty else "x%s" % int(slot.get("count", 0))
		slot_accents[index].color = slot.get("accent", Color(0.24, 0.3, 0.38))
		slot_name_labels[index].modulate = Color(0.62, 0.7, 0.78) if is_empty else Color(0.95, 0.98, 1.0)


func set_selected_block(slot_index: int, block_name: String) -> void:
	selected_label.text = "Selected: %s" % block_name
	for index in range(slot_panels.size()):
		slot_panels[index].add_theme_stylebox_override(
			"panel",
			_selected_slot_style() if index == slot_index else _slot_style()
		)


func set_targeted_block(block_name: String) -> void:
	target_label.text = "" if block_name.is_empty() else "Target: %s" % block_name


func set_mods(mod_entries: Array[Dictionary]) -> void:
	if mod_list == null:
		return

	for child in mod_list.get_children():
		mod_list.remove_child(child)
		child.queue_free()

	for mod_entry in mod_entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		mod_list.add_child(row)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)

		var title := Label.new()
		title.text = String(mod_entry.get("name", "Unknown Mod"))
		title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		text_box.add_child(title)

		var description := Label.new()
		description.text = String(mod_entry.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color(0.72, 0.8, 0.88))
		text_box.add_child(description)

		var toggle := Button.new()
		var enabled := bool(mod_entry.get("enabled", false))
		toggle.text = "On" if enabled else "Off"
		toggle.custom_minimum_size = Vector2(68.0, 34.0)
		toggle.pressed.connect(_on_mod_toggle_pressed.bind(String(mod_entry.get("id", ""))))
		row.add_child(toggle)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	slot_panels.clear()
	slot_name_labels.clear()
	slot_count_labels.clear()
	slot_accents.clear()

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	target_label = Label.new()
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.anchor_left = 0.5
	target_label.anchor_right = 0.5
	target_label.anchor_top = 0.0
	target_label.anchor_bottom = 0.0
	target_label.offset_left = -260.0
	target_label.offset_right = 260.0
	target_label.offset_top = 28.0
	target_label.offset_bottom = 56.0
	target_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	root.add_child(target_label)

	selected_label = Label.new()
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	selected_label.anchor_left = 0.0
	selected_label.anchor_right = 0.0
	selected_label.anchor_top = 0.0
	selected_label.anchor_bottom = 0.0
	selected_label.offset_left = 24.0
	selected_label.offset_right = 260.0
	selected_label.offset_top = 24.0
	selected_label.offset_bottom = 56.0
	selected_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	root.add_child(selected_label)

	var crosshair_root := Control.new()
	crosshair_root.anchor_left = 0.5
	crosshair_root.anchor_right = 0.5
	crosshair_root.anchor_top = 0.5
	crosshair_root.anchor_bottom = 0.5
	crosshair_root.offset_left = -10.0
	crosshair_root.offset_right = 10.0
	crosshair_root.offset_top = -10.0
	crosshair_root.offset_bottom = 10.0
	root.add_child(crosshair_root)

	var horizontal := ColorRect.new()
	horizontal.color = Color(0.96, 0.99, 1.0, 0.92)
	horizontal.offset_left = -8.0
	horizontal.offset_right = 8.0
	horizontal.offset_top = -1.0
	horizontal.offset_bottom = 1.0
	crosshair_root.add_child(horizontal)

	var vertical := ColorRect.new()
	vertical.color = Color(0.96, 0.99, 1.0, 0.92)
	vertical.offset_left = -1.0
	vertical.offset_right = 1.0
	vertical.offset_top = -8.0
	vertical.offset_bottom = 8.0
	crosshair_root.add_child(vertical)

	var hotbar_anchor := MarginContainer.new()
	hotbar_anchor.anchor_left = 0.5
	hotbar_anchor.anchor_right = 0.5
	hotbar_anchor.anchor_top = 1.0
	hotbar_anchor.anchor_bottom = 1.0
	hotbar_anchor.offset_left = -520.0
	hotbar_anchor.offset_right = 520.0
	hotbar_anchor.offset_top = -128.0
	hotbar_anchor.offset_bottom = -28.0
	root.add_child(hotbar_anchor)

	var hotbar_box := HBoxContainer.new()
	hotbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_box.add_theme_constant_override("separation", 10)
	hotbar_anchor.add_child(hotbar_box)

	for _slot_index in range(BlockLibrary.get_hotbar_size()):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(110.0, 82.0)
		slot.add_theme_stylebox_override("panel", _slot_style())
		hotbar_box.add_child(slot)
		slot_panels.append(slot)

		var slot_margin := MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 10)
		slot_margin.add_theme_constant_override("margin_right", 10)
		slot_margin.add_theme_constant_override("margin_top", 8)
		slot_margin.add_theme_constant_override("margin_bottom", 8)
		slot.add_child(slot_margin)

		var slot_stack := VBoxContainer.new()
		slot_stack.add_theme_constant_override("separation", 4)
		slot_margin.add_child(slot_stack)

		var accent := ColorRect.new()
		accent.custom_minimum_size = Vector2(0.0, 8.0)
		accent.color = Color(0.24, 0.3, 0.38)
		slot_stack.add_child(accent)
		slot_accents.append(accent)

		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.text = "Empty"
		slot_stack.add_child(name_label)
		slot_name_labels.append(name_label)

		var count_label := Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
		slot_stack.add_child(count_label)
		slot_count_labels.append(count_label)

	help_label = Label.new()
	help_label.anchor_left = 0.0
	help_label.anchor_right = 0.0
	help_label.anchor_top = 1.0
	help_label.anchor_bottom = 1.0
	help_label.offset_left = 24.0
	help_label.offset_right = 560.0
	help_label.offset_top = -126.0
	help_label.offset_bottom = -24.0
	help_label.text = "ZQSD / WASD move  |  Shift sprint  |  Space jump  |  Hold left click break  |  Right click place  |  Wheel / 1-8 select  |  M mods  |  R new world"
	help_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	root.add_child(help_label)

	mod_panel = PanelContainer.new()
	mod_panel.visible = false
	mod_panel.anchor_left = 1.0
	mod_panel.anchor_right = 1.0
	mod_panel.anchor_top = 0.0
	mod_panel.anchor_bottom = 0.0
	mod_panel.offset_left = -420.0
	mod_panel.offset_right = -24.0
	mod_panel.offset_top = 24.0
	mod_panel.offset_bottom = 420.0
	mod_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mod_panel.add_theme_stylebox_override("panel", _selected_slot_style())
	root.add_child(mod_panel)

	var mod_margin := MarginContainer.new()
	mod_margin.add_theme_constant_override("margin_left", 14)
	mod_margin.add_theme_constant_override("margin_right", 14)
	mod_margin.add_theme_constant_override("margin_top", 14)
	mod_margin.add_theme_constant_override("margin_bottom", 14)
	mod_panel.add_child(mod_margin)

	var mod_stack := VBoxContainer.new()
	mod_stack.add_theme_constant_override("separation", 10)
	mod_margin.add_child(mod_stack)

	var mod_title := Label.new()
	mod_title.text = "Mods"
	mod_title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	mod_stack.add_child(mod_title)

	var mod_hint := Label.new()
	mod_hint.text = "Toggle mods and regenerate the infinite world."
	mod_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	mod_stack.add_child(mod_hint)

	var regen_button := Button.new()
	regen_button.text = "New Seed World"
	regen_button.pressed.connect(_on_regenerate_pressed)
	mod_stack.add_child(regen_button)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0.0, 260.0)
	mod_stack.add_child(list_scroll)

	mod_list = VBoxContainer.new()
	mod_list.add_theme_constant_override("separation", 12)
	list_scroll.add_child(mod_list)

	_set_mouse_passthrough(root)
	mod_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mod_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	mod_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	list_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	mod_list.mouse_filter = Control.MOUSE_FILTER_PASS


func _slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.72)
	style.border_color = Color(0.35, 0.49, 0.64, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _selected_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.2, 0.92)
	style.border_color = Color(0.57, 0.86, 1.0, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.22, 0.6, 0.9, 0.35)
	style.shadow_size = 10
	return style


func _set_mouse_passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_mouse_passthrough(child)


func _toggle_mod_panel() -> void:
	mods_visible = not mods_visible
	mod_panel.visible = mods_visible
	overlay_mode_changed.emit(mods_visible)


func _on_mod_toggle_pressed(mod_id: String) -> void:
	mod_toggle_requested.emit(mod_id)


func _on_regenerate_pressed() -> void:
	world_regenerate_requested.emit()
