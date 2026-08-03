extends Control

const LEVEL_CHALLENGE_SCENE := "res://Scenes/level_challenge.tscn"
const MENU_SCENE := "res://Scenes/menu.tscn"
const FONT_DIR := "res://Assets/Fonts/"
const TITLE_DIR := "res://Assets/Sprites/Title/"
const BTN_DIR := "res://Assets/Sprites/UI/Buttons/"
const PANEL_TEX_PATH := "res://Assets/Sprites/UI/info_panel.png"
const TITLE_SCALE: float = 1.6
const NOVICE_LEVELS: Array[String] = ["level_01", "level_02", "level_03"]

var _fnt: Font = null
var _title_labels: Array[Label] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fnt = _load_font()
	_build_background()
	_build_top_bar()
	_build_bottom_bar()
	_show_category_select()

func _build_background() -> void:
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

func _build_top_bar() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	top.add_child(_spacer(18.0))
	top.add_child(_make_title_styled("关卡选择", _fnt))
	add_child(top)

func _build_bottom_bar() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 10)
	bottom.add_child(_spacer(24.0))
	var back := _make_img_button(BTN_DIR + "back_to_menu.png", "返回主菜单", _on_back,
		Color(0.18, 0.14, 0.22), Color(0.78, 0.45, 0.98), Vector2(240.0, 64.0), 0.8)
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_row.add_child(back)
	bottom.add_child(back_row)
	bottom.add_child(_spacer(22.0))
	add_child(bottom)

func _show_category_select() -> void:
	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 120.0
	content.offset_bottom = -120.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_top = 0.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 60)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hbox)

	var novice_btn := _make_category_card("新手关卡", "适合初学者的基础挑战", Color(0.35, 0.85, 0.55), "🗡️", false, func():
		RunStats.level_category = "novice"
		get_tree().change_scene_to_file(LEVEL_CHALLENGE_SCENE))
	hbox.add_child(novice_btn)

	var all_novice_done: bool = true
	for id in NOVICE_LEVELS:
		if not RunStats.is_level_completed(id):
			all_novice_done = false
			break
	var official_btn := _make_category_card("正式关卡", "通关所有新手关卡后解锁", Color(0.35, 0.85, 0.55), "🗡️", not all_novice_done, func():
		if all_novice_done:
			RunStats.level_category = "official"
			get_tree().change_scene_to_file(LEVEL_CHALLENGE_SCENE))
	hbox.add_child(official_btn)

func _make_category_card(title: String, desc: String, accent: Color, icon: String, locked: bool, cb: Callable) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(300.0, 320.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_card_panel_style(panel, true, false)
	wrap.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24.0
	vbox.offset_right = -24.0
	vbox.offset_top = 20.0
	vbox.offset_bottom = -20.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 52)
	icon_lbl.add_theme_color_override("font_color", accent)
	icon_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	if _fnt != null:
		title_lbl.add_theme_font_override("font", _fnt)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(title_lbl)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(120.0, 2.0)
	sep.color = Color(accent.r, accent.g, accent.b, 0.4)
	sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(sep)

	var desc_lbl := Label.new()
	if locked:
		desc_lbl.text = "🔒 " + desc
	else:
		desc_lbl.text = desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62) if locked else Color(0.80, 0.82, 0.88))
	desc_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(desc_lbl)

	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)

	if locked:
		_apply_card_panel_style(panel, true, false)
		hit.mouse_entered.connect(func():
			var tw := create_tween()
			tw.tween_property(wrap, "rotation", -0.02, 0.04)
			tw.tween_property(wrap, "rotation", 0.02, 0.08)
			tw.tween_property(wrap, "rotation", -0.015, 0.06)
			tw.tween_property(wrap, "rotation", 0.0, 0.05))
		hit.pressed.connect(func():
			desc_lbl.text = "❌ 未完成全部新手关卡"
			desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
			var tw := create_tween()
			tw.tween_property(wrap, "rotation", -0.03, 0.04)
			tw.tween_property(wrap, "rotation", 0.03, 0.06)
			tw.tween_property(wrap, "rotation", -0.02, 0.05)
			tw.tween_property(wrap, "rotation", 0.0, 0.03)
			tw.tween_callback(func():
				desc_lbl.text = "🔒 " + desc
				desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))))
	else:
		hit.mouse_entered.connect(func():
			_apply_card_panel_style(panel, true, true)
			var tw := create_tween()
			tw.tween_property(wrap, "scale", Vector2(1.03, 1.03), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC))
		hit.mouse_exited.connect(func():
			_apply_card_panel_style(panel, true, false)
			var tw := create_tween()
			tw.tween_property(wrap, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC))
		hit.pressed.connect(cb)
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

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

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

	_title_labels = [glow_t, shadow_t, body_t]
	return wrap

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
