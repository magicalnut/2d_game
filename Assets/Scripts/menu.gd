extends Control

## 初始主菜单（极简）：仅「这也叫地牢」标题 + 一个「?」开始键。
## 「?」既是标点也是开始按钮：悬停放大、点击 / Enter / Space / J / 触屏均可开始。
## 标题：Assets/Sprites/Title/title_main.png（「这也叫地牢」整图）会被均匀切成 5 个字，逐字从屏幕外掉落入场；char_q.png 作「?」按钮图标；缺失则回退逐字/金色文字（见该目录 README）。
## 特殊字体 Assets/Fonts/title.ttf 仍作为回退文字的字体（缺失则用默认字体）。

const SETUP_SCENE := "res://Scenes/character_setup.tscn"
const FONT_DIR := "res://Assets/Fonts/"
const TITLE_DIR := "res://Assets/Sprites/Title/"
const CARD_BACK_TEX := "res://Assets/Sprites/UI/info_panel.png"   # 角色卡面背景（读档槽卡 / 暂停按钮 / 主菜单三按钮 / 返回 / 确认覆盖 等统一复用）
const MENU_BTN_SIZE := Vector2(318.0, 75.0)              # 主菜单三按钮尺寸；背景复用角色卡面素材 info_panel.png（见 _make_menu_button）

# 标题逐字精灵：字 → 文件名（统一 ASCII，避开中文名 preload 编码坑）
const TITLE_MAP := {
	"这": "char_zhe",
	"也": "char_ye",
	"叫": "char_jiao",
	"地": "char_di",
	"牢": "char_lao",
	"?": "char_q",
}

var _starting: bool = false
var _q: Button = null
var _q_wrap: Control = null
var _q_img: TextureRect = null
var _q_shader: ShaderMaterial = null
var _q_idle_tween: Tween = null
var _q_glow_tween: Tween = null   # 黄色描边强度补间；每次切换前 kill 旧的，避免快速进出竞态
var _has_q_img: bool = false
var _fade: ColorRect = null
var _title_chars: Array = []   # 标题逐字容器（整图切片模式），供入场掉落动画使用
var _menu_revealed: bool = false  # 「?」是否已点击展开菜单
var _menu_buttons: Control = null # 点击「?」后溶解出现的三个按钮容器
var _q_center: Vector2 = Vector2.ZERO   # 「?」最终屏幕中心，供三个按钮在此溶解出现
var _load_overlay: Control = null # 主菜单「读取存档」浮层
var _new_game_overlay: Control = null # 主菜单「开始游戏」选槽浮层

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 背景图铺满
	var bg_img := TextureRect.new()
	bg_img.texture = preload("res://Assets/Sprites/UI/menu_bg.png")
	bg_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_img.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_img.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg_img)

	# 基础暗化层（加深以突出中央两元素）
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.30)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 背景鬼影：白色幽灵在背景层游荡（位于暗化层之上、标题/问号之下）
	var gl_menu := preload("res://Assets/Scripts/ghost_layer.gd").new()
	gl_menu.ghost_dir = "res://Assets/Sprites/Ghosts/White/"
	add_child(gl_menu)

	var fnt: Font = _load_font()

	# 居中竖向布局
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 44)
	add_child(vbox)
	# 整体上移，让放大后的标题更靠上、下方给「?」留出空间
	vbox.offset_top = -70.0
	vbox.offset_bottom = -70.0

	# 标题：这也叫地牢（整图优先；缺整图则逐字精灵，再缺则金色文字）
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	title_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_make_title(fnt))
	vbox.add_child(title_row)
	# 「?」开始键：透明 Button 接收输入；底下 TextureRect 显示「?」并带黄色描边 shader。
	# 鼠标贴近时：描边亮起（找到你了）+ 停止呼吸（屏住呼吸）。
	var q_wrap := Control.new()
	q_wrap.custom_minimum_size = Vector2(220, 170)
	q_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	q_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(q_wrap)
	_q_wrap = q_wrap

	var q_path: String = TITLE_DIR + TITLE_MAP["?"] + ".png"
	var has_img: bool = ResourceLoader.exists(q_path)
	_has_q_img = has_img

	# 底层：? 图像（带黄色描边 shader），接收不到鼠标
	var q_img := TextureRect.new()
	q_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_img.custom_minimum_size = Vector2(160, 160)
	if has_img:
		# 把 384px 原图预缩放成 160×160，避免 EXPAND_IGNORE_SIZE 导致的原生尺寸溢出右移
		var src := load(q_path) as Texture2D
		var tex: Texture2D = src
		var img := src.get_image()
		if img != null:
			img.resize(160, 160, Image.INTERPOLATE_LANCZOS)
			var it := ImageTexture.create_from_image(img)
			if it != null:
				tex = it
		q_img.texture = tex
		var sm := ShaderMaterial.new()
		sm.shader = load("res://Assets/Sprites/Title/q_appear.gdshader")
		sm.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.15, 1.0))
		sm.set_shader_parameter("intensity", 0.0)
		sm.set_shader_parameter("thickness", 2.5)
		sm.set_shader_parameter("glow", 5.0)
		sm.set_shader_parameter("progress", 0.0)      # 溶解：出场时由 0 渐显到 1
		sm.set_shader_parameter("dissolve_edge", 0.10)
		sm.set_shader_parameter("dissolve_color", Color(1.0, 0.9, 0.55, 1.0))
		q_img.material = sm
		_q_shader = sm
	q_wrap.add_child(q_img)
	_q_img = q_img

	# 上层：透明 Button 只负责接收悬停/点击/键盘
	var q := Button.new()
	q.text = "?"
	q.flat = true
	q.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	q.add_theme_stylebox_override("normal", empty)
	q.add_theme_stylebox_override("hover", empty)
	q.add_theme_stylebox_override("pressed", empty)
	q.add_theme_stylebox_override("focus", empty)
	q.add_theme_font_size_override("font_size", 96)
	q.add_theme_color_override("font_color", UIColors.WHITE)
	q.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	q.add_theme_constant_override("outline_size", 4)
	if fnt != null:
		q.add_theme_font_override("font", fnt)
	if has_img:
		q.text = ""                       # 有图则透明覆盖，图像由 q_img 显示
		q.custom_minimum_size = Vector2(160, 160)
	q_wrap.add_child(q)
	_q = q

	q.mouse_entered.connect(_on_q_hover.bind(q, true))
	q.mouse_exited.connect(_on_q_hover.bind(q, false))
	q.pressed.connect(_on_q_pressed)

	# 设置按钮不再常驻左上角：改为点击「?」展开菜单后的三个按钮之一（见 _on_q_pressed）。

	# 顶部淡出遮罩（点击开始后整屏淡出到角色选择）
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate = Color(1, 1, 1, 0)
	add_child(fade)
	_fade = fade

	# 入场动画
	if _title_chars.is_empty():
		# 回退（无整图）：标题整行淡入放大
		title_row.modulate = Color(1, 1, 1, 0)
		title_row.scale = Vector2(0.92, 0.92)
		var tw0 := create_tween()
		tw0.tween_property(title_row, "modulate", Color(1, 1, 1, 1), 0.5)
		tw0.parallel().tween_property(title_row, "scale", Vector2(1, 1), 0.5).set_ease(Tween.EASE_OUT)
	else:
		# 标题逐字从屏幕外上方掉落、错峰、带回弹（不再加绑带细线）
		for i in range(_title_chars.size()):
			var cb = _title_chars[i]
			cb.position.y = -800.0
			cb.modulate.a = 0.0
			var ct := create_tween()
			ct.tween_interval(0.10 * float(i))
			ct.tween_property(cb, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ct.parallel().tween_property(cb, "modulate:a", 1.0, 0.3)

	q.grab_focus()
	q_wrap.modulate.a = 0.0   # 先透明：避免标题掉落期间问号在最终位置闪现一帧；飞入 tween 会再淡入

	# 布局已完成、尺寸确定后再做居中（提前 PRESET_CENTER 会因尺寸=0 算错偏移，把字形推偏）
	await get_tree().process_frame
	# 关键：用「锚点置 0 + 显式 position/size」的绝对定位，把图像层(q_img,160)与命中层(q,200)
	# 各自居中钉在 q_wrap 内、共享同一中心点。PRESET_CENTER(KEEP_WIDTH) 会把空文本 Button
	# 压扁后再设 size，导致命中区偏到右下、与实际问号错位——这里彻底绕开它。
	for _pair in [[q_img, 160.0], [q, 200.0]]:
		var _n: Control = _pair[0]
		var _s: float = _pair[1]
		_n.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_n.size = Vector2(_s, _s)
		_n.position = (q_wrap.size - Vector2(_s, _s)) * 0.5
	q.pivot_offset = q.size * 0.5
	q_wrap.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	q_wrap.pivot_offset = q_wrap.size * 0.5
	# 水平 H：0=屏幕正中；正数右移、负数左移。垂直 V：下移像素（你之前确认合适的 90）。
	var H: float = -110.0
	var V: float = 90.0
	q_wrap.offset_left = H
	q_wrap.offset_right = H
	q_wrap.offset_top = V
	q_wrap.offset_bottom = V

	# 「?」出场改为：在「这也叫地牢」出现后，从地面以「溶解」的形式浮现——
	# 起点在最终位置正下方（屏幕底部附近，像从地里钻出），向上缓缓升起；
	# 同时由 shader 的 progress(0→1) 控制「溶解变清晰」，最终达到当前大小与位置。
	# 当前 q_wrap.position 已是 vbox 布局落定的最终局部位置（≈屏幕坐标，父链无平移/缩放）
	var _final_pos: Vector2 = q_wrap.position
	var _rise: float = 230.0                                       # 从地下升起的垂直距离
	var _ground_pos: Vector2 = Vector2(_final_pos.x, _final_pos.y + _rise)
	q_wrap.position = _ground_pos
	q_wrap.rotation = 0.0
	q_wrap.scale = Vector2(1.0, 1.0)                              # 保持最终尺寸，只升起 + 溶解变清晰
	if _q_shader != null:
		_q_shader.set_shader_parameter("progress", 0.0)
		q_wrap.modulate.a = 1.0                                    # 显隐交给 shader，避免与溶解冲突
	else:
		q_wrap.modulate.a = 0.0                                    # 文字回退：无 shader，用 modulate 淡入
	var _qfly := create_tween()
	_qfly.tween_interval(0.10 * float(_title_chars.size()) + 0.05)   # 等「这也叫地牢」字落定
	_qfly.parallel().tween_property(q_wrap, "position", _final_pos, 1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _q_shader != null:
		_qfly.parallel().tween_method(_set_q_progress, 0.0, 1.0, 1.25).set_trans(Tween.TRANS_LINEAR)
	else:
		_qfly.parallel().tween_property(q_wrap, "modulate:a", 1.0, 1.25)
	_qfly.tween_callback(_begin_idle.bind(q_wrap))

	# 记录「?」点击后三个按钮溶解出现的中心：水平居中、并整体下移一段距离
	# （不再沿用「?」左偏的位置；按钮组在标题下方居中，远离标题且不会被标题挤压）
	var _qv: Vector2 = get_viewport().get_visible_rect().size
	var _btn_drop: float = 150.0            # 按钮组中心相对屏幕中心的下移像素
	_q_center = Vector2(_qv.x * 0.5, _qv.y * 0.5 + _btn_drop)

func _begin_idle(q_wrap: Control) -> void:
	_q_idle_tween = create_tween()
	_q_idle_tween.set_loops()
	_q_idle_tween.tween_property(q_wrap, "scale", Vector2(1.03, 1.03), 1.4).set_ease(Tween.EASE_IN_OUT)
	_q_idle_tween.tween_property(q_wrap, "scale", Vector2(1.0, 1.0), 1.4).set_ease(Tween.EASE_IN_OUT)

# 鼠标靠近标题字符时，字会紧张地摇晃（旋转抖动 + 轻微位移），离开后平息
func _set_q_intensity(v: float) -> void:
	if _q_shader != null:
		_q_shader.set_shader_parameter("intensity", v)

func _set_q_progress(v: float) -> void:
	if _q_shader != null:
		_q_shader.set_shader_parameter("progress", v)

func _on_q_hover(q: Button, on: bool) -> void:
	# 每次切换前先结束上一条发光补间，杜绝快速「进→出→进」时新旧补间打架、最终被拽回 0 的竞态
	if _q_glow_tween != null and _q_glow_tween.is_valid():
		_q_glow_tween.kill()
	if on:
		# 被找到：屏住呼吸（冻结待机缩放），边缘亮起黄色描边
		if _q_idle_tween != null and _q_idle_tween.is_valid():
			_q_idle_tween.kill()
		if _q_shader != null:
			_q_glow_tween = create_tween()
			_q_glow_tween.tween_method(_set_q_intensity, _q_shader.get_shader_parameter("intensity"), 1.0, 0.18)
		else:
			# 文字回退：把描边变黄加粗
			q.add_theme_color_override("font_outline_color", Color(1.0, 0.85, 0.15, 1.0))
			q.add_theme_constant_override("outline_size", 9)
	else:
		# 没被盯着：收起黄色、恢复呼吸
		if _q_shader != null:
			_q_glow_tween = create_tween()
			_q_glow_tween.tween_method(_set_q_intensity, _q_shader.get_shader_parameter("intensity"), 0.0, 0.24)
		else:
			q.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
			q.add_theme_constant_override("outline_size", 4)
		_begin_idle(_q_wrap)

func _unhandled_input(ev: InputEvent) -> void:
	if _starting:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_J:
			if not _menu_revealed:
				_on_q_pressed()      # 菜单未展开时，J 等同于点击「?」
			else:
				_open_new_game_ui()  # 菜单已展开时，J 等同于点「开始游戏」（先选存档槽）

func _open_settings() -> void:
	var ui := preload("res://Assets/Scripts/settings_ui.gd").new()
	add_child(ui)

func _start_game() -> void:
	if _starting:
		return
	_starting = true
	if RunStats != null:
		RunStats.game_mode = "endless"
	# 置顶黑幕，淡出时盖住标题/「?」/三个按钮，过渡干净（Godot 4 已移除 CanvasItem.raise()，改用 move_child 移到末尾）
	if _fade != null and _fade.get_parent() != null:
		_fade.get_parent().move_child(_fade, -1)
	if _menu_buttons != null:
		_menu_buttons.visible = false
	var tw := create_tween()
	tw.tween_property(_q, "scale", Vector2(0.82, 0.82), 0.12).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_fade, "modulate", Color(1, 1, 1, 1), 0.34)
	tw.tween_callback(_go)

func _go() -> void:
	get_tree().change_scene_to_file(SETUP_SCENE)

# —— 点击「?」后的菜单展开（溶解出现三个按钮）——
# 行为：骷髅从天而降 + 「?」淡出 + 在标题下方居中处溶解浮现 开始游戏/读取存档/设置。
func _on_q_pressed() -> void:
	if _menu_revealed:
		return
	_menu_revealed = true
	# 1) 「?」淡出（仅视觉隐藏，不要 visible=false：否则 VBoxContainer 重新布局会把标题往下挤）
	if _q_idle_tween != null and _q_idle_tween.is_valid():
		_q_idle_tween.kill()
	_q.disabled = true                                  # 失能，避免透明层仍拦截点击
	_q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var twq := create_tween()
	twq.tween_property(_q_wrap, "modulate:a", 0.0, 0.25)
	# 3) 三个按钮溶解出现
	_build_menu_buttons()

func _build_menu_buttons() -> void:
	var btn_size := MENU_BTN_SIZE   # 单个按钮尺寸（= 裁掉透明边后的纯框 ×1.5）
	var GAP := 12.0   # 按钮之间的固定间距（像素）；想调大/调小改这一行即可
	var total_h := btn_size.y * 3.0 + GAP * 2.0

	# 普通容器（非 VBoxContainer），手动绝对定位每个按钮 → 间距完全可控、不受主题 separation/膨胀影响
	var vb := Control.new()
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.custom_minimum_size = Vector2(btn_size.x, total_h)
	vb.size = Vector2(btn_size.x, total_h)
	vb.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(vb)
	_menu_buttons = vb

	var defs := [
		["开始新游戏", Callable(self, "_open_new_game_ui")],
		["读取存档", Callable(self, "_open_load_ui")],
		["设置", Callable(self, "_open_settings")],
	]
	var idx := 0
	for d in defs:
		var b := _make_menu_button(d[0], d[1])
		b.position = Vector2(0.0, float(idx) * (btn_size.y + GAP))
		vb.add_child(b)
		idx += 1

	# 等一帧让布局确定尺寸，再按「?」中心精确居中摆放
	await get_tree().process_frame
	vb.position = _q_center - vb.size * 0.5

	# 错位淡入：每个按钮整体透明度 0→1，依次亮起；完成前不可点
	idx = 0
	for child in vb.get_children():
		var btn: Button = child.get_meta("btn")
		var delay: float = 0.15 * float(idx)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(child, "modulate:a", 1.0, 0.5)
		tw.tween_callback(func(): btn.disabled = false)
		idx += 1
	var first: Button = (vb.get_child(0)).get_meta("btn")
	if first != null:
		first.grab_focus()

# 单个菜单按钮：角色卡面背景（info_panel.png，9 宫格自适应）+ 中文标签 + 透明点击层
func _make_menu_button(label: String, cb: Callable) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	# 按钮尺寸 = MENU_BTN_SIZE；背景复用角色卡面素材 info_panel.png（见下方 StyleBoxTexture，9 宫格自适应）。
	var min_sz := MENU_BTN_SIZE
	wrap.custom_minimum_size = min_sz
	wrap.size = min_sz

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxTexture.new()
	sb.texture = load(CARD_BACK_TEX)   # 角色卡面背景（与读档 / 暂停 / 出战按钮统一）
	# 9 宫格：四边固定 28px 不变形，中间拉伸填满按钮；按钮高 75 >= 56，上下角不会重叠。
	sb.texture_margin_left = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", sb)
	wrap.add_child(panel)

	var lab := Label.new()
	lab.text = label
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", UIColors.WHITE)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lab.add_theme_constant_override("outline_size", 3)
	wrap.add_child(lab)

	var btn := Button.new()
	btn.flat = true
	btn.text = ""
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	btn.custom_minimum_size = min_sz
	btn.size = min_sz
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.disabled = true
	btn.mouse_entered.connect(func(): wrap.modulate = Color(1.18, 1.18, 1.18))
	btn.mouse_exited.connect(func(): wrap.modulate = Color(1.0, 1.0, 1.0))
	btn.pressed.connect(cb)
	wrap.add_child(btn)

	wrap.set_meta("lab", lab)
	wrap.set_meta("btn", btn)
	wrap.modulate.a = 0.0
	return wrap

# —— 主菜单「读取存档」浮层（2×2 读档格）——
# 与 pause_menu 的读档流程一致：写入 pending_restore_slot，再切到 main.tscn 由其 _ready 消费。
func _open_load_ui() -> void:
	if _load_overlay != null:
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_load_overlay = ov

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(600, 540)
	panel.size = Vector2(600, 540)
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://Assets/Sprites/UI/info_panel.png")
	sb.texture_margin_left = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", sb)
	ov.add_child(panel)
	call_deferred("_center_load_panel", panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.offset_left = 36.0
	vbox.offset_right = -36.0
	vbox.offset_top = 42.0
	vbox.offset_bottom = -30.0

	var title := Label.new()
	title.text = "读取存档"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UIColors.GOLD)
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
		grid.add_child(_make_load_card(i))

	vbox.add_child(_spacer(10))
	vbox.add_child(_menu_text_button("返回", _close_load_ui, Vector2(200.0, 48.0)))

func _make_load_card(index: int) -> Button:
	var meta: Dictionary = SaveManager.get_slot_meta(index) if SaveManager != null else {}
	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 170)
	card.text = ""
	card.add_theme_stylebox_override("normal", _slot_card_stylebox(Color(1.0, 1.0, 1.0)))
	card.add_theme_stylebox_override("hover", _slot_card_stylebox(Color(1.22, 1.28, 1.4)))
	card.add_theme_stylebox_override("pressed", _slot_card_stylebox(Color(1.4, 1.5, 1.6)))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.offset_left = 18.0
	box.offset_right = -18.0
	box.offset_top = 12.0
	box.offset_bottom = -12.0
	card.add_child(box)
	var head := Label.new()
	head.text = "存档 %d" % (index + 1)
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", UIColors.WHITE)
	box.add_child(head)
	if meta.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", UIColors.MUTED)
		box.add_child(empty)
		card.disabled = true
	else:
		var ch: String = meta.get("character", "???")
		var wi: String = meta.get("wave_info", "")
		var ti: String = _format_time(meta.get("time_survived", 0.0))
		var ts: String = meta.get("timestamp", "???")
		var l1 := Label.new(); l1.text = "角色：%s" % ch; l1.add_theme_font_size_override("font_size", 15); l1.add_theme_color_override("font_color", UIColors.WHITE); l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l1)
		var l2 := Label.new(); l2.text = "进度：%s" % wi; l2.add_theme_font_size_override("font_size", 15); l2.add_theme_color_override("font_color", UIColors.GRAY); l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l2)
		var l3 := Label.new(); l3.text = "存活：%s" % ti; l3.add_theme_font_size_override("font_size", 15); l3.add_theme_color_override("font_color", UIColors.GRAY); l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l3)
		var l4 := Label.new(); l4.text = ts; l4.add_theme_font_size_override("font_size", 13); l4.add_theme_color_override("font_color", UIColors.MUTED); l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l4)
		card.pressed.connect(_do_load.bind(index))
	return card

func _do_load(index: int) -> void:
	# 读档：先进角色选择页（道具跟随存档，只换出战角色），选完角色后由 main.tscn 还原进度
	if SaveManager != null:
		SaveManager.menu_load_slot = index
	_close_load_ui()
	get_tree().change_scene_to_file("res://Scenes/character_setup.tscn")

func _close_load_ui() -> void:
	if _load_overlay != null:
		_load_overlay.queue_free()
		_load_overlay = null

# —— 主菜单「开始游戏」：先选存档槽，再进选角色页面 ——
func _open_new_game_ui() -> void:
	if _new_game_overlay != null:
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_new_game_overlay = ov

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(600, 540)
	panel.size = Vector2(600, 540)
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://Assets/Sprites/UI/info_panel.png")
	sb.texture_margin_left = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", sb)
	ov.add_child(panel)
	call_deferred("_center_load_panel", panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.offset_left = 36.0
	vbox.offset_right = -36.0
	vbox.offset_top = 42.0
	vbox.offset_bottom = -30.0

	var title := Label.new()
	title.text = "选择新游戏存档位置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIColors.GOLD)
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
		grid.add_child(_make_new_game_card(i))

	vbox.add_child(_spacer(10))
	vbox.add_child(_menu_text_button("返回", _close_new_game_ui, Vector2(200.0, 48.0)))

# 单个「开始游戏」选卡槽：空格→直接新建；已有存档→点选后弹覆盖确认
func _make_new_game_card(index: int) -> Button:
	var meta: Dictionary = SaveManager.get_slot_meta(index) if SaveManager != null else {}
	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 170)
	card.text = ""
	card.add_theme_stylebox_override("normal", _slot_card_stylebox(Color(1.0, 1.0, 1.0)))
	card.add_theme_stylebox_override("hover", _slot_card_stylebox(Color(1.22, 1.28, 1.4)))
	card.add_theme_stylebox_override("pressed", _slot_card_stylebox(Color(1.4, 1.5, 1.6)))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.offset_left = 18.0
	box.offset_right = -18.0
	box.offset_top = 12.0
	box.offset_bottom = -12.0
	card.add_child(box)
	var head := Label.new()
	head.text = "存档 %d" % (index + 1)
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", UIColors.WHITE)
	box.add_child(head)
	if meta.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", UIColors.MUTED)
		box.add_child(empty)
		var hint := Label.new()
		hint.text = "点击新建"
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", UIColors.GRAY)
		box.add_child(hint)
		card.pressed.connect(_start_new_game.bind(index))
	else:
		var ch: String = meta.get("character", "???")
		var wi: String = meta.get("wave_info", "")
		var ti: String = _format_time(meta.get("time_survived", 0.0))
		var ts: String = meta.get("timestamp", "???")
		var l1 := Label.new(); l1.text = "角色：%s" % ch; l1.add_theme_font_size_override("font_size", 15); l1.add_theme_color_override("font_color", UIColors.WHITE); l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l1)
		var l2 := Label.new(); l2.text = "进度：%s" % wi; l2.add_theme_font_size_override("font_size", 15); l2.add_theme_color_override("font_color", UIColors.GRAY); l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l2)
		var l3 := Label.new(); l3.text = "存活：%s" % ti; l3.add_theme_font_size_override("font_size", 15); l3.add_theme_color_override("font_color", UIColors.GRAY); l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l3)
		var l4 := Label.new(); l4.text = ts; l4.add_theme_font_size_override("font_size", 13); l4.add_theme_color_override("font_color", UIColors.MUTED); l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l4)
		card.pressed.connect(_confirm_overwrite.bind(index))
	return card

# 已有存档的槽被点选：弹「确认覆盖」
func _confirm_overwrite(index: int) -> void:
	if _new_game_overlay == null:
		return
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_game_overlay.add_child(c)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(380, 190)
	panel.size = Vector2(380, 190)
	panel.add_theme_stylebox_override("panel", _slot_card_stylebox(Color(1.0, 1.0, 1.0)))   # 角色卡面背景
	c.add_child(panel)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp != Vector2.ZERO:
		panel.position = (vp - panel.size) * 0.5
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24.0
	v.offset_right = -24.0
	v.offset_top = 22.0
	v.offset_bottom = -22.0
	v.add_theme_constant_override("separation", 14)
	var t := Label.new()
	t.text = "该存档已有内容，确定覆盖吗？"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", UIColors.GOLD)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	t.add_theme_constant_override("outline_size", 3)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(row)
	row.add_theme_constant_override("separation", 16)
	var yes := _menu_text_button("确定覆盖", func(): c.queue_free(); _start_new_game(index), Vector2(150.0, 46.0))
	var no := _menu_text_button("取消", func(): c.queue_free(), Vector2(150.0, 46.0))
	row.add_child(yes)
	row.add_child(no)

# 选定槽后：绑定 active_slot、清空旧内容（已确认覆盖）、关闭浮层、进入选角色页
func _start_new_game(index: int) -> void:
	# 新游戏 = 全新一局：清掉任何残留的读档/还原全局状态，避免继承别的存档槽数据
	if RunStats != null:
		RunStats.reset_for_new_run()
	if SaveManager != null:
		SaveManager.pending_restore_slot = -1
		SaveManager.pending_restore_data = {}
		SaveManager.menu_load_slot = -1
		SaveManager.active_slot = index
		SaveManager.clear_slot(index)
	if EquipmentManager != null:
		# 新建存档：局外养成回到干净起点，避免继承之前残留的等级/钻石/仓库
		EquipmentManager.reset_equip_to_default()
	# 立刻把这个新档落盘（Lv.1 / 0钻 / 空仓库 + meta），
	# 否则槽里仍是 null，玩家回主菜单会看到「（空）」，以为新建没生效。
	if SaveManager != null and EquipmentManager != null:
		SaveManager.init_new_slot(index, EquipmentManager.get_equip_state())
	_close_new_game_ui()
	_start_game()

func _close_new_game_ui() -> void:
	if _new_game_overlay != null:
		_new_game_overlay.queue_free()
		_new_game_overlay = null

func _center_load_panel(panel: Panel) -> void:
	if panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		return
	panel.position = (vp - panel.size) * 0.5

func _format_time(t: float) -> String:
	var total: int = int(t)
	var m: int = total / 60
	var s: int = total % 60
	return "%02d:%02d" % [m, s]

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

# 存档槽 / 菜单按钮的卡面背景（info_panel.png，9 宫格自适应）。tint 用于悬停/按下时的高亮反馈。
func _slot_card_stylebox(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(CARD_BACK_TEX)
	sb.texture_margin_left = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_bottom = 28.0
	sb.modulate_color = tint
	return sb

# 角色卡面背景（info_panel.png）构造器：存档页「返回」、覆盖确认「确定覆盖 / 取消」等复用，
# 与主页三按钮、暂停 / 出战按钮视觉统一。compact 边距（16）适配高度 < 56 的小按钮，避免上下角重叠。
func _menu_btn_stylebox(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(CARD_BACK_TEX)
	sb.texture_margin_left = 16.0
	sb.texture_margin_top = 16.0
	sb.texture_margin_right = 16.0
	sb.texture_margin_bottom = 16.0
	sb.modulate_color = tint
	return sb

func _menu_text_button(text: String, cb: Callable, min_sz: Vector2 = Vector2(200.0, 48.0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_sz
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	# 同时覆盖 normal/hover/pressed：否则 hover 会回落到主题默认灰底（即「变灰」）
	b.add_theme_stylebox_override("normal", _menu_btn_stylebox(Color(1.0, 1.0, 1.0)))
	b.add_theme_stylebox_override("hover", _menu_btn_stylebox(Color(1.18, 1.2, 1.25)))
	b.add_theme_stylebox_override("pressed", _menu_btn_stylebox(Color(1.35, 1.4, 1.5)))
	b.add_theme_color_override("font_color", UIColors.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 3)
	b.pressed.connect(cb)
	return b

# —— 资源/纹理辅助 ——

# 标题整图：把「这也叫地牢」整图均匀切成 5 个字，逐字掉落入场（见 _ready）
func _make_title(fnt: Font) -> Control:
	var path: String = TITLE_DIR + "title_main.png"
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var h := 288.0
		var sc: float = h / max(1.0, float(tex.get_height()))
		var tw: float = tex.get_width() * sc
		var n := 5
		var cw: float = tw / float(n)                      # 每字显示宽度
		var ch: float = float(tex.get_width()) / float(n)  # 原图每字宽度（像素）
		var box := Control.new()
		box.custom_minimum_size = Vector2(tw, h)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_chars.clear()
		for i in n:
			var region := Rect2(ch * float(i), 0.0, ch, float(tex.get_height()))
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = region
			var cb := _make_char_box(at, cw, h)
			cb.position = Vector2(cw * float(i), 0.0)
			box.add_child(cb)
			_title_chars.append(cb)
		wrapper.custom_minimum_size = Vector2(tw, h)
		wrapper.add_child(box)
	else:
		var lab := Label.new()
		lab.text = "这也叫地牢"
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", fnt)
		wrapper.custom_minimum_size = Vector2(900.0, 320.0)
		wrapper.add_child(lab)
	return wrapper
	# 回退：逐字（每字再各自回退文字）
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for ch in "这也叫地牢":
		row.add_child(_make_title_char(ch, fnt))
	return row

# 单个字的容器：外发光 → 投影 → 本体（三层都用同一切片图）
func _make_char_box(tex_slice: Texture2D, w: float, h: float) -> Control:
	var cb := Control.new()
	cb.custom_minimum_size = Vector2(w, h)
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.pivot_offset = Vector2(w * 0.5, h * 0.5)   # 旋转绕字中心，摇晃才自然

	var glow := TextureRect.new()
	glow.texture = tex_slice
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.custom_minimum_size = Vector2(w * 1.06, h * 1.06)
	glow.position = Vector2(-w * 0.03, -h * 0.03)
	glow.modulate = Color(1.0, 0.92, 0.7, 0.35)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.add_child(glow)

	var shadow := TextureRect.new()
	shadow.texture = tex_slice
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.custom_minimum_size = Vector2(w, h)
	shadow.position = Vector2(6.0, 10.0)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.55)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.add_child(shadow)

	var body := TextureRect.new()
	body.texture = tex_slice
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.custom_minimum_size = Vector2(w, h)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.add_child(body)

	return cb

# 标题逐字：有图用图（归一化高度 80px、保持比例），无图回退金色描边文字
func _make_title_char(ch: String, fnt: Font) -> Control:
	var path: String = TITLE_DIR + TITLE_MAP[ch] + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var h := 288.0
		var sc: float = h / max(1.0, float(tex.get_height()))
		tr.custom_minimum_size = Vector2(tex.get_width() * sc, h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lab := Label.new()
	lab.text = ch
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 64)
	lab.add_theme_color_override("font_color", UIColors.GOLD)
	lab.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lab.add_theme_constant_override("outline_size", 4)
	lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if fnt != null:
		lab.add_theme_font_override("font", fnt)
	return lab

func _load_font() -> Font:
	for p in [FONT_DIR + "title.ttf", FONT_DIR + "title.otf"]:
		if ResourceLoader.exists(p):
			var f = load(p)
			if f is Font:
				return f
	return null
