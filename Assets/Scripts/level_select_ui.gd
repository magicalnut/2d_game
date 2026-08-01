class_name LevelSelectUI
extends Control

const MAIN_SCENE := "res://Scenes/main.tscn"
const MENU_SCENE := "res://Scenes/menu.tscn"
const SETUP_SCENE := "res://Scenes/character_setup.tscn"
const LEVEL_DATA_PATH := "res://Assets/Resources/Levels/"
const LEVEL_IDS: Array[String] = ["level_01", "level_02", "level_03"]

const FONT_DIR := "res://Assets/Fonts/"
const TITLE_DIR := "res://Assets/Sprites/Title/"
const BTN_DIR := "res://Assets/Sprites/UI/Buttons/"
const PANEL_TEX_PATH := "res://Assets/Sprites/UI/info_panel.png"
const TITLE_SCALE: float = 1.6

var _level_data_cache: Dictionary = {}
var _selected_level: String = ""
var _card_root: HBoxContainer = null
var _fnt: Font = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fnt = _load_font()
	_load_all_level_data()
	_setup_ui()
	_refresh_ui()

func _setup_ui() -> void:
	var bg_img := TextureRect.new()
	bg_img.texture = preload("res://Assets/Sprites/UI/menu_bg.png")
	bg_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_img.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_img.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg_img)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.38)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var ghost := preload("res://Assets/Scripts/ghost_layer.gd").new()
	ghost.ghost_dir = "res://Assets/Sprites/Ghosts/Red/"
	add_child(ghost)

	var vig := TextureRect.new()
	vig.texture = _make_vignette(0.5)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(vig)

	var skull := preload("res://Assets/Scripts/skull_layer.gd").new()
	skull.skull_dir = "res://Assets/Sprites/Skulls/Red/"
	skull.skull_tint = Color(0.6, 0.6, 0.66, 1.0)
	add_child(skull)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	top.add_child(_spacer(18.0))
	add_child(top)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card_root = HBoxContainer.new()
	_card_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_root.add_theme_constant_override("separation", 28)
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_card_root)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 10)
	bottom.add_child(_spacer(24.0))
	var back := _make_card_button("返回战备", _on_back, UIColors.WHITE, Vector2(240.0, 64.0))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_row.add_child(back)
	bottom.add_child(back_row)
	bottom.add_child(_spacer(22.0))
	add_child(bottom)

func _load_all_level_data() -> void:
	for id in LEVEL_IDS:
		var path: String = LEVEL_DATA_PATH + id + ".tres"
		if ResourceLoader.exists(path):
			var data: LevelData = load(path) as LevelData
			if data != null:
				_level_data_cache[id] = data

func _refresh_ui() -> void:
	if _card_root == null:
		return
	for c in _card_root.get_children():
		c.queue_free()

	for id in LEVEL_IDS:
		var data: LevelData = _level_data_cache.get(id) as LevelData
		var unlocked: bool = _is_level_unlocked(id)
		var completed: bool = _is_level_completed(id)
		_card_root.add_child(_make_level_card(id, data, unlocked, completed))

func _make_level_card(level_id: String, data: LevelData, unlocked: bool, completed: bool) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(300.0, 440.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_card_panel_style(panel, unlocked, false)
	wrap.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 28.0
	vbox.offset_right = -28.0
	vbox.offset_top = 28.0
	vbox.offset_bottom = -28.0
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(vbox)

	var display_name: String = level_id if data == null else data.display_name
	var description: String = "" if data == null else data.description
	var objective_text: String = _format_objective(data)
	var reward_text: String = _format_rewards(data)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 14)
	if completed:
		badge.text = "✓ 已通关"
		badge.add_theme_color_override("font_color", UIColors.GOLD)
	elif not unlocked:
		badge.text = "🔒 未解锁"
		badge.add_theme_color_override("font_color", UIColors.MUTED)
	else:
		badge.text = ""
	vbox.add_child(badge)

	var title := Label.new()
	title.text = display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIColors.GOLD)
	if _fnt != null:
		title.add_theme_font_override("font", _fnt)
	vbox.add_child(title)

	vbox.add_child(_spacer(6.0))

	var desc := Label.new()
	desc.text = description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", UIColors.GRAY)
	vbox.add_child(desc)

	vbox.add_child(_spacer(12.0))

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.color = Color(0.55, 0.65, 0.78, 0.35)
	vbox.add_child(line)

	vbox.add_child(_spacer(10.0))

	var obj_title := Label.new()
	obj_title.text = "关卡目标"
	obj_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_title.add_theme_font_size_override("font_size", 16)
	obj_title.add_theme_color_override("font_color", UIColors.GOLD)
	vbox.add_child(obj_title)

	var obj := Label.new()
	obj.text = objective_text
	obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.add_theme_font_size_override("font_size", 17)
	obj.add_theme_color_override("font_color", UIColors.WHITE)
	vbox.add_child(obj)

	vbox.add_child(_spacer(10.0))

	var rwd_title := Label.new()
	rwd_title.text = "通关奖励"
	rwd_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rwd_title.add_theme_font_size_override("font_size", 16)
	rwd_title.add_theme_color_override("font_color", UIColors.GOLD)
	vbox.add_child(rwd_title)

	var rwd := Label.new()
	rwd.text = reward_text
	rwd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rwd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rwd.add_theme_font_size_override("font_size", 15)
	rwd.add_theme_color_override("font_color", UIColors.GOLD)
	vbox.add_child(rwd)

	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.disabled = not unlocked
	hit.mouse_filter = Control.MOUSE_FILTER_STOP if unlocked else Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.add_theme_stylebox_override("disabled", empty)
	if unlocked:
		hit.mouse_entered.connect(func(): _apply_card_panel_style(panel, true, true))
		hit.mouse_exited.connect(func(): _apply_card_panel_style(panel, true, false))
		hit.pressed.connect(_on_level_selected.bind(level_id))
	wrap.add_child(hit)

	return wrap

func _apply_card_panel_style(panel: Panel, unlocked: bool, hovered: bool) -> void:
	var sb: StyleBox
	if ResourceLoader.exists(PANEL_TEX_PATH):
		var st := StyleBoxTexture.new()
		st.texture = load(PANEL_TEX_PATH)
		st.texture_margin_left = 28.0
		st.texture_margin_top = 28.0
		st.texture_margin_right = 28.0
		st.texture_margin_bottom = 28.0
		st.modulate_color = Color(1.0, 1.0, 1.0, 1.0) if unlocked else Color(0.55, 0.55, 0.58, 0.85)
		if hovered and unlocked:
			st.modulate_color = Color(1.18, 1.18, 1.18, 1.0)
		sb = st
	else:
		var fb := StyleBoxFlat.new()
		if unlocked:
			fb.bg_color = Color(0.10, 0.13, 0.18)
			fb.border_color = Color(0.55, 0.75, 0.95) if hovered else Color(0.45, 0.58, 0.75)
		else:
			fb.bg_color = Color(0.08, 0.08, 0.09)
			fb.border_color = Color(0.38, 0.38, 0.40)
		fb.set_border_width_all(2)
		fb.set_corner_radius_all(14)
		sb = fb
	panel.add_theme_stylebox_override("panel", sb)

func _format_objective(data: LevelData) -> String:
	if data == null or data.stages.is_empty():
		return "?"
	var stage: Dictionary = data.stages[0]
	var obj_type: String = stage.get("objective_type", "kill_count")
	var target: float = float(stage.get("target_value", 0.0))
	match obj_type:
		"survive_time":
			return "存活 %d 秒" % int(target)
		"kill_boss":
			return "击败 BOSS"
		"protect_target":
			return "保护目标"
		_:
			return "击杀 %d 名敌人" % int(target)

func _format_rewards(data: LevelData) -> String:
	if data == null:
		return ""
	var lines: Array[String] = []
	var diamonds: int = data.get_diamond_reward()
	if diamonds > 0:
		lines.append("💎 %d" % diamonds)
	var first_gear: String = data.get_first_clear_gear_id()
	if not first_gear.is_empty() and EquipmentManager != null:
		lines.append("首通：%s" % EquipmentManager.get_gear_name(first_gear))
	if lines.is_empty():
		return "无"
	return "\n".join(lines)

func _is_level_unlocked(level_id: String) -> bool:
	if RunStats != null:
		return RunStats.is_level_unlocked(level_id)
	var data: LevelData = _level_data_cache.get(level_id) as LevelData
	if data == null:
		return false
	return data.unlock_requirement.is_empty()

func _is_level_completed(level_id: String) -> bool:
	if RunStats != null:
		return RunStats.is_level_completed(level_id)
	return false

func _on_level_selected(level_id: String) -> void:
	if not _is_level_unlocked(level_id):
		return
	_selected_level = level_id
	if RunStats != null:
		RunStats.game_mode = "level"
		RunStats.selected_level_id = level_id
		RunStats.level_mode_result = ""
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_back() -> void:
	# 返回战备页（选择装备页面），而非角色选择转盘：置 back_to_loadout 标志，
	# character_setup._ready 检测到后会跳过角色转盘、直接停在整备（选择装备）视图。
	# active_slot 在新游戏/读档两种入口下均已绑定为有效槽位，故此处条件恒满足。
	if SaveManager != null and SaveManager.active_slot >= 0:
		SaveManager.back_to_loadout = true
	get_tree().change_scene_to_file(SETUP_SCENE)

func _load_font() -> Font:
	for p in [FONT_DIR + "title.ttf", FONT_DIR + "title.otf"]:
		if ResourceLoader.exists(p):
			var f = load(p)
			if f is Font:
				return f
	return null

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

func _make_vignette(strength: float) -> Texture2D:
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(s) * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clamp((d - 0.38) / 0.62, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(0, 0, 0, a * strength))
	return ImageTexture.create_from_image(img)

func _make_title_styled(text: String, fnt: Font) -> Control:
	var title_layer := Control.new()
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var img_path: String = TITLE_DIR + "select_title.png"
	if ResourceLoader.exists(img_path):
		var tex: Texture2D = load(img_path)
		var h := 70.0 * TITLE_SCALE
		var sc: float = h / max(1.0, float(tex.get_height()))
		var w: float = float(tex.get_width()) * sc
		title_layer.custom_minimum_size = Vector2(w, h)

		var glow := TextureRect.new()
		glow.texture = tex
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		glow.scale = Vector2(1.06, 1.06)
		glow.modulate = Color(1.0, 0.92, 0.7, 0.45)
		glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_layer.add_child(glow)

		var shadow := TextureRect.new()
		shadow.texture = tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		shadow.modulate = Color(0.0, 0.0, 0.0, 0.55)
		shadow.position = Vector2(6.0, 10.0)
		shadow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_layer.add_child(shadow)

		var body := TextureRect.new()
		body.texture = tex
		body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		body.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		body.scale = Vector2(sc, sc)
		body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_layer.add_child(body)

		return title_layer

	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.custom_minimum_size = Vector2(760.0, 110.0)

	var glow_t := Label.new()
	glow_t.text = text
	glow_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glow_t.add_theme_font_size_override("font_size", 78.0)
	glow_t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 0.35))
	if fnt != null:
		glow_t.add_theme_font_override("font", fnt)
	glow_t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(glow_t)

	var shadow_t := Label.new()
	shadow_t.text = text
	shadow_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow_t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shadow_t.add_theme_font_size_override("font_size", 74.0)
	shadow_t.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.55))
	shadow_t.position = Vector2(6.0, 10.0)
	if fnt != null:
		shadow_t.add_theme_font_override("font", fnt)
	shadow_t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(shadow_t)

	var body_t := Label.new()
	body_t.text = text
	body_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_t.add_theme_font_size_override("font_size", 74.0)
	body_t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	body_t.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	body_t.add_theme_constant_override("outline_size", 4)
	if fnt != null:
		body_t.add_theme_font_override("font", fnt)
	body_t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(body_t)
	return wrap

# 角色卡面背景按钮（与全局其它按钮统一）：系统字体 + info_panel 9 宫格背景
func _make_card_button(text: String, cb: Callable, accent: Color, min_sz: Vector2 = Vector2(240.0, 64.0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_sz
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxTexture.new()
	sb.texture = load(PANEL_TEX_PATH)
	sb.texture_margin_left = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_bottom = 28.0
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.modulate_color = Color(1.15, 1.15, 1.2)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sbh.duplicate()
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 3)
	b.pressed.connect(cb)
	return b

func _make_img_button(tex_path: String, text: String, cb: Callable, normal_col: Color, border_col: Color, min_size: Vector2 = Vector2(240.0, 64.0), scale_factor: float = 1.0) -> Control:
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		var sz := tex.get_size()
		var visual := _make_outline_visual(tex)
		if scale_factor != 1.0:
			visual.custom_minimum_size = sz * scale_factor
			visual.scale = Vector2(scale_factor, scale_factor)
		var hit := _make_hit(sz, cb)
		hit.mouse_entered.connect(func(): _tween_btn_glow(visual, 1.0))
		hit.mouse_exited.connect(func(): _tween_btn_glow(visual, 0.0))
		hit.button_down.connect(func(): visual.self_modulate = Color(0.82, 0.82, 0.82, 1.0))
		hit.button_up.connect(func(): visual.self_modulate = Color(1.0, 1.0, 1.0, 1.0))
		visual.add_child(hit)
		return visual

	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = normal_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = normal_col * 1.3
	b.add_theme_stylebox_override("hover", sbh)
	b.mouse_entered.connect(func(): b.self_modulate = Color(1.2, 1.2, 1.2, 1.0))
	b.mouse_exited.connect(func(): b.self_modulate = Color(1.0, 1.0, 1.0, 1.0))
	b.pressed.connect(cb)
	return b

func _make_outline_visual(tex: Texture2D) -> TextureRect:
	var visual := TextureRect.new()
	visual.texture = tex
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := tex.get_size()
	visual.custom_minimum_size = sz
	visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Assets/Sprites/Title/q_appear.gdshader")
	sm.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.15, 1.0))
	sm.set_shader_parameter("intensity", 0.0)
	sm.set_shader_parameter("thickness", max(2.0, sz.x * 0.012))
	sm.set_shader_parameter("glow", max(5.0, sz.x * 0.03))
	sm.set_shader_parameter("progress", 1.0)
	sm.set_shader_parameter("dissolve_edge", 0.10)
	sm.set_shader_parameter("dissolve_color", Color(1.0, 0.9, 0.55, 1.0))
	visual.material = sm
	visual.set_meta("sm", sm)
	return visual

func _make_hit(sz: Vector2, cb: Callable) -> Button:
	var hit := Button.new()
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.custom_minimum_size = sz
	hit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.pressed.connect(cb)
	return hit

func _tween_btn_glow(visual: TextureRect, target: float) -> void:
	var sm = visual.get_meta("sm", null)
	if sm == null or not (sm is ShaderMaterial):
		return
	var old = sm.get_meta("gtw", null)
	if old != null and old is Tween and old.is_valid():
		old.kill()
	var tw := create_tween()
	var cur: float = float(sm.get_shader_parameter("intensity"))
	tw.tween_method(func(v: float): sm.set_shader_parameter("intensity", v), cur, target, 0.18)
	sm.set_meta("gtw", tw)
