extends Control

var _panel: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	call_deferred("_center_panel")

func _center_panel() -> void:
	if _panel == null:
		return
	var ps := size
	if ps == Vector2.ZERO:
		ps = get_viewport_rect().size
	_panel.position = (ps - _panel.size) * 0.5

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = ColorRect.new()
	_panel.color = Color(0.12, 0.14, 0.18, 0.95)
	_panel.custom_minimum_size = Vector2(380, 320)
	_panel.size = Vector2(380, 320)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.add_theme_constant_override("margin_left", 30)
	vbox.add_theme_constant_override("margin_right", 30)
	vbox.add_theme_constant_override("margin_top", 20)

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	vbox.add_child(_spacer(8))

	var vol_label := Label.new()
	vol_label.text = "主音量"
	vol_label.add_theme_font_size_override("font_size", 22)
	vol_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	vbox.add_child(vol_label)

	var vol := HSlider.new()
	vol.size_flags_horizontal = Control.SIZE_FILL
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = SaveManager.settings.get("master_volume", 1.0) if SaveManager != null else 1.0
	vol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vol.value_changed.connect(_on_volume_changed)
	vbox.add_child(vol)

	_volume_value_label = Label.new()
	_volume_value_label.text = "%d%%" % int(vol.value * 100.0)
	_volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value_label.add_theme_font_size_override("font_size", 18)
	_volume_value_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(_volume_value_label)

	var full := CheckBox.new()
	full.text = "全屏模式"
	full.add_theme_font_size_override("font_size", 22)
	full.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	full.button_pressed = SaveManager.settings.get("fullscreen", false) if SaveManager != null else false
	full.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(full)

	vbox.add_child(_spacer(8))

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.25, 0.32)
	sb.border_color = Color(0.5, 0.55, 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	close_btn.add_theme_stylebox_override("normal", sb)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_on_close)
	vbox.add_child(close_btn)

var _volume_value_label: Label

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

func _on_volume_changed(val: float) -> void:
	if _volume_value_label != null:
		_volume_value_label.text = "%d%%" % int(val * 100.0)
	if SaveManager != null:
		SaveManager.update_setting("master_volume", val)

func _on_fullscreen_toggled(on: bool) -> void:
	if SaveManager != null:
		SaveManager.update_setting("fullscreen", on)

func _on_close() -> void:
	queue_free()
