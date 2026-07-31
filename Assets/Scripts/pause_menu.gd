extends CanvasLayer

## 暂停菜单（CanvasLayer，挂于 Main 下，process_mode=ALWAYS 以便暂停时仍可响应 ESC）。
## ESC 开关：与升级卡（UpgradeUI）互斥，与死亡结算屏（GameOverUI）互斥。

const MENU_SCENE := "res://Scenes/menu.tscn"

var _overlay: Control
var _open: bool = false
var _slot_overlay: Control = null
var _slot_panel: Panel = null   # 存档窗口面板（用于延迟居中）
var _slot_mode: String = ""  # "save" or "load"

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
	vbox.add_theme_constant_override("separation", 5)
	# 整体把面板往上平移（负间隔会被 Godot 夹成 0、居中又会吸收一半位移，所以用整体平移才看得出来）
	vbox.offset_top = -14.0
	vbox.offset_bottom = -14.0

	var _title_h := 60.0
	var _title_tex_path := "res://Assets/Sprites/UI/TextBits/pause_title.png"
	if ResourceLoader.exists(_title_tex_path):
		var _ttx := load(_title_tex_path) as Texture2D
		_title_h = _ttx.get_size().y
		var title := TextureRect.new()
		title.texture = _ttx
		title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title.custom_minimum_size = _ttx.get_size()
		title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title)
	else:
		var title := Label.new()
		vbox.add_child(title)
		title.text = "已暂停"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 52)
		title.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		title.add_theme_constant_override("outline_size", 5)

	var _btn_max_h: float = clamp(_title_h * 0.6, 40.0, 76.0)
	var _btn_max_w := 300.0
	vbox.add_child(_spacer(0.0))
	vbox.add_child(_make_button("继续游戏", _on_resume, Color(0.18, 0.30, 0.22), "res://Assets/Sprites/UI/Buttons/pause_resume.png", _btn_max_w, _btn_max_h))
	vbox.add_child(_make_button("保存游戏", _on_save_click, Color(0.18, 0.28, 0.35), "res://Assets/Sprites/UI/Buttons/pause_save.png", _btn_max_w, _btn_max_h))
	vbox.add_child(_make_button("读取存档", _on_load_click, Color(0.25, 0.20, 0.30), "res://Assets/Sprites/UI/Buttons/pause_load.png", _btn_max_w, _btn_max_h))
	vbox.add_child(_make_button("重新开始", _on_restart, Color(0.20, 0.18, 0.30), "res://Assets/Sprites/UI/Buttons/pause_restart.png", _btn_max_w, _btn_max_h))
	vbox.add_child(_make_button("返回主菜单", _on_menu, Color(0.20, 0.18, 0.30), "res://Assets/Sprites/UI/Buttons/pause_menu.png", _btn_max_w, _btn_max_h))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _upgrade_open() or _gameover_open():
		return
	if _slot_overlay != null and _slot_overlay.visible:
		_close_slot_ui()
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

func _on_save_click() -> void:
	_slot_mode = "save"
	_open_slot_ui()

func _on_load_click() -> void:
	_slot_mode = "load"
	_open_slot_ui()

func _open_slot_ui() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
	_slot_overlay = Control.new()
	_slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_slot_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_overlay.add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(600, 540)
	panel.size = Vector2(600, 540)
	var sb_bg := StyleBoxTexture.new()
	sb_bg.texture = load("res://Assets/Sprites/UI/info_panel.png")
	sb_bg.texture_margin_left = 28.0
	sb_bg.texture_margin_top = 28.0
	sb_bg.texture_margin_right = 28.0
	sb_bg.texture_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", sb_bg)
	_slot_overlay.add_child(panel)
	_slot_panel = panel
	call_deferred("_center_slot_panel")   # 等布局完成再按视口尺寸居中（避免创建瞬间父尺寸未定导致偏到一侧）

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	# Panel 不按 StyleBox 边距内缩子控件，VBox 也不识别 margin_* 主题常量，
	# 手动设 offset 内缩；offset_top 多留白，避免「读档」标题顶出框上沿
	vbox.offset_left = 36.0
	vbox.offset_right = -36.0
	vbox.offset_top = 42.0
	vbox.offset_bottom = -30.0

	var title := Label.new()
	title.text = "存档" if _slot_mode == "save" else "读档"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.30, 0.52, 0.36))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	vbox.add_child(_spacer(6))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	var slot_n: int = SaveManager.SLOT_COUNT if SaveManager != null else 4
	for i in range(slot_n):
		grid.add_child(_make_slot_card(i))

	vbox.add_child(_spacer(10))

	var cancel := Button.new()
	cancel.text = "返回"
	cancel.custom_minimum_size = Vector2(160, 44)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.add_theme_font_size_override("font_size", 22)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.16, 0.19, 0.25)
	sb2.border_color = Color(0.55, 0.62, 0.72)
	sb2.set_border_width_all(2)
	sb2.set_corner_radius_all(12)
	cancel.add_theme_stylebox_override("normal", sb2)
	cancel.pressed.connect(_close_slot_ui)
	vbox.add_child(cancel)

func _close_slot_ui() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
		_slot_overlay = null
	_slot_panel = null

# 等布局完成后再把存档面板按视口尺寸精确居中（与 settings_ui 同套路）
func _center_slot_panel() -> void:
	if _slot_panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		return
	_slot_panel.position = (vp - _slot_panel.size) * 0.5

# 构造一个存档卡（2×2 网格里的单个格子）
func _make_slot_card(index: int) -> Button:
	var meta: Dictionary = SaveManager.get_slot_meta(index) if SaveManager != null else {}
	var card := Button.new()
	card.custom_minimum_size = Vector2(230, 140)
	card.text = ""   # 内容用子节点显示，避免默认文本占位
	# 卡片底色（正常 / 悬停 / 按下）
	var sb_card := StyleBoxFlat.new()
	sb_card.bg_color = Color(0.14, 0.17, 0.22)
	sb_card.border_color = Color(0.45, 0.52, 0.62)
	sb_card.set_border_width_all(2)
	sb_card.set_corner_radius_all(12)
	card.add_theme_stylebox_override("normal", sb_card)
	var sb_hover := sb_card.duplicate()
	sb_hover.bg_color = Color(0.22, 0.27, 0.34)
	sb_hover.border_color = Color(0.62, 0.70, 0.85)
	card.add_theme_stylebox_override("hover", sb_hover)
	var sb_press := sb_hover.duplicate()
	sb_press.bg_color = Color(0.28, 0.34, 0.42)
	card.add_theme_stylebox_override("pressed", sb_press)
	# 内容容器
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	# VBox 不识别 margin_* 主题常量，手动设 offset 内缩，让文字不贴卡片边框
	box.offset_left = 16.0
	box.offset_right = -16.0
	box.offset_top = 14.0
	box.offset_bottom = -14.0
	card.add_child(box)
	# 标题行：存档 N
	var head := Label.new()
	head.text = "存档 %d" % (index + 1)
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	box.add_child(head)
	if meta.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		box.add_child(empty)
		# 读档模式下空格子不可点（不能读空档）
		if _slot_mode == "load":
			card.disabled = true
	else:
		var ch: String = meta.get("character", "???")
		var wi: String = meta.get("wave_info", "")
		var ti: String = _format_time(meta.get("time_survived", 0.0))
		var ts: String = meta.get("timestamp", "???")
		var l1 := Label.new()
		l1.text = "角色：%s" % ch
		l1.add_theme_font_size_override("font_size", 16)
		l1.add_theme_color_override("font_color", Color(0.80, 0.88, 1.0))
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l1)
		var l2 := Label.new()
		l2.text = "进度：%s" % wi
		l2.add_theme_font_size_override("font_size", 16)
		l2.add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l2)
		var l3 := Label.new()
		l3.text = "存活：%s" % ti
		l3.add_theme_font_size_override("font_size", 16)
		l3.add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))
		l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l3)
		var l4 := Label.new()
		l4.text = ts
		l4.add_theme_font_size_override("font_size", 13)
		l4.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
		l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l4)
	card.pressed.connect(_on_slot_selected.bind(index))
	return card

func _on_slot_selected(index: int) -> void:
	if _slot_mode == "save":
		_do_save(index)
	else:
		_do_load(index)
	_close_slot_ui()

func _do_save(index: int) -> void:
	var state := _gather_save_state()
	SaveManager.save_in_game_slot(index, state)

func _do_load(index: int) -> void:
	SaveManager.load_in_game_slot(index)
	_on_resume()
	if RunStats != null:
		RunStats.skip_reset = true
	if SkillManager != null:
		SkillManager.skip_reset = true
	if WaveManager != null:
		WaveManager.skip_reset = true
	var tree := get_tree()
	if tree != null:
		tree.reload_current_scene()

func _gather_save_state() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_state: Dictionary = {}
	if player != null and player.has_method("export_state"):
		player_state = player.export_state()
	var wave_state: Dictionary = {}
	if WaveManager != null and WaveManager.has_method("export_state"):
		wave_state = WaveManager.export_state()
	var run_stats_data: Dictionary = {}
	if RunStats != null:
		run_stats_data = {
			"time_survived": RunStats.time_survived,
			"kills": RunStats.kills,
			"last_wave_reached": RunStats.last_wave_reached,
			"chosen_character": RunStats.chosen_character,
			"deploy_difficulty": RunStats.deploy_difficulty,
			"game_mode": RunStats.game_mode,
			"selected_level_id": RunStats.selected_level_id,
			"equipped_gear": RunStats.equipped_gear.duplicate(true),
			"run_diamonds": RunStats.run_diamonds,
		}
	var skills_data: Dictionary = {}
	if SkillManager != null:
		skills_data = SkillManager.owned.duplicate(true)
	return {
		"player_state": player_state,
		"wave_state": wave_state,
		"run_stats": run_stats_data,
		"skills": skills_data,
	}

func _format_time(t: float) -> String:
	var total: int = int(t)
	var m: int = total / 60
	var s: int = total % 60
	return "%02d:%02d" % [m, s]

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

func _make_button(text: String, cb: Callable, accent: Color, tex_path := "", max_w := 300.0, max_h := 64.0) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if tex_path != "" and ResourceLoader.exists(tex_path):
		# 素材已是完整按钮外观：去掉原色块框，缩放到上限内显示（保持比「已暂停」小）
		var tex := load(tex_path) as Texture2D
		var tsz := tex.get_size()
		var _scale: float = min(max_w / tsz.x, max_h / tsz.y, 1.0)
		b.icon = tex
		b.text = ""
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = tsz * _scale
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.mouse_entered.connect(func(): b.modulate = Color(1.25, 1.25, 1.25))
		b.mouse_exited.connect(func(): b.modulate = Color(1, 1, 1))
	else:
		b.text = text
		b.custom_minimum_size = Vector2(240.0, 56.0)
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
