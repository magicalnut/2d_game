extends Control

## 角色出战设置（强制前置）：从 RunStats.CHARACTERS 中选取一个角色，
## 写入 RunStats.chosen_character；「确认出战」后要先选择挑战模式（无尽/关卡），
## 才能进入战斗场景。由 SkillManager 按角色授予初始武器，player.gd 按角色加载对应外观。
##
## 选角交互：3D 旋转木马（Carousel）—— 角色卡排成圆环，选中者居中正对、放大高亮，
## 两侧卡片向后退并带透视缩放 / 透明 / 倾斜，切换时整体旋转转到下一角色。
## 皮肤就位显示真实精灵图（idle 第一帧），否则显示配色占位。

const MENU_SCENE := "res://Scenes/menu.tscn"
const ENDLESS_SCENE := "res://Scenes/main.tscn"
const LEVEL_SCENE := "res://Scenes/level_mode.tscn"
const FONT_DIR := "res://Assets/Fonts/"
# 预渲染文字块素材目录：每张图为「角色id_槽位.png」，缺失则退回系统文字
# 槽位：name=角色名 / desc=描述 / wp=「初始武器：X」行
const TEXT_BIT_DIR := "res://Assets/Sprites/UI/TextBits/"
const TEXT_BIT_BRIGHTNESS := 1.35   # 文字块图统一提亮系数（>1 变亮）
const BTN_DIR := "res://Assets/Sprites/UI/Buttons/"   # 预渲染按钮图（确认出战/返回主菜单）
const TITLE_DIR := "res://Assets/Sprites/Title/"
const SLOT_DIR := "res://Assets/Sprites/UI/Slots/"   # 出战页六装备槽未来素材目录：放入 {id}.png 即自动显示（id 见 _DEPLOY_SLOTS）
const CARD_BACK_TEX := "res://Assets/Sprites/UI/info_panel.png"   # 角色卡面背景（装备选择面板复用）
const GEAR_ICON_DIR := "res://Assets/Sprites/UI/Gear/"   # 单件装备图标（按 def_id 命名，如 rune_of_fire.png）
const DEPLOY_BG_DIR := "res://Assets/Sprites/UI/DeployBG/"   # 出战页背景图目录：放入 deploy_bg.png 即自动作为整备页背景
# 出战整备页：角色卡居中，左右各三装备槽呈发散(扇形)分布；pos 为槽左上角(相对舞台本地坐标，舞台 680×560)
const _DEPLOY_SLOTS: Array = [
	{"id": "rune",   "name": "符文", "pos": Vector2(106.0, 110.0)},
	{"id": "pet",    "name": "宠物", "pos": Vector2(74.0, 213.0)},
	{"id": "amulet", "name": "护符", "pos": Vector2(106.0, 316.0)},
	{"id": "potion", "name": "药剂", "pos": Vector2(500.0, 110.0)},
	{"id": "token",  "name": "信物", "pos": Vector2(532.0, 213.0)},
	{"id": "relic",  "name": "圣物", "pos": Vector2(500.0, 316.0)},
]
const _DEPLOY_STAGE_W: float = 680.0
const _DEPLOY_STAGE_H: float = 600.0   # 底部：无尽+关卡并排一行、重选居中在下方
const _DEPLOY_CARD_POS: Vector2 = Vector2(240.0, 115.0)   # 角色卡左上角（中心仍保持 340,250，连线不变）
const _DEPLOY_CARD_SIZE: Vector2 = Vector2(200.0, 270.0)  # 与选择页 CARD_W/CARD_H 一致，复用素材不必缩小
const _DEPLOY_SLOT_SIZE: float = 74.0                     # 装备槽 0.8× 原 92
const _DEPLOY_FRAME_DISP: float = 82.0                    # 外框显示尺寸（=槽位74+每边溢出4px，「框中框」）
const _DEPLOY_CARD_CENTER: Vector2 = Vector2(340.0, 250.0)

const CARD_W: float = 200.0
const CARD_H: float = 270.0
const STAGE_W: float = 820.0
const STAGE_H: float = 340.0

const SPREAD: float = 340.0      # 圆环水平半径（决定相邻卡的间距），略增以拉开间距
const SCALE_MIN: float = 0.45    # 背面卡片的缩放（更小→纵深更强）
const SCALE_MAX: float = 1.08    # 正面（选中）卡片的缩放
const LIFT: float = 0.0          # 0=所有卡片中心线水平一致，选中卡不会高于两侧
const TILT: float = 0.22         # 两侧卡片倾斜（弧度），加大以强化立体感
const _BTN_CORNER: float = 14.0  # 统一按钮圆角（确认/返回/挑战）
const _ARROW_CORNER: float = 18.0 # 左右大箭头圆角（更大更圆润）

var _char_ids: Array = []
var _selected: int = 0
var _cards: Array = []           # 每张卡 = _create_card() 返回的字典，与 _char_ids 一一对应
var _stage: Control = null       # 旋转木马舞台（用于取真实屏幕中心）
var _stage_center: Vector2 = Vector2.ZERO
var _phase: float = 0.0          # 当前旋转相位（连续值，用于平滑旋转）
var _phase_target: float = 0.0   # 目标相位（_select 时更新）
var _bottom: VBoxContainer = null
var _nav_left: Control = null
var _nav_right: Control = null
var _confirmed: bool = false
var _bit_cache: Dictionary = {}   # 文字块图 path -> 裁好透明边的 Image（未缩放，按 target 缩放显示）
var _deploy_lv_label: Label = null
var _deploy_dia_label: Label = null
var _deploy_up_btn: Button = null
var _deploy_buy_btn: Button = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if RunStats != null:
		_char_ids = RunStats.CHARACTERS.keys()
		_selected = _char_ids.find(RunStats.chosen_character)
		if _selected < 0:
			_selected = 0
	_build_ui()
	var step: float = TAU / float(max(_char_ids.size(), 1))
	_phase = -_selected * step
	_phase_target = _phase

func _build_ui() -> void:
	# 背景图 + 轻度暗化 + 径向暗角（聚焦中央，让视线落在转盘上）
	var bg_img := TextureRect.new()
	bg_img.texture = preload("res://Assets/Sprites/UI/menu_bg.png")
	bg_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_img.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_img.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg_img)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.38)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 背景鬼影：红色幽灵在背景层游荡（位于暗角层之下、卡片之后，更融入背景）
	var gl_char := preload("res://Assets/Scripts/ghost_layer.gd").new()
	gl_char.ghost_dir = "res://Assets/Sprites/Ghosts/Red/"
	add_child(gl_char)

	var vig := TextureRect.new()
	vig.texture = _make_vignette(0.5)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(vig)

	# 角落骷髅：左下/右下各一只（红色，位于暗角之上、卡片之后）
	var sk_char := preload("res://Assets/Scripts/skull_layer.gd").new()
	sk_char.skull_dir = "res://Assets/Sprites/Skulls/Red/"
	sk_char.skull_tint = Color(0.6, 0.6, 0.66, 1.0)   # 红色骷髅调暗到与初始页白骷髅同一暗度（值越小越暗，1.0=原样）
	add_child(sk_char)

	# —— 旋转木马舞台：铺满全屏的叠加层，主卡中心锚定屏幕正中 ——
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	for j in _char_ids.size():
		var parts := _create_card()
		_stage.add_child(parts.panel)
		_set_card_content(parts, RunStats.CHARACTERS[_char_ids[j]], _char_ids[j])
		_cards.append(parts)

	# —— 顶部标题（叠加层，不拦截点击）——
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	top.add_child(_spacer(8.0))   # 标题距顶部的距离（想再上移改小，想下移改大）
	var fnt: Font = _load_font()
	var title := _make_title_styled("选择你的角色", fnt)
	top.add_child(title)
	add_child(top)

	# —— 底部控制栏（叠加层，按钮可点击）——
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 10)

	# 注：底部信息条（角色名+武器）已移除——卡片本体已显示这些信息，原信息条会在
	# 「返回主菜单」按钮处重复/被遮挡地多显示一个角色名，造成用户报告的额外“学者”二字。

	# 确认出战 + 返回主菜单：同一行并排，压缩底部高度，避免与卡片重叠
	# 优先用预渲染按钮图（TextureButton），素材缺失自动回退到文字按钮，不崩
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 18)
	var start := _make_img_button(BTN_DIR + "confirm_battle.png", "确认出战", _on_confirm, Color(0.16, 0.42, 0.26), Color(0.55, 1.0, 0.65), Vector2(240.0, 64.0), 0.8)
	action_row.add_child(start)
	var back := _make_img_button(BTN_DIR + "back_to_menu.png", "返回主菜单", _on_back, Color(0.18, 0.14, 0.22), Color(0.78, 0.45, 0.98), Vector2(240.0, 64.0), 0.8)
	action_row.add_child(back)
	bottom.add_child(action_row)

	_bottom = bottom
	add_child(bottom)

	# 左右两侧「上一个 / 下一个」大箭头：悬浮于卡片两侧，绝不与卡片或底部描述重叠
	_add_side_nav()

func _create_card() -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(CARD_W, CARD_H)
	panel.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	# 角色背板：用自制 info_panel.png 作底板（9 宫格自适应卡片 200×270，不拉伸变形）
	var back_tex_path := "res://Assets/Sprites/UI/info_panel.png"
	if ResourceLoader.exists(back_tex_path):
		var st := StyleBoxTexture.new()
		st.texture = load(back_tex_path)
		st.texture_margin_left = 28.0
		st.texture_margin_top = 28.0
		st.texture_margin_right = 28.0
		st.texture_margin_bottom = 28.0
		panel.add_theme_stylebox_override("panel", st)
	else:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.10, 0.13, 0.18)
		fb.set_border_width_all(2)
		fb.set_corner_radius_all(14)
		panel.add_theme_stylebox_override("panel", fb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(110.0, 110.0)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(avatar)
	var nm := Label.new()
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_text_bit_slot(nm)
	v.add_child(nm)
	var wp := Label.new()
	wp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wp.add_theme_font_size_override("font_size", 15)
	wp.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_text_bit_slot(wp)
	v.add_child(wp)
	return {"panel": panel, "avatar": avatar, "name": nm, "weapon": wp}

# 为文字 Label 挂载一个隐藏的图片槽（Img 子节点），供 _apply_bit 复用
func _add_text_bit_slot(label: Label) -> void:
	var img := TextureRect.new()
	img.name = "Img"
	img.visible = false
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_child(img)

# 用预渲染文字图替换（或退回）Label 文字：
# 目录内有「{id}_{slot}.png」则裁掉透明边距、等比缩放到 fit 进 target 显示；缺失则显示系统文字。
# target = 该槽位允许的最大显示尺寸(宽,高)；同一张图在卡片/信息条用不同 target 即可得到不同显示大小。
func _apply_bit(label: Label, id: String, slot: String, text: String, color: Color, target: Vector2) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	var path := TEXT_BIT_DIR + id + "_" + slot + ".png"
	var img: TextureRect = label.get_node_or_null("Img")
	if ResourceLoader.exists(path):
		var cropped: Image = null
		if not _bit_cache.has(path):
			var src := Image.new()
			if src.load(path) == OK:
				_bit_cache[path] = _tight_crop(src)
		cropped = _bit_cache.get(path, null)
		if cropped != null:
			# 等比缩放 fit 进 target（不溢出任一维度）
			var cw: int = cropped.get_width()
			var ch: int = cropped.get_height()
			var sc: float = min(target.x / float(cw), target.y / float(ch))
			var dw: int = int(float(cw) * sc)
			var dh: int = int(float(ch) * sc)
			var disp: Image = cropped.duplicate()
			disp.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
			disp.adjust_bcs(TEXT_BIT_BRIGHTNESS, 1.0, 1.0)   # 提亮文字块图（角色名/武器行偏暗）
			var itex: ImageTexture = ImageTexture.create_from_image(disp)
			if img == null:
				_add_text_bit_slot(label)
				img = label.get_node_or_null("Img")
			img.texture = itex
			img.visible = true
			label.text = ""                                  # 有图则隐藏文字，只显示图片
			label.custom_minimum_size = Vector2(dw, dh)       # 用缩放后尺寸撑开，正好显示、不溢出
			return
	if img != null:
		img.visible = false
	label.text = text
	label.custom_minimum_size = Vector2(0.0, 0.0)           # 退回文字：恢复自动高度

# 裁掉图片四周边透明区域，返回贴住不透明像素的 Image；全透明返回 null
func _tight_crop(img: Image) -> Image:
	var w := img.get_width(); var h := img.get_height()
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.02:
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
	if maxx < 0:
		return null
	return img.get_region(Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1))

func _set_card_content(parts: Dictionary, def: Dictionary, char_id: String) -> void:
	var wname: String = "?"
	if SkillManager != null and SkillManager.SKILLS.has(def["start_weapon"]):
		wname = SkillManager.SKILLS[def["start_weapon"]]["name"]
	_apply_bit(parts.name, char_id, "name", def["name"], Color(1.0, 0.9, 0.6), Vector2(138.0, 40.0))
	_apply_bit(parts.weapon, char_id, "wp", "初始武器：" + wname, Color(0.85, 0.88, 0.92), Vector2(150.0, 33.0))
	# 头像：皮肤就位显示真实精灵图（idle 第一帧），否则配色占位（复用 _fill_avatar，出战页同款立绘）
	_fill_avatar(parts.avatar, def)

# 把 def 的 idle 帧立绘填进 avatar 控件（选择卡与出战卡共用，保证素材一致、不糊）
func _fill_avatar(avatar: Control, def: Dictionary) -> void:
	for c in avatar.get_children():
		c.queue_free()
	var sheet: String = def.get("sheet", "")
	if ResourceLoader.exists(sheet):
		var tex: Texture2D = load(sheet)
		var idle_region: Rect2 = def.get("idle_region", Rect2(0, 150, 76, 75))
		if tex != null and idle_region.position.x + idle_region.size.x <= tex.get_width() and idle_region.position.y + idle_region.size.y <= tex.get_height():
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = idle_region   # 各角色独立 idle 帧区域
			var tr := TextureRect.new()
			tr.texture = at
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # 居中、保比例、不拉伸变形
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST        # 像素/小图放大后更锐利，不糊
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			avatar.add_child(tr)
			return
	var cr := ColorRect.new()
	cr.color = def.get("accent", Color(0.6, 0.6, 0.6))
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(cr)
	var lb := Label.new()
	lb.text = def["name"].substr(0, 1)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 40)
	lb.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(lb)

# —— 旋转木马核心：每帧按相位重排所有卡片 ——
func _process(delta: float) -> void:
	if _char_ids.size() == 0:
		return
	_phase = lerp(_phase, _phase_target, 1.0 - exp(-delta * 9.0))
	_relayout()

func _relayout() -> void:
	var n: int = _char_ids.size()
	var step: float = TAU / float(n)
	# 主卡中心锚定「屏幕正中」（每帧按视口真实尺寸计算，彻底摆脱 vbox 布局偏移）
	_stage_center = get_viewport_rect().size * 0.5
	_stage_center.y -= 18.0   # 卡片中心锚定屏幕正中（底部控制栏已压缩，不再与卡片重叠）
	for j in _cards.size():
		var c: Dictionary = _cards[j]
		var p: Control = c.panel
		var raw: float = float(j) * step + _phase
		var a: float = fposmod(raw + PI, TAU) - PI   # 归一化到 [-PI, PI]，0 = 正前方
		var cos_a: float = cos(a)
		var t: float = cos_a * 0.5 + 0.5             # 0(背面) .. 1(正面)
		var x: float = sin(a) * SPREAD
		var y: float = (1.0 - cos_a) * LIFT   # 选中卡(a=0)的 y=0 → 严格居中；侧/背卡自然下沉形成纵深
		# position 指左上角；减去半个卡身让「中心」对准目标点，避免整体偏移
		p.position = _stage_center + Vector2(x, y) - Vector2(CARD_W, CARD_H) * 0.5
		var sc: float = SCALE_MIN + (SCALE_MAX - SCALE_MIN) * t
		p.scale = Vector2(sc, sc)
		p.rotation = sin(a) * TILT
		p.modulate = Color(0.55 + 0.45 * t, 0.55 + 0.45 * t, 0.55 + 0.45 * t, 0.18 + 0.82 * t)  # 背面更暗更透→纵深更强
		p.z_index = int(cos_a * 100)

func _select(idx: int) -> void:
	var n: int = _char_ids.size()
	if n == 0:
		return
	idx = int(fposmod(idx, n))
	if idx == _selected:
		return
	_selected = idx
	# 计算目标相位：让第 idx 张卡转到正前方（a = 0）
	var step: float = TAU / float(n)
	var target: float = -idx * step
	# 走最短路径，避免整圈空转
	while target - _phase_target > PI:
		target -= TAU
	while target - _phase_target < -PI:
		target += TAU
	_phase_target = target

func _unhandled_input(ev: InputEvent) -> void:
	if _confirmed:
		return   # 已确认出战，等待选择挑战模式
	if ev.is_action_pressed("ui_left"):
		_select(_selected - 1)
	elif ev.is_action_pressed("ui_right"):
		_select(_selected + 1)

func _make_nav(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150.0, 52.0)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.30, 0.42)
	sb.border_color = Color(0.4, 0.8, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.26, 0.42, 0.58)
	b.add_theme_stylebox_override("hover", sb_h)
	b.z_index = 1000            # 双保险：按钮自身也提到最高层
	b.pressed.connect(cb)
	return b

# 左右两侧的大箭头导航：锚定屏幕左右边缘、垂直与卡片中心对齐，
# 悬浮在卡片两侧，既不遮挡卡片主体，也不与底部职业描述重叠。
func _add_side_nav() -> void:
	var W: float = 118.0         # 箭头显示尺寸（与预缩放后的图片一致）
	var H: float = 118.0
	var y_shift: float = 18.0    # 相对垂直中心上移一点
	var left := _make_arrow("left", func(): _select(_selected - 1))
	left.custom_minimum_size = Vector2(W, H)
	left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	left.offset_left = 18.0
	left.offset_right = 18.0 + W
	left.offset_top = -H * 0.5 - y_shift
	left.offset_bottom = H * 0.5 - y_shift
	left.z_index = 1000
	_nav_left = left
	add_child(left)

	var right := _make_arrow("right", func(): _select(_selected + 1))
	right.custom_minimum_size = Vector2(W, H)
	right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	right.offset_right = -18.0
	right.offset_left = -18.0 - W
	right.offset_top = -H * 0.5 - y_shift
	right.offset_bottom = H * 0.5 - y_shift
	right.z_index = 1000
	_nav_right = right
	add_child(right)

# 左右导航箭头：优先用素材图片（TextureButton），素材缺失时回退到文字箭头，避免崩溃。
# 素材位置：Assets/Sprites/UI/NavArrows/nav_arrow_left.png（你提供） /
#                                            nav_arrow_right.png（由左图水平翻转生成）
func _make_arrow(side: String, cb: Callable) -> Control:
	var path := "res://Assets/Sprites/UI/NavArrows/nav_arrow_%s.png" % side
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		var sz := tex.get_size()
		var visual := _make_outline_visual(tex)
		visual.name = "NavArrow_" + side
		var hit := _make_hit(sz, cb)
		hit.mouse_entered.connect(func(): _tween_btn_glow(visual, 1.0))
		hit.mouse_exited.connect(func(): _tween_btn_glow(visual, 0.0))
		hit.button_down.connect(func(): visual.self_modulate = Color(0.78, 0.78, 0.78, 1.0))
		hit.button_up.connect(func(): visual.self_modulate = Color(1.0, 1.0, 1.0, 1.0))
		visual.add_child(hit)      # 透明输入层盖在视觉层之上
		return visual
	else:
		# 回退：原始文字箭头
		var b := Button.new()
		b.text = "‹" if side == "left" else "›"
		b.add_theme_font_size_override("font_size", 60)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.24, 0.36, 0.82)
		sb.border_color = Color(0.45, 0.85, 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(16)
		b.add_theme_stylebox_override("normal", sb)
		var sb_h := sb.duplicate()
		sb_h.bg_color = Color(0.26, 0.44, 0.62)
		b.add_theme_stylebox_override("hover", sb_h)
		b.z_index = 1000
		b.pressed.connect(cb)
		return b

func _on_confirm() -> void:
	if RunStats != null:
		RunStats.chosen_character = _char_ids[_selected]
	_show_challenge_picker()

# 确认出战 → 出战整备页：左侧英雄卡 + 六装备槽 + 模式选择 + 槽位等级升级
func _show_challenge_picker() -> void:
	_confirmed = true
	if _stage != null:
		_stage.visible = false
	if _nav_left != null:
		_nav_left.visible = false
	if _nav_right != null:
		_nav_right.visible = false
	if _bottom != null:
		_bottom.visible = false

	var id: String = _char_ids[_selected]
	var def: Dictionary = RunStats.CHARACTERS[id]

	# 加载角色专属装备配置
	if RunStats != null:
		if RunStats.character_gear.has(id):
			RunStats.equipped_gear = RunStats.character_gear[id].duplicate(true)
		else:
			RunStats.equipped_gear = {}

	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.name = "ChallengePicker"
	# 背景图
	var bg_candidates: Array[String] = ["deploy_bg.png", "deploy_bg.jpg", "deploy_bg.jpeg", "deploy_bg.webp"]
	var bg_tex: Texture2D = null
	for cand: String in bg_candidates:
		var p: String = DEPLOY_BG_DIR + cand
		if ResourceLoader.exists(p):
			var t = load(p)
			if t is Texture2D:
				bg_tex = t
				break
	var has_bg := bg_tex != null
	if has_bg:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal.add_child(bg)

	var dim_alpha: float = 0.82
	if has_bg:
		dim_alpha = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(_DEPLOY_STAGE_W, _DEPLOY_STAGE_H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 0) 顶部信息栏：槽位等级 + 钻石数量 + 升级 / 合成 / 购买按钮
	if EquipmentManager != null:
		var info_bar := HBoxContainer.new()
		info_bar.position = Vector2(10.0, 8.0)
		info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(info_bar)
		_deploy_lv_label = Label.new()
		_deploy_lv_label.text = "装备槽 Lv.%d / 12" % EquipmentManager.get_slot_level()
		_deploy_lv_label.add_theme_font_size_override("font_size", 16)
		_deploy_lv_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		info_bar.add_child(_deploy_lv_label)
		info_bar.add_child(_spacer(20.0))
		_deploy_dia_label = Label.new()
		_deploy_dia_label.text = "💎 %d" % EquipmentManager.get_diamonds()
		_deploy_dia_label.add_theme_font_size_override("font_size", 16)
		_deploy_dia_label.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
		info_bar.add_child(_deploy_dia_label)
		info_bar.add_child(_spacer(12.0))
		_deploy_up_btn = Button.new()
		_deploy_up_btn.text = "升级"
		_deploy_up_btn.custom_minimum_size = Vector2(60.0, 28.0)
		_deploy_up_btn.add_theme_font_size_override("font_size", 14)
		var up_cost: int = EquipmentManager.get_next_upgrade_cost()
		if up_cost < 0:
			_deploy_up_btn.text = "已满级"
			_deploy_up_btn.disabled = true
		else:
			_deploy_up_btn.text = "升级(%d💎)" % up_cost
		_deploy_up_btn.pressed.connect(_on_upgrade_slot)
		info_bar.add_child(_deploy_up_btn)
		info_bar.add_child(_spacer(8.0))
		_deploy_buy_btn = Button.new()
		_deploy_buy_btn.text = "购买(%d💎)" % EquipmentManager.BUY_GEAR_COST
		_deploy_buy_btn.custom_minimum_size = Vector2(96.0, 28.0)
		_deploy_buy_btn.add_theme_font_size_override("font_size", 14)
		_deploy_buy_btn.disabled = EquipmentManager.get_diamonds() < EquipmentManager.BUY_GEAR_COST
		_deploy_buy_btn.pressed.connect(_on_buy_gear)
		info_bar.add_child(_deploy_buy_btn)
		var synth_btn := Button.new()
		synth_btn.text = "合成"
		synth_btn.custom_minimum_size = Vector2(56.0, 28.0)
		synth_btn.add_theme_font_size_override("font_size", 14)
		synth_btn.pressed.connect(_show_synthesis_panel)
		info_bar.add_child(synth_btn)

	# 1) 连线
	var link_tex_path := SLOT_DIR + "link.png"
	var link_tex: Texture2D = null
	if ResourceLoader.exists(link_tex_path):
		link_tex = load(link_tex_path)
	for cfg in _DEPLOY_SLOTS:
		var slot_c: Vector2 = cfg.pos + Vector2(_DEPLOY_SLOT_SIZE, _DEPLOY_SLOT_SIZE) * 0.5
		var line := Line2D.new()
		line.points = [_DEPLOY_CARD_CENTER, slot_c]
		line.width = 18.0
		if link_tex != null:
			line.texture = link_tex
			line.texture_mode = 2
			line.default_color = Color(1.0, 1.0, 1.0, 1.0)
		else:
			line.default_color = Color(0.5, 0.6, 0.75, 0.45)
		stage.add_child(line)

	# 2) 角色卡
	var card := _make_deploy_card(def, id)
	card.position = _DEPLOY_CARD_POS
	stage.add_child(card)

	# 3) 六装备槽（带解锁状态和交互）
	for cfg in _DEPLOY_SLOTS:
		var gear_inst: Dictionary = {}
		if RunStats != null and RunStats.equipped_gear.has(cfg.id):
			gear_inst = RunStats.equipped_gear[cfg.id]
		stage.add_child(_make_slot(cfg.name, cfg.id, cfg.pos, gear_inst))

	# 4) 底部模式按钮：info_panel 卡片风格（与关卡选择页一致）
	var endless := _make_mode_card("无尽模式", "无限波次 · 生存挑战", Color(0.55, 1.0, 0.65), func():
		RunStats.chosen_character = id
		if RunStats != null:
			RunStats.character_gear[id] = RunStats.equipped_gear.duplicate(true)
		RunStats.deploy_difficulty = 0
		get_tree().change_scene_to_file(ENDLESS_SCENE))
	endless.position = Vector2(130.0, 418.0)
	stage.add_child(endless)
	var levels := _make_mode_card("关卡模式", "目标挑战 · 解锁关卡", Color(0.65, 0.60, 1.0), func():
		RunStats.chosen_character = id
		if RunStats != null:
			RunStats.character_gear[id] = RunStats.equipped_gear.duplicate(true)
		RunStats.game_mode = "level"
		get_tree().change_scene_to_file("res://Scenes/level_mode.tscn"))
	levels.position = Vector2(350.0, 418.0)
	stage.add_child(levels)

	# 5) 重新选择角色
	var reback := _make_img_button(BTN_DIR + "reselect_char.png", "重新选择角色", func():
		get_tree().change_scene_to_file("res://Scenes/character_setup.tscn"),
		Color(0.18, 0.14, 0.22), Color(0.78, 0.45, 0.98), Vector2(269.0, 90.0), 0.68)
	reback.position = Vector2(251.0, 530.0)
	stage.add_child(reback)

	center.add_child(stage)
	modal.add_child(center)
	add_child(modal)

func _refresh_deploy_info() -> void:
	if EquipmentManager == null:
		return
	if _deploy_lv_label != null:
		_deploy_lv_label.text = "装备槽 Lv.%d / 12" % EquipmentManager.get_slot_level()
	if _deploy_dia_label != null:
		_deploy_dia_label.text = "💎 %d" % EquipmentManager.get_diamonds()
	if _deploy_up_btn != null:
		var up_cost: int = EquipmentManager.get_next_upgrade_cost()
		if up_cost < 0:
			_deploy_up_btn.text = "已满级"
			_deploy_up_btn.disabled = true
		else:
			_deploy_up_btn.text = "升级(%d💎)" % up_cost
			_deploy_up_btn.disabled = not EquipmentManager.can_upgrade()
	if _deploy_buy_btn != null:
		_deploy_buy_btn.text = "购买(%d💎)" % EquipmentManager.BUY_GEAR_COST
		_deploy_buy_btn.disabled = EquipmentManager.get_diamonds() < EquipmentManager.BUY_GEAR_COST

func _on_upgrade_slot() -> void:
	if EquipmentManager == null:
		return
	var cost: int = EquipmentManager.get_next_upgrade_cost()
	if cost < 0:
		return
	if not EquipmentManager.can_upgrade():
		_refresh_deploy_info()
		return
	if EquipmentManager.upgrade_slot():
		_refresh_deploy_info()
		_refresh_deploy_slots()

func _on_buy_gear() -> void:
	if EquipmentManager == null:
		return
	var _r: Dictionary = EquipmentManager.buy_random_gear("")
	_refresh_deploy_info()

func _refresh_deploy_slots() -> void:
	var modal: Control = get_node_or_null("ChallengePicker")
	if modal == null:
		return
	var center: CenterContainer = modal.get_child(2) if modal.get_child_count() > 2 else null
	if center == null:
		return
	var stage: Control = center.get_child(0) if center.get_child_count() > 0 else null
	if stage == null:
		return
	for c in stage.get_children():
		if c.name.begins_with("Slot_"):
			var slot_id: String = c.get_meta("slot_id", "")
			var gear_inst: Dictionary = {}
			if RunStats != null and RunStats.equipped_gear.has(slot_id):
				gear_inst = RunStats.equipped_gear[slot_id]
			_update_slot_visual(c, slot_id, gear_inst)

func _update_slot_visual(slot: Control, slot_id: String, gear_inst: Dictionary) -> void:
	var is_unlocked: bool = true
	if EquipmentManager != null:
		is_unlocked = EquipmentManager.is_slot_unlocked(slot_id)
	var sb: StyleBox = slot.get_theme_stylebox("panel")
	if sb == null or not (sb is StyleBoxFlat):
		sb = StyleBoxFlat.new()
	var art: TextureRect = slot.get_node_or_null("Art")
	var lb: Label = slot.get_node_or_null("Label")
	var slot_icon_path: String = SLOT_DIR + slot_id + ".png"
	var lock_path: String = SLOT_DIR + "lock.png"
	if not is_unlocked:
		# 未解锁：灰色 + 锁（优先用美化版 lock.png，否则回退 emoji）
		sb.bg_color = Color(0.04, 0.05, 0.07, 0.35)
		sb.border_color = Color(0.30, 0.30, 0.32, 0.50)
		if ResourceLoader.exists(lock_path):
			if art != null:
				art.texture = load(lock_path)
				art.visible = true
			if lb != null:
				lb.visible = false
		else:
			if art != null:
				art.visible = false
			if lb != null:
				lb.text = "🔒"
				lb.visible = true
				lb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
		slot.add_theme_stylebox_override("panel", sb)
		return
	# —— 已解锁 ——
	if not gear_inst.is_empty():
		# 已装备：显示装备图标（去掉文字），图标占满槽位、保持比例居中
		var def_id: String = gear_inst.get("def_id", "")
		var gear_icon_path: String = GEAR_ICON_DIR + def_id + ".png"
		if ResourceLoader.exists(gear_icon_path):
			if art != null:
				art.texture = load(gear_icon_path)
				art.visible = true
			if lb != null:
				lb.visible = false
		else:
			if art != null:
				art.visible = false
			if lb != null:
				lb.text = EquipmentManager.get_gear_name(def_id) if EquipmentManager != null else def_id
				lb.visible = true
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	# —— 已解锁空槽 ——
	if ResourceLoader.exists(slot_icon_path):
		# 有专属图标：显示原图标（去掉面板底，露出图标本身）
		if art != null:
			art.texture = load(slot_icon_path)
			art.visible = true
		if lb != null:
			lb.visible = false
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	else:
		# 已解锁但空，无图标：退回显示槽位名首字
		sb.bg_color = Color(0.08, 0.11, 0.16, 0.55)
		sb.border_color = Color(0.50, 0.60, 0.72, 0.85)
		if art != null:
			art.visible = false
		if lb != null:
			lb.text = EquipmentManager.SLOT_NAMES.get(slot_id, slot_id).substr(0, 1) if EquipmentManager != null else slot_id.substr(0, 1)
			lb.visible = true
			lb.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 0.9))
	slot.add_theme_stylebox_override("panel", sb)

func _on_slot_clicked(slot_id: String) -> void:
	if EquipmentManager == null or RunStats == null:
		return
	if not EquipmentManager.is_slot_unlocked(slot_id):
		# 锁住的槽位：提示需要升级到几级（不再静默无反应）
		var need_lv: int = 99
		for lvl in EquipmentManager.SLOT_UNLOCKS.keys():
			if slot_id in EquipmentManager.SLOT_UNLOCKS[lvl]:
				need_lv = int(lvl)
		if need_lv < 99:
			print("需槽位 Lv.%d 解锁" % need_lv)
		return
	var gear_inst: Dictionary = {}
	if RunStats.equipped_gear.has(slot_id):
		gear_inst = RunStats.equipped_gear[slot_id]
	if gear_inst.is_empty():
		_show_gear_pick_panel(slot_id)
	else:
		_show_gear_detail_panel(slot_id, gear_inst)

# 角色卡面背景（info_panel.png，9 宫格自适应），用作装备选择面板底
func _card_stylebox() -> StyleBox:
	if ResourceLoader.exists(CARD_BACK_TEX):
		var st := StyleBoxTexture.new()
		st.texture = load(CARD_BACK_TEX)
		st.texture_margin_left = 28.0
		st.texture_margin_top = 28.0
		st.texture_margin_right = 28.0
		st.texture_margin_bottom = 28.0
		return st
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	fb.set_border_width_all(2)
	fb.set_corner_radius_all(14)
	return fb

func _show_gear_detail_panel(slot_id: String, gear_inst: Dictionary) -> void:
	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 2000
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340.0, 320.0)
	panel.position = get_viewport_rect().size * 0.5 - Vector2(170.0, 160.0)
	panel.add_theme_stylebox_override("panel", _card_stylebox())
	modal.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var def_id: String = gear_inst.get("def_id", "")
	var def: Dictionary = EquipmentManager.get_gear_def(def_id) if EquipmentManager != null else {}
	var rarity: int = gear_inst.get("rarity", 1)
	var col: Color = Color.WHITE
	if EquipmentManager != null:
		col = EquipmentManager.get_rarity_color(rarity)

	var icon_path: String = GEAR_ICON_DIR + def_id + ".png"
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(80.0, 80.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	v.add_child(icon)
	var title := Label.new()
	title.text = def.get("name", def_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", col)
	v.add_child(title)

	var stats: Dictionary = EquipmentManager.get_gear_stats(gear_inst) if EquipmentManager != null else {}
	var stats_str := ""
	for key in stats.keys():
		var val: float = float(stats[key])
		var label_name: String = key
		match key:
			"atk_bonus": label_name = "攻击力"
			"max_hp_bonus": label_name = "生命值"
			"move_speed_bonus": label_name = "移速"
			"projectile_speed": label_name = "弹速"
			"def_bonus": label_name = "减伤"
			"pickup_radius": label_name = "拾取"
			"exp_bonus": label_name = "经验"
		if key == "projectile_speed" or key == "def_bonus" or key == "exp_bonus":
			stats_str += "%s +%.0f%%\n" % [label_name, val * 100]
		elif key == "pickup_radius":
			stats_str += "%s +%.0f\n" % [label_name, val]
		else:
			stats_str += "%s +%.0f\n" % [label_name, val]
	if stats_str != "":
		var st := Label.new()
		st.text = stats_str.strip_edges()
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_theme_font_size_override("font_size", 15)
		st.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		v.add_child(st)

	var flavor := Label.new()
	flavor.text = "\"%s\"" % def.get("flavor", "")
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_font_size_override("font_size", 13)
	flavor.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	v.add_child(flavor)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	v.add_child(btn_row)
	var replace_btn := Button.new()
	replace_btn.text = "替换"
	replace_btn.custom_minimum_size = Vector2(100.0, 36.0)
	replace_btn.pressed.connect(func():
		modal.queue_free()
		_show_gear_pick_panel(slot_id)
	)
	btn_row.add_child(replace_btn)
	var remove_btn := Button.new()
	remove_btn.text = "卸下"
	remove_btn.custom_minimum_size = Vector2(100.0, 36.0)
	remove_btn.pressed.connect(func():
		RunStats.equipped_gear.erase(slot_id)
		_refresh_deploy_slots()
		modal.queue_free()
	)
	btn_row.add_child(remove_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(100.0, 36.0)
	close_btn.pressed.connect(func(): modal.queue_free())
	btn_row.add_child(close_btn)

func _show_gear_pick_panel(slot_id: String) -> void:
	if EquipmentManager == null:
		return
	var candidates: Array[String] = EquipmentManager.get_gear_for_slot(slot_id)
	if candidates.is_empty():
		return
	# 二选一：随机选两个不同定义
	var opts: Array[Dictionary] = []
	var used: Array[String] = []
	for _i in range(2):
		var pool: Array[String] = []
		for c in candidates:
			if c not in used:
				pool.append(c)
		if pool.is_empty():
			break
		var pick: String = pool[randi() % pool.size()]
		used.append(pick)
		opts.append(EquipmentManager.create_instance(pick, 1, 1))
	if opts.is_empty():
		return

	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 2000
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(380.0, 280.0)
	panel.position = get_viewport_rect().size * 0.5 - Vector2(190.0, 140.0)
	panel.add_theme_stylebox_override("panel", _card_stylebox())
	modal.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "选择一件%s" % EquipmentManager.SLOT_NAMES.get(slot_id, slot_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	v.add_child(title)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	v.add_child(btn_row)
	for opt in opts:
		var def: Dictionary = EquipmentManager.get_gear_def(opt.get("def_id", ""))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150.0, 130.0)
		var bvb := VBoxContainer.new()
		bvb.alignment = BoxContainer.ALIGNMENT_CENTER
		bvb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bvb.add_theme_constant_override("separation", 6)
		bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bvb)
		var icon_path: String = GEAR_ICON_DIR + opt.get("def_id", "") + ".png"
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(72.0, 72.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		bvb.add_child(icon)
		var nm := Label.new()
		nm.text = def.get("name", "?")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 14)
		if EquipmentManager != null:
			nm.add_theme_color_override("font_color", EquipmentManager.get_rarity_color(opt.get("rarity", 1)))
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvb.add_child(nm)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.12, 0.16, 0.22)
		bsb.border_color = Color(0.50, 0.60, 0.72)
		bsb.set_border_width_all(2)
		bsb.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", bsb)
		var bsb_h := bsb.duplicate()
		bsb_h.bg_color = Color(0.18, 0.24, 0.32)
		btn.add_theme_stylebox_override("hover", bsb_h)
		btn.pressed.connect(func():
			RunStats.equipped_gear[slot_id] = opt
			_refresh_deploy_slots()
			modal.queue_free()
		)
		btn_row.add_child(btn)
	var close_btn := Button.new()
	close_btn.text = "取消"
	close_btn.custom_minimum_size = Vector2(100.0, 32.0)
	close_btn.pressed.connect(func(): modal.queue_free())
	v.add_child(close_btn)

# 出战页角色卡：复用选择页素材（info_panel 背板 + idle 帧立绘 + name/wp 文字块图），仅尺寸更小
func _make_deploy_card(def: Dictionary, id: String) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = _DEPLOY_CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_tex_path := "res://Assets/Sprites/UI/info_panel.png"
	if ResourceLoader.exists(back_tex_path):
		var st := StyleBoxTexture.new()
		st.texture = load(back_tex_path)
		st.texture_margin_left = 28.0
		st.texture_margin_top = 28.0
		st.texture_margin_right = 28.0
		st.texture_margin_bottom = 28.0
		panel.add_theme_stylebox_override("panel", st)
	else:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.10, 0.13, 0.18)
		fb.set_border_width_all(2)
		fb.set_corner_radius_all(14)
		panel.add_theme_stylebox_override("panel", fb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(110.0, 110.0)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(avatar)
	var nm := Label.new()
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 26)
	_add_text_bit_slot(nm)
	v.add_child(nm)
	var wp := Label.new()
	wp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wp.add_theme_font_size_override("font_size", 15)
	_add_text_bit_slot(wp)
	v.add_child(wp)
	_fill_avatar(avatar, def)
	var wname: String = "?"
	if SkillManager != null and SkillManager.SKILLS.has(def["start_weapon"]):
		wname = SkillManager.SKILLS[def["start_weapon"]]["name"]
	_apply_bit(nm, id, "name", def["name"], Color(1.0, 0.9, 0.6), Vector2(138.0, 40.0))
	_apply_bit(wp, id, "wp", "初始武器：" + wname, Color(0.85, 0.88, 0.92), Vector2(150.0, 33.0))
	return panel

func _make_slot(name: String, id: String, pos: Vector2, gear_inst: Dictionary = {}) -> Control:
	var slot := Panel.new()
	slot.name = "Slot_" + id
	slot.custom_minimum_size = Vector2(_DEPLOY_SLOT_SIZE, _DEPLOY_SLOT_SIZE)
	slot.position = pos
	slot.mouse_filter = Control.MOUSE_FILTER_PASS   # 允许点击穿透到子按钮
	slot.set_meta("slot_id", id)
	var is_unlocked: bool = true
	if EquipmentManager != null:
		is_unlocked = EquipmentManager.is_slot_unlocked(id)
	var sb := StyleBoxFlat.new()
	var col: Color = Color(0.50, 0.60, 0.72, 0.85)
	if not gear_inst.is_empty() and EquipmentManager != null:
		var rarity: int = EquipmentManager.get_gear_rarity(gear_inst.get("def_id", ""))
		col = EquipmentManager.get_rarity_color(rarity)
	if not is_unlocked:
		sb.bg_color = Color(0.04, 0.05, 0.07, 0.35)
		sb.border_color = Color(0.30, 0.30, 0.32, 0.50)
	else:
		sb.bg_color = Color(0.08, 0.11, 0.16, 0.55)
		sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	slot.add_theme_stylebox_override("panel", sb)
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := SLOT_DIR + id + ".png"
	if is_unlocked and ResourceLoader.exists(art_path):
		art.texture = load(art_path)
		art.visible = true
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var sm := ShaderMaterial.new()
		sm.shader = load("res://Assets/Sprites/Title/q_appear.gdshader")
		sm.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.15, 1.0))
		sm.set_shader_parameter("intensity", 0.0)
		sm.set_shader_parameter("thickness", max(3.0, _DEPLOY_SLOT_SIZE * 0.07))
		sm.set_shader_parameter("glow", max(9.0, _DEPLOY_SLOT_SIZE * 0.20))
		sm.set_shader_parameter("progress", 1.0)
		sm.set_shader_parameter("dissolve_edge", 0.10)
		sm.set_shader_parameter("dissolve_color", Color(1.0, 0.9, 0.55, 1.0))
		art.material = sm
		art.set_meta("sm", sm)
	else:
		art.visible = false
	slot.add_child(art)
	var frame_path := SLOT_DIR + "frame.png"
	if ResourceLoader.exists(frame_path):
		var fr := TextureRect.new()
		fr.name = "Frame"
		fr.texture = load(frame_path)
		fr.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr.custom_minimum_size = Vector2(_DEPLOY_FRAME_DISP, _DEPLOY_FRAME_DISP)
		fr.size = Vector2(_DEPLOY_FRAME_DISP, _DEPLOY_FRAME_DISP)
		var off: float = (_DEPLOY_SLOT_SIZE - _DEPLOY_FRAME_DISP) * 0.5
		fr.position = Vector2(off, off)
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fsm := ShaderMaterial.new()
		fsm.shader = load("res://Assets/Sprites/Title/q_appear.gdshader")
		fsm.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.15, 1.0))
		fsm.set_shader_parameter("intensity", 0.0)
		fsm.set_shader_parameter("thickness", max(3.0, _DEPLOY_SLOT_SIZE * 0.07))
		fsm.set_shader_parameter("glow", max(9.0, _DEPLOY_SLOT_SIZE * 0.20))
		fsm.set_shader_parameter("progress", 1.0)
		fsm.set_shader_parameter("dissolve_edge", 0.10)
		fsm.set_shader_parameter("dissolve_color", Color(1.0, 0.9, 0.55, 1.0))
		fr.material = fsm
		fr.set_meta("sm", fsm)
		slot.add_child(fr)
	var lb := Label.new()
	lb.name = "Label"
	if not is_unlocked:
		lb.text = "🔒"
		if art != null:
			art.visible = false   # 锁住时绝不显示专属图标
	elif not gear_inst.is_empty():
		var gear_def_id: String = gear_inst.get("def_id", "")
		if EquipmentManager != null:
			lb.text = EquipmentManager.get_gear_name(gear_def_id).substr(0, 2)
		else:
			lb.text = name.substr(0, 1)
	else:
		lb.text = name.substr(0, 1)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 15)
	if not is_unlocked:
		lb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
	elif not gear_inst.is_empty():
		lb.add_theme_color_override("font_color", col)
	else:
		lb.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 0.9))
	lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art.visible:
		lb.visible = false
	slot.add_child(lb)
	# 点击层：所有槽位都挂点击（锁住的由 _on_slot_clicked 弹「需 Lv.X 解锁」）
	var hit := Button.new()
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.custom_minimum_size = Vector2(_DEPLOY_SLOT_SIZE, _DEPLOY_SLOT_SIZE)
	hit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.pressed.connect(func(): _on_slot_clicked(id))
	slot.add_child(hit)
	# 统一用 _update_slot_visual 初始化外观：未解锁槽立即显示 lock.png 美术素材，
	# 而非默认 emoji —— 避免出现「进页面是 emoji、选完符文刷新后才变 lock.png」的不一致
	_update_slot_visual(slot, id, gear_inst)
	return slot

# 模式按钮：enabled=false 时置灰「即将开放」不可点
func _make_mode_card(title: String, desc: String, accent: Color, cb: Callable) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(200.0, 100.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_mode_panel_style(panel, accent, false)
	wrap.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14.0
	vbox.offset_right = -14.0
	vbox.offset_top = 12.0
	vbox.offset_bottom = -12.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(vbox)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(t)

	var d := Label.new()
	d.text = desc
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	vbox.add_child(d)

	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.mouse_entered.connect(func(): _apply_mode_panel_style(panel, accent, true))
	hit.mouse_exited.connect(func(): _apply_mode_panel_style(panel, accent, false))
	hit.pressed.connect(cb)
	wrap.add_child(hit)

	return wrap


func _apply_mode_panel_style(panel: Panel, accent: Color, hovered: bool) -> void:
	var back_tex_path := "res://Assets/Sprites/UI/info_panel.png"
	if ResourceLoader.exists(back_tex_path):
		var st := StyleBoxTexture.new()
		st.texture = load(back_tex_path)
		st.texture_margin_left = 28.0
		st.texture_margin_top = 28.0
		st.texture_margin_right = 28.0
		st.texture_margin_bottom = 28.0
		st.modulate_color = Color(1.18, 1.18, 1.18, 1.0) if hovered else Color(1.0, 1.0, 1.0, 1.0)
		panel.add_theme_stylebox_override("panel", st)
	else:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.10, 0.13, 0.18)
		fb.border_color = accent if hovered else Color(0.45, 0.58, 0.75)
		fb.set_border_width_all(2)
		fb.set_corner_radius_all(14)
		panel.add_theme_stylebox_override("panel", fb)


func _make_mode_button(text: String, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(311.0, 104.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.disabled = not enabled
	var sb := StyleBoxFlat.new()
	if enabled:
		sb.bg_color = Color(0.16, 0.42, 0.26)
		sb.border_color = Color(0.55, 1.0, 0.65)
	else:
		sb.bg_color = Color(0.18, 0.18, 0.20)
		sb.border_color = Color(0.40, 0.40, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	if enabled:
		sbh.bg_color = Color(0.22, 0.55, 0.34)
	else:
		sbh.bg_color = Color(0.22, 0.22, 0.24)
	b.add_theme_stylebox_override("hover", sbh)
	if enabled:
		b.pressed.connect(cb)
	return b

func _show_synthesis_panel() -> void:
	if EquipmentManager == null:
		return
	var inv: Array = EquipmentManager.get_inventory()
	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 2000
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(dim)
	var panel := Panel.new()
	var vsz := get_viewport_rect().size
	var pw: float = min(560.0, vsz.x - 40.0)
	var ph: float = min(500.0, vsz.y - 40.0)
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.position = vsz * 0.5 - Vector2(pw, ph) * 0.5
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	psb.border_color = Color(0.45, 0.55, 0.70)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", psb)
	modal.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "装备合成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "点击高亮装备进行升星"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	vbox.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 300.0)
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(grid)

	for inst in inv:
		var uid: String = inst.get("uid", "")
		var def_id: String = inst.get("def_id", "")
		var rarity: int = inst.get("rarity", 1)
		var def: Dictionary = EquipmentManager.get_gear_def(def_id)
		var same: Array = EquipmentManager.count_identical(inst)
		var can_synth: bool = same.size() >= 2 and rarity < EquipmentManager.MAX_RARITY

		var cell := Button.new()
		cell.custom_minimum_size = Vector2(96.0, 84.0)
		var col: Color = EquipmentManager.get_rarity_color(rarity)
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		if can_synth:
			csb.border_color = col
			csb.set_border_width_all(3)
		else:
			csb.border_color = Color(0.30, 0.30, 0.35, 0.50)
			csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		cell.add_theme_stylebox_override("normal", csb)
		if can_synth:
			var csb_h := csb.duplicate()
			csb_h.bg_color = Color(0.12, 0.16, 0.24)
			cell.add_theme_stylebox_override("hover", csb_h)
		cell.disabled = not can_synth
		grid.add_child(cell)

		var cv := VBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 2)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cv)

		var name_lbl := Label.new()
		name_lbl.text = def.get("name", def_id).substr(0, 4)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", col)
		cv.add_child(name_lbl)

		var star_lbl := Label.new()
		var rstr: String = ""
		for _i in range(rarity):
			rstr += "★"
		for _i in range(EquipmentManager.MAX_RARITY - rarity):
			rstr += "☆"
		star_lbl.text = rstr
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 12)
		star_lbl.add_theme_color_override("font_color", col)
		cv.add_child(star_lbl)

		var slot_lbl := Label.new()
		slot_lbl.text = EquipmentManager.SLOT_NAMES.get(def.get("slot", ""), "")
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_font_size_override("font_size", 11)
		slot_lbl.add_theme_color_override("font_color", Color(0.6, 0.64, 0.72))
		cv.add_child(slot_lbl)

		if can_synth:
			var brother: Dictionary = same[0]
			if brother.get("uid") == uid and same.size() >= 2:
				brother = same[1]
			var bro_uid: String = brother.get("uid", "")
			cell.pressed.connect(func():
				_show_synth_confirm(modal, uid, bro_uid, def, rarity, col)
			)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom_row)
	var dia_lbl := Label.new()
	dia_lbl.text = "💎 %d" % EquipmentManager.get_diamonds()
	dia_lbl.add_theme_font_size_override("font_size", 16)
	dia_lbl.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	bottom_row.add_child(dia_lbl)
	var buy_inner := Button.new()
	buy_inner.text = "购买随机装备(%d💎)" % EquipmentManager.BUY_GEAR_COST
	buy_inner.custom_minimum_size = Vector2(180.0, 32.0)
	buy_inner.add_theme_font_size_override("font_size", 14)
	buy_inner.pressed.connect(func():
		var _r: Dictionary = EquipmentManager.buy_random_gear("")
		_refresh_deploy_info()
		dia_lbl.text = "💎 %d" % EquipmentManager.get_diamonds()
		buy_inner.disabled = EquipmentManager.get_diamonds() < EquipmentManager.BUY_GEAR_COST
		modal.queue_free()
		_show_synthesis_panel()
	)
	buy_inner.disabled = EquipmentManager.get_diamonds() < EquipmentManager.BUY_GEAR_COST
	bottom_row.add_child(buy_inner)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(80.0, 32.0)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(func():
		_refresh_deploy_info()
		_refresh_deploy_slots()
		modal.queue_free()
	)
	bottom_row.add_child(close_btn)

func _show_synth_confirm(parent_modal: Control, base_uid: String, fodder_uid: String, def: Dictionary, rarity: int, col: Color) -> void:
	if EquipmentManager == null:
		return
	var target_rarity: int = rarity + 1
	var target_col: Color = EquipmentManager.get_rarity_color(target_rarity)
	var cost: int = EquipmentManager.SYNTH_COST.get(target_rarity, 0)
	var has_dia: bool = EquipmentManager.get_diamonds() >= cost

	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 2100
	parent_modal.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.60)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(300.0, 220.0)
	var vsz := get_viewport_rect().size
	panel.position = vsz * 0.5 - Vector2(150.0, 110.0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	psb.border_color = target_col
	psb.set_border_width_all(3)
	psb.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", psb)
	modal.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "确认合成"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	v.add_child(t)
	var formula := Label.new()
	formula.text = "%s ★%d  +  %s ★%d" % [def.get("name"), rarity, def.get("name"), rarity]
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formula.add_theme_font_size_override("font_size", 16)
	formula.add_theme_color_override("font_color", col)
	v.add_child(formula)
	var arrow := Label.new()
	arrow.text = "→  %s ★%d" % [def.get("name"), target_rarity]
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", target_col)
	v.add_child(arrow)
	var cost_lbl := Label.new()
	cost_lbl.text = "消耗: %d💎    当前: %d💎" % [cost, EquipmentManager.get_diamonds()]
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0) if has_dia else Color(1.0, 0.35, 0.35))
	v.add_child(cost_lbl)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	v.add_child(btn_row)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认合成"
	confirm_btn.custom_minimum_size = Vector2(120.0, 36.0)
	confirm_btn.disabled = not has_dia
	confirm_btn.pressed.connect(func():
		var result: Dictionary = EquipmentManager.synthesize(base_uid, fodder_uid)
		if not result.is_empty():
			_refresh_deploy_info()
			parent_modal.queue_free()
			_show_synthesis_panel()
	)
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80.0, 36.0)
	cancel_btn.pressed.connect(func(): modal.queue_free())
	btn_row.add_child(cancel_btn)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _make_back() -> Button:
	var b := Button.new()
	b.text = "返回主菜单"
	b.custom_minimum_size = Vector2(280.0, 60.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.14, 0.22)
	sb.border_color = Color(0.78, 0.45, 0.98)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.26, 0.18, 0.32)
	b.add_theme_stylebox_override("hover", sb_h)
	b.pressed.connect(_on_back)
	return b

# 预渲染按钮：有图用 TextureButton（静态图，按下时轻微变暗反馈），缺图回退到文字按钮
# overlay_text：可选叠加文字（用于纯底图+自定义文字的情况，如关卡模式用 btn_base.png 复用无尽模式底图）
func _make_img_button(tex_path: String, text: String, cb: Callable, normal_col: Color, border_col: Color, min_size: Vector2 = Vector2(240.0, 64.0), scale_factor: float = 1.0, overlay_text: String = "") -> Control:
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		var sz := tex.get_size()
		var visual := _make_outline_visual(tex)
		if scale_factor != 1.0:
			visual.custom_minimum_size = sz * scale_factor
			visual.scale = Vector2(scale_factor, scale_factor)

		# 如果需要叠加文字（纯底图场景），在视觉层容器中加 Label
		var host: Control = visual
		if overlay_text != "":
			var container := Control.new()
			container.custom_minimum_size = visual.custom_minimum_size if visual.custom_minimum_size.x > 0 else sz
			container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			visual.anchor_right = 1.0
			visual.anchor_bottom = 1.0
			visual.offset_right = 0.0
			visual.offset_bottom = 0.0
			container.add_child(visual)

			var label := Label.new()
			label.text = overlay_text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.add_theme_font_size_override("font_size", 32)
			label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			label.add_theme_constant_override("outline_size", 4)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(label)
			host = container

		var hit := _make_hit(sz, cb)
		hit.mouse_entered.connect(func(): _tween_btn_glow(visual, 1.0))
		hit.mouse_exited.connect(func(): _tween_btn_glow(visual, 0.0))
		hit.button_down.connect(func(): visual.self_modulate = Color(0.82, 0.82, 0.82, 1.0))
		hit.button_up.connect(func(): visual.self_modulate = Color(1.0, 1.0, 1.0, 1.0))
		host.add_child(hit)      # 透明输入层盖在视觉层之上，捕获悬停/点击
		return host

	# 回退：程序绘制金属质感按钮，视觉接近无尽模式底图风格
	var container := Control.new()
	container.custom_minimum_size = min_size
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# 底图：深灰黑金属渐变底板（圆角胶囊形）
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08)
	sb.border_color = Color(0.55, 0.40, 0.20)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(28)
	# 微妙内边距，让文字完美居中
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", sb)
	container.add_child(panel)

	# 文字：浅金色 + 黑边描边
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	# 悬停高亮层（默认透明，hover时亮起）
	var glow := Panel.new()
	glow.name = "GlowOverlay"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var sb_glow := StyleBoxFlat.new()
	sb_glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb_glow.border_color = Color(0.85, 0.70, 0.30)
	sb_glow.set_border_width_all(3)
	sb_glow.set_corner_radius_all(28)
	glow.add_theme_stylebox_override("panel", sb_glow)
	container.add_child(glow)

	# 透明点击层
	var hit := Button.new()
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.mouse_entered.connect(func():
		var tw := create_tween()
		tw.tween_property(glow, "modulate:a", 0.6, 0.15)
		label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	)
	hit.mouse_exited.connect(func():
		var tw := create_tween()
		tw.tween_property(glow, "modulate:a", 0.0, 0.20)
		label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	)
	hit.button_down.connect(func():
		container.scale = Vector2(0.96, 0.96)
		container.position += container.custom_minimum_size * 0.02
	)
	hit.button_up.connect(func():
		container.scale = Vector2(1.0, 1.0)
		container.position -= container.custom_minimum_size * 0.02
	)
	hit.pressed.connect(cb)
	container.add_child(hit)
	return container

# 按钮视觉层：TextureRect + 问号同款描边发光 shader（q_appear.gdshader），
# 悬停时把 intensity 0→1，按钮轮廓四周亮起黄色光（与问号「找到你了」效果一致）。
# progress 固定=1（按钮不需要溶解显现），仅用 intensity 控制轮廓发光。
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
	sm.set_shader_parameter("progress", 1.0)        # 按钮始终完整显示，仅轮廓受 intensity 控制
	sm.set_shader_parameter("dissolve_edge", 0.10)
	sm.set_shader_parameter("dissolve_color", Color(1.0, 0.9, 0.55, 1.0))
	visual.material = sm
	visual.set_meta("sm", sm)
	return visual

# 透明输入层：盖在视觉层之上，捕获悬停/点击（与问号 q_img+透明 Button 同架构）
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

# 悬停时缓动按钮视觉层的轮廓发光强度（0↔1）
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

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

# 程序生成径向暗角：中心透明、边缘变暗，把视线聚焦到中央转盘区。
# strength 控制边缘最暗处的 alpha（0=无，1=纯黑边）。中心 d<0.38 完全透明，不影响中央卡片。
func _make_vignette(strength: float) -> Texture2D:
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(s) * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = clamp((d - 0.38) / 0.62, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)   # smoothstep，边缘过渡更柔
			img.set_pixel(x, y, Color(0, 0, 0, a * strength))
	return ImageTexture.create_from_image(img)

# 装备槽边框素材约定：把 frame.png 放进 SLOT_DIR（Assets/Sprites/UI/Slots/），
# 即自动作为六个槽位共用的边框覆盖在美术之上，悬停时边框边缘亮起（见 _make_slot）。


# 顶部标题：优先用你自制的 select_title.png（整图三层：暖白发光 / 黑投影 / 金色本体），
# 与初始页「这也叫地牢」视觉语言一致；放大到原来的 1.8 倍（TITLE_SCALE），位置与原先保持一致。
# 找不到图时回退为风格化文字（同色系），保证不崩。
const TITLE_SCALE: float = 1.8
func _make_title_styled(text: String, fnt: Font) -> Control:
	var title_layer := Control.new()
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var img_path: String = TITLE_DIR + "select_title.png"
	if ResourceLoader.exists(img_path):
		var tex: Texture2D = load(img_path)
		var h := 70.0 * TITLE_SCALE        # 原高 70 → 1.8 倍
		var sc: float = h / max(1.0, float(tex.get_height()))
		var w: float = float(tex.get_width()) * sc
		title_layer.custom_minimum_size = Vector2(w, h)

		# 暖白外发光（放大 1.06、半透明、居中）
		var glow := TextureRect.new()
		glow.texture = tex
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		glow.scale = Vector2(1.06, 1.06)
		glow.modulate = Color(1.0, 0.92, 0.7, 0.45)
		glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_layer.add_child(glow)

		# 黑投影（偏移 +6,+10、半透明）
		var shadow := TextureRect.new()
		shadow.texture = tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		shadow.modulate = Color(0.0, 0.0, 0.0, 0.55)
		shadow.position = Vector2(6.0, 10.0)
		shadow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_layer.add_child(shadow)

		# 金色本体（居中，缩放后居中显示）
		var body := TextureRect.new()
		body.texture = tex
		body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		body.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		body.scale = Vector2(sc, sc)
		body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_layer.add_child(body)

		return title_layer

	# 无图回退：单张风格化文字（金色描边 + 暖白发光 + 黑投影三层）
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

func _load_font() -> Font:
	for p in [FONT_DIR + "title.ttf", FONT_DIR + "title.otf"]:
		if ResourceLoader.exists(p):
			var f = load(p)
			if f is Font:
				return f
	return null
