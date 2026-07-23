extends CanvasLayer

## 暂停菜单（CanvasLayer，挂于 Main 下，process_mode=ALWAYS 以便暂停时仍可响应 ESC）。
## ESC 开关：与升级卡（UpgradeUI）互斥，与死亡结算屏（GameOverUI）互斥。

const MENU_SCENE := "res://Scenes/menu.tscn"

var _overlay: Control
var _open: bool = false

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_overlay.visible = false

func _build() -> void:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false

	# 背景图（pause_bg.png，384x216 等比铺满）
	var bg := TextureRect.new()
	_overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = preload("res://Assets/Sprites/UI/pause_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

	# 暗化叠层，保证文字清晰
	var dim := ColorRect.new()
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	_overlay.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)

	var title := Label.new()
	vbox.add_child(title)
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 5)

	vbox.add_child(_spacer(14.0))
	vbox.add_child(_make_button("继续游戏", _on_resume, Color(0.18, 0.30, 0.22)))
	vbox.add_child(_make_button("重新开始", _on_restart, Color(0.20, 0.18, 0.30)))
	vbox.add_child(_make_button("返回主菜单", _on_menu, Color(0.20, 0.18, 0.30)))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	# 升级卡打开或死亡结算打开时不响应 ESC，避免嵌套暂停
	if _upgrade_open() or _gameover_open():
		return
	toggle()

func toggle() -> void:
	if _open:
		_on_resume()
	else:
		_open = true
		_overlay.visible = true
		var tree := get_tree()
		if tree != null:
			tree.paused = true

func _on_resume() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false

func _on_restart() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
		tree.reload_current_scene()

func _on_menu() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file.call_deferred(MENU_SCENE)

func is_open() -> bool:
	return _open

func _upgrade_open() -> bool:
	var ui = get_tree().current_scene.get_node_or_null("UpgradeUI")
	if ui != null and ui.has_method("is_open"):
		return ui.is_open()
	return false

func _gameover_open() -> bool:
	var go = get_tree().current_scene.get_node_or_null("GameOverUI")
	if go != null and go.has_method("is_open"):
		return go.is_open()
	return false

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

func _make_button(text: String, cb: Callable, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240.0, 56.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.border_color = Color(0.9, 0.9, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = accent * 1.3
	b.add_theme_stylebox_override("hover", sbh)
	b.pressed.connect(cb)
	return b
