extends Control

var _panel: Panel

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

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(380, 320)
	_panel.size = Vector2(380, 320)
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://Assets/Sprites/UI/info_panel.png")
	sb.texture_margin_left = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_bottom = 28.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	# Panel 不会按 StyleBox 边距内缩子控件，VBox 也不识别 margin_* 主题常量，
	# 必须手动设 offset 才能把内容真正缩进卡面框内（否则文字顶到边框上）
	vbox.offset_left = 40.0
	vbox.offset_right = -40.0
	vbox.offset_top = 44.0
	vbox.offset_bottom = -36.0

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	var vol_label := Label.new()
	vol_label.text = "主音量"
	vol_label.add_theme_font_size_override("font_size", 18)
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
	full.add_theme_font_size_override("font_size", 18)
	full.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	full.button_pressed = SaveManager.settings.get("fullscreen", false) if SaveManager != null else false
	full.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(full)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb_btn := StyleBoxFlat.new()
	sb_btn.bg_color = Color(0.22, 0.25, 0.32)
	sb_btn.border_color = Color(0.5, 0.55, 0.65)
	sb_btn.set_border_width_all(2)
	sb_btn.set_corner_radius_all(12)
	close_btn.add_theme_stylebox_override("normal", sb_btn)
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
