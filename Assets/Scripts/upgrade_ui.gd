extends CanvasLayer

## 升级选择界面：玩家升级时暂停游戏，弹出技能卡供选择。
## 卡片数据来自 SkillManager.roll_choices()（技能池抽卡），显示图标/名称/星级/描述。
## 点击卡片或按 1/2/3 选择 -> SkillManager.grant(id) -> 应用 -> 恢复游戏（多级连升继续弹）。

var _player: Node2D = null
var _overlay: ColorRect
var _title: Label
var _hint: Label
var _cards: Array[Button] = []

# 复用的样式（创建一次，应用到三张卡）
var _sb_normal: StyleBox
var _sb_hover: StyleBox
var _sb_pressed: StyleBox
var _sb_empty: StyleBox

# 三卡须在 1152 屏宽内排下；CARD_W 取极限宽度，间距压到最小
const CARD_W: float = 374.0
const CARD_H: float = 448.0
const ICON_SIZE: float = 96.0

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	_build_ui()
	_overlay.visible = false
	_refresh_player()
	if _player != null:
		_player.leveled_up.connect(_on_leveled_up)

func _refresh_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _build_styles() -> void:
	# 升级卡底图（card_bg.png），用 StyleBoxTexture 做 9 宫拉伸，圆角不糊
	_sb_normal = StyleBoxTexture.new()
	_sb_normal.texture = preload("res://Assets/Sprites/UI/card_bg.png")
	_sb_normal.texture_margin_left = 24
	_sb_normal.texture_margin_top = 24
	_sb_normal.texture_margin_right = 24
	_sb_normal.texture_margin_bottom = 24
	_sb_hover = _sb_normal
	_sb_pressed = _sb_normal
	# 透明样式盒：卡片底图改用发光层(TextureRect+shader)充当，避免与样式盒双重绘制卡面
	_sb_empty = StyleBoxEmpty.new()

func _build_ui() -> void:
	_overlay = ColorRect.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.03, 0.05, 0.80)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	_overlay.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)

	_title = Label.new()
	vbox.add_child(_title)
	_title.text = "升级！选择一项强化"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", UIColors.GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 4)

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for i in range(3):
		var card := Button.new()
		hbox.add_child(card)
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.size = Vector2(CARD_W, CARD_H)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.clip_contents = true
		card.add_theme_stylebox_override("normal", _sb_empty)
		card.add_theme_stylebox_override("hover", _sb_empty)
		card.add_theme_stylebox_override("pressed", _sb_empty)
		card.add_theme_font_size_override("font_size", 22)
		card.text = ""
		card.visible = false
		card.pressed.connect(_on_card_pressed.bind(i))
		# 内容容器：固定尺寸 Control，clip_contents 裁剪溢出
		var content := Control.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.clip_contents = true
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		card.set_meta("content", content)

		# 悬停发光：复用初始页「?」的 q_appear 描边 shader，贴在 card_bg.png 的
		# 透明边缘上，自然箍住卡面轮廓；悬停时 intensity 0→1 点亮金色描边+外发光
		var glow := TextureRect.new()
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.texture = preload("res://Assets/Sprites/UI/card_bg.png")
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE   # 与 StyleBoxTexture 同样拉伸铺满卡片
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gsm := ShaderMaterial.new()
		gsm.shader = preload("res://Assets/Sprites/Title/q_appear.gdshader")
		gsm.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.15, 1.0))  # 与「?」同款金色
		gsm.set_shader_parameter("intensity", 0.0)
		gsm.set_shader_parameter("thickness", 2.5)
		gsm.set_shader_parameter("glow", 5.0)
		gsm.set_shader_parameter("progress", 1.0)     # 始终完整显示卡面，不做溶解
		gsm.set_shader_parameter("dissolve_edge", 0.10)
		gsm.set_shader_parameter("dissolve_color", Color(1.0, 0.9, 0.55, 1.0))
		glow.material = gsm
		card.add_child(glow)
		card.move_child(glow, 0)   # 置于卡面底图之上、内容之下
		card.set_meta("glow_mat", gsm)
		card.set_meta("glow_tween", null)
		card.mouse_entered.connect(func():
			var m = card.get_meta("glow_mat")
			var tw = card.get_meta("glow_tween")
			if tw != null and tw.is_valid():
				tw.kill()
			tw = create_tween()
			card.set_meta("glow_tween", tw)
			tw.tween_method(func(v): m.set_shader_parameter("intensity", v), m.get_shader_parameter("intensity"), 1.0, 0.18)
		)
		card.mouse_exited.connect(func():
			var m = card.get_meta("glow_mat")
			var tw = card.get_meta("glow_tween")
			if tw != null and tw.is_valid():
				tw.kill()
			tw = create_tween()
			card.set_meta("glow_tween", tw)
			tw.tween_method(func(v): m.set_shader_parameter("intensity", v), m.get_shader_parameter("intensity"), 0.0, 0.24)
		)

		_cards.append(card)

	_hint = Label.new()
	vbox.add_child(_hint)
	_hint.text = "点击卡片，或按 1 / 2 / 3 键选择"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", UIColors.GRAY)

func _on_leveled_up() -> void:
	if _overlay.visible:
		return
	_show_cards()

func is_open() -> bool:
	return _overlay.visible

func _show_cards() -> void:
	if _player == null or not _player.is_inside_tree():
		_refresh_player()
	var choices: Array = SkillManager.roll_choices(3)
	if choices.is_empty():
		# 全部满级/无可选：直接恢复
		if _player != null and _player.has_method("consume_level_up"):
			_player.consume_level_up()
		if _player != null and _player.has_method("get_pending_levels") and _player.get_pending_levels() > 0:
			_show_cards()
		else:
			var _t := get_tree()
			if _t != null: _t.paused = false
		return
	for i in range(_cards.size()):
		var card: Button = _cards[i]
		# 清空旧内容（保留彩色边框）
		var content = card.get_meta("content")
		for c in content.get_children():
			c.queue_free()
		if i >= choices.size():
			card.visible = false
			continue
		var ch: Dictionary = choices[i]
		var id: String = ch["id"]
		var def: Dictionary = SkillManager.SKILLS[id]
		var has_stars: bool = not ch.get("is_new", false)

		# 卡片分上下两区：上区放图标+名称+星级，下区放描述
		var pad_x: float = 24.0
		var inner_w: float = CARD_W - pad_x * 2.0
		var SPLIT_Y: float = CARD_H * 0.48   # 上下分界线（略高于一半）

		# ── 上区：图标靠上，名称+星级靠下 ──
		# 图标：顶部留间距，居中
		var tex_rect := TextureRect.new()
		content.add_child(tex_rect)
		tex_rect.texture = def["icon"]
		tex_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.position = Vector2(pad_x + (inner_w - ICON_SIZE) * 0.5, 70.0)
		tex_rect.size = Vector2(ICON_SIZE, ICON_SIZE)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 名称 + 星级：贴在上区底部
		var bottom_y: float = SPLIT_Y - 8.0
		if has_stars:
			bottom_y -= 28.0
			var star_lbl := Label.new()
			content.add_child(star_lbl)
			star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			star_lbl.add_theme_font_size_override("font_size", 22)
			var cur: int = int(ch["stars"])
			var mx: int = int(def["max_stars"])
			star_lbl.text = "★".repeat(cur) + "☆".repeat(mx - cur)
			star_lbl.add_theme_color_override("font_color", UIColors.GOLD)
			star_lbl.position = Vector2(pad_x, bottom_y)
			star_lbl.size = Vector2(inner_w, 28.0)
			bottom_y -= 4.0

		var name_lbl := Label.new()
		content.add_child(name_lbl)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.text = def["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", UIColors.WHITE)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.position = Vector2(pad_x, bottom_y - 30.0)
		name_lbl.size = Vector2(inner_w, 30.0)

		# ── 下区：描述文字，垂直居中 ──
		var desc_text: String = def.get("desc", "")
		if desc_text != "":
			var wrapped_desc: String = _wrap_every_n(desc_text, 8)
			var line_count: int = wrapped_desc.count("\n") + 1
			var desc_block_h: float = line_count * 20.0
			var desc_y: float = SPLIT_Y + (CARD_H - SPLIT_Y - desc_block_h) * 0.3
			var desc_lbl := Label.new()
			content.add_child(desc_lbl)
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc_lbl.text = wrapped_desc
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			desc_lbl.add_theme_font_size_override("font_size", 14)
			desc_lbl.add_theme_color_override("font_color", UIColors.GRAY)
			desc_lbl.position = Vector2(pad_x, desc_y)
			desc_lbl.size = Vector2(inner_w, desc_block_h)

		card.set_meta("skill_id", id)
		card.visible = true
	_overlay.visible = true
	var _t := get_tree()
	if _t != null: _t.paused = true

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _cards.size():
		return
	if not _cards[idx].visible:
		return
	if AudioManager != null:
		AudioManager.play_select_sfx()
	var id: String = _cards[idx].get_meta("skill_id")
	SkillManager.grant(id)
	_overlay.visible = false
	if _player != null and _player.has_method("consume_level_up"):
		_player.consume_level_up()
	if _player != null and _player.has_method("get_pending_levels") and _player.get_pending_levels() > 0:
		_show_cards()
	else:
		var _t := get_tree()
		if _t != null: _t.paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _on_card_pressed(0)
			KEY_2: _on_card_pressed(1)
			KEY_3: _on_card_pressed(2)

func _wrap_every_n(text: String, n: int) -> String:
	var result: String = ""
	var count: int = 0
	for ch in text:
		if ch == "\n":
			result += ch
			count = 0
		else:
			result += ch
			count += 1
			if count >= n:
				result += "\n"
				count = 0
	return result
