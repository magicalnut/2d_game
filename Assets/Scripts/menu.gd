extends Control

## 初始主菜单（极简）：仅「这也叫地牢」标题 + 一个「?」开始键。
## 「?」既是标点也是开始按钮：悬停放大、点击 / Enter / Space / J / 触屏均可开始。
## 标题：Assets/Sprites/Title/title_main.png（「这也叫地牢」整图）会被均匀切成 5 个字，逐字从屏幕外掉落入场；char_q.png 作「?」按钮图标；缺失则回退逐字/金色文字（见该目录 README）。
## 特殊字体 Assets/Fonts/title.ttf 仍作为回退文字的字体（缺失则用默认字体）。

const SETUP_SCENE := "res://Scenes/character_setup.tscn"
const FONT_DIR := "res://Assets/Fonts/"
const TITLE_DIR := "res://Assets/Sprites/Title/"

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
var _shake_targets: Array = []  # 需要「鼠标靠近摇晃」的标题字符控件（图片模式=逐字切片，回退=整行子节点）
var _title_ready: bool = false  # 入场动画结束后再启用摇晃，避免与掉落补间冲突
var _sk_menu: Node = null        # 初始页角落骷髅层（标题出现后再触发滚入）
var _char_base: Array = []      # 每个字符静止时的基准 position
var _char_shake: Array = []     # 每个字符当前摇晃幅度包络 0..1（near 时升、离开时降）
var _char_phase: Array = []     # 每个字符摇晃相位（错峰，避免五个字同步抖）
const TITLE_NEAR: float = 40.0  # 鼠标距字符多近算「靠近」（像素）；调大=更容易触发摇晃

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
	# 角落骷髅：左下/右下各一只（白色，透明素材），初始页标题出现后从屏幕上方外面从天而降
	var sk_menu := preload("res://Assets/Scripts/skull_layer.gd").new()
	sk_menu.skull_dir = "res://Assets/Sprites/Skulls/White/"
	sk_menu.skull_tint = Color(0.6, 0.6, 0.66, 1.0)   # 白色骷髅调暗（想再暗/再亮改这里：值越小越暗，1.0=原样）
	sk_menu.roll_in = true          # 本层使用滚入动画（auto_roll_in=false → 不自动滚，由标题入场后触发）
	add_child(sk_menu)
	_sk_menu = sk_menu

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
	# 摇晃目标：有整图切片则逐字，否则用回退整行的各子节点
	if _title_chars.is_empty():
		_shake_targets = title_row.get_children()
	else:
		_shake_targets = _title_chars

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
	q.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
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
	q.pressed.connect(_start_game)

	# 设置按钮（左上角，缩小+字体变暗）：优先用美术图 Gear/settings.png，缺失则回退文字
	var settings_btn := Button.new()
	settings_btn.flat = true
	var _settings_tex_path := "res://Assets/Sprites/UI/Gear/settings.png"
	if ResourceLoader.exists(_settings_tex_path):
		var _stx := load(_settings_tex_path) as Texture2D
		settings_btn.icon = _stx
		settings_btn.text = ""
		settings_btn.expand_icon = true
		settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var _sz := _stx.get_size()
		if _sz.y > 57.2:
			_sz = _sz * (57.2 / _sz.y)   # 限制高度（原 44 的 1.3 倍），避免过大
		settings_btn.custom_minimum_size = _sz
		for _st in ["normal", "hover", "pressed", "focus"]:
			settings_btn.add_theme_stylebox_override(_st, StyleBoxEmpty.new())
		var _base_mod := Color(1.0, 1.0, 1.0)
		settings_btn.mouse_entered.connect(func(): settings_btn.modulate = Color(1.3, 1.3, 1.3))
		settings_btn.mouse_exited.connect(func(): settings_btn.modulate = _base_mod)
	else:
		settings_btn.text = "设置"
		settings_btn.add_theme_font_size_override("font_size", 26)
		settings_btn.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80))
		settings_btn.add_theme_color_override("font_hover_color", Color(0.82, 0.90, 1.0))
		settings_btn.add_theme_constant_override("outline_size", 2)
		settings_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		settings_btn.custom_minimum_size = Vector2(70, 36)
	settings_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(settings_btn)
	settings_btn.position = Vector2(12, 12)
	settings_btn.pressed.connect(_open_settings)

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
		# 标题逐字从屏幕外上方掉落、错峰、带回弹；落地后绷出黑色绑带把字拉住
		for i in range(_title_chars.size()):
			var cb = _title_chars[i]
			cb.position.y = -800.0
			cb.modulate.a = 0.0
			var ct := create_tween()
			ct.tween_interval(0.10 * float(i))
			ct.tween_property(cb, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ct.parallel().tween_property(cb, "modulate:a", 1.0, 0.3)
			ct.tween_callback(_add_straps.bind(cb, i))

	# 骷髅：标题一开始掉落就同步从天而降（用户要求「这也叫地牢」出现后立马掉落，不再长延迟）
	if _sk_menu != null:
		_sk_menu.begin_roll_in(0.3)

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

	# 等待标题入场（掉落 + 绑带）完成，再启用「鼠标靠近摇晃」，并捕获各字静止基准位置
	await get_tree().create_timer(0.10 * float(_shake_targets.size()) + 0.75).timeout
	# 关键：必须先把三个摇晃数组填满，再把 _title_ready 置 true。
	# 否则 _process 的守卫(if not _title_ready)一旦放行，就会访问尚未填充的
	# _char_shake/_char_phase 空数组 → "Out of bounds get index '0'"。
	# （切勿在填充数组前 await——await 挂起期间 _process 仍每帧运行。）
	for i in _shake_targets.size():
		_char_base.append(_shake_targets[i].position)
		_char_shake.append(0.0)
		_char_phase.append(randf() * 100.0)
	_title_ready = true

# 落地后在字上方绷出几根垂直向下的线，模拟被从上方拉住、不再往下掉
func _add_straps(cb: Control, idx: int) -> void:
	var sz: Vector2 = cb.custom_minimum_size
	var w: float = sz.x
	var top: float = 0.0
	# 上方起始点（屏幕外一点），从那儿往下拉到字上边缘
	var top_y: Array = [-34.0, -26.0, -30.0]
	var xs: Array = [w * 0.30, w * 0.50, w * 0.70]
	var count: int = 3 if (idx % 2 == 0) else 2
	for k in count:
		var start_y: float = float(top_y[k])
		var end_y: float = top
		var len: float = end_y - start_y
		var sw: float = 3.0
		var xx: float = float(xs[k])
		var strap := ColorRect.new()
		strap.color = Color(0.05, 0.05, 0.06, 0.92)
		strap.custom_minimum_size = Vector2(sw, len)
		strap.size = Vector2(sw, len)
		strap.position = Vector2(xx - sw * 0.5, start_y)
		strap.pivot_offset = Vector2(sw * 0.5, 0.0)   # 顶边为锚：向下绷紧
		strap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strap.scale = Vector2(1.0, 0.0)
		strap.modulate.a = 0.0
		cb.add_child(strap)
		var st := create_tween()
		st.tween_interval(0.02 * float(k))
		st.tween_property(strap, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(strap, "modulate:a", 1.0, 0.12)

func _begin_idle(q_wrap: Control) -> void:
	_q_idle_tween = create_tween()
	_q_idle_tween.set_loops()
	_q_idle_tween.tween_property(q_wrap, "scale", Vector2(1.03, 1.03), 1.4).set_ease(Tween.EASE_IN_OUT)
	_q_idle_tween.tween_property(q_wrap, "scale", Vector2(1.0, 1.0), 1.4).set_ease(Tween.EASE_IN_OUT)

# 鼠标靠近标题字符时，字会紧张地摇晃（旋转抖动 + 轻微位移），离开后平息
func _process(delta: float) -> void:
	if not _title_ready:
		return
	# 二重保险：摇晃数组尚未与目标一一对齐时，本帧不处理（防止任何时序竞态越界）
	if _char_shake.size() < _shake_targets.size() or _char_phase.size() < _shake_targets.size():
		return
	# 取鼠标在「画布全局坐标」的位置：Godot 4.7 中 get_viewport() 返回 Window，
	# 其上无 get_global_mouse_position()（旧 API 已移除），改用 get_mouse_position() + 画布变换。
	var vp := get_viewport()
	var mp: Vector2 = vp.get_mouse_position()
	mp = vp.get_canvas_transform().affine_inverse() * mp
	for i in _shake_targets.size():
		var cb: Control = _shake_targets[i]
		var rect: Rect2 = cb.get_global_rect()
		# 鼠标到字包围盒的最近距离（含字外「靠近」区，不含则=0）
		var dx: float = max(rect.position.x - mp.x, 0.0, mp.x - rect.end.x)
		var dy: float = max(rect.position.y - mp.y, 0.0, mp.y - rect.end.y)
		var d: float = sqrt(dx * dx + dy * dy)
		var near: bool = d < TITLE_NEAR
		var amp: float = _char_shake[i]
		if near:
			amp = min(1.0, amp + delta * 5.0)       # 靠近：幅度快速升到 1
		else:
			amp = max(0.0, amp - delta * 7.0)       # 离开：幅度快速回落
		_char_shake[i] = amp
		_char_phase[i] += delta * (36.0 if near else 18.0)
		var a: float = amp
		var rot: float = sin(_char_phase[i]) * 0.05 * a            # 旋转抖动（≈±3°）
		var jx: float = sin(_char_phase[i] * 1.3 + 1.0) * 2.0 * a  # 水平轻微位移
		var jy: float = cos(_char_phase[i] * 1.7 + 2.0) * 2.0 * a  # 垂直轻微位移
		cb.rotation = rot
		cb.position = (_char_base[i] as Vector2) + Vector2(jx, jy)

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
			var tw := create_tween()
			tw.tween_method(_set_q_intensity, _q_shader.get_shader_parameter("intensity"), 1.0, 0.18)
			_q_glow_tween = tw
		else:
			# 文字回退：把描边变黄加粗
			q.add_theme_color_override("font_outline_color", Color(1.0, 0.85, 0.15, 1.0))
			q.add_theme_constant_override("outline_size", 9)
	else:
		# 没被盯着：收起黄色、恢复呼吸
		if _q_shader != null:
			var tw := create_tween()
			tw.tween_method(_set_q_intensity, _q_shader.get_shader_parameter("intensity"), 0.0, 0.24)
			_q_glow_tween = tw
		else:
			q.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
			q.add_theme_constant_override("outline_size", 4)
		_begin_idle(_q_wrap)

func _unhandled_input(ev: InputEvent) -> void:
	if _starting:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_J:
			_start_game()

func _open_settings() -> void:
	var ui := preload("res://Assets/Scripts/settings_ui.gd").new()
	add_child(ui)

func _start_game() -> void:
	if _starting:
		return
	_starting = true
	if RunStats != null:
		RunStats.game_mode = "endless"
	var tw := create_tween()
	tw.tween_property(_q, "scale", Vector2(0.82, 0.82), 0.12).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_fade, "modulate", Color(1, 1, 1, 1), 0.34)
	tw.tween_callback(_go)

func _go() -> void:
	get_tree().change_scene_to_file(SETUP_SCENE)

# —— 资源/纹理辅助 ——

# 标题整图：把「这也叫地牢」整图均匀切成 5 个字，逐字掉落入场（见 _ready）
func _make_title(fnt: Font) -> Control:
	var path: String = TITLE_DIR + "title_main.png"
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
		return box
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
	lab.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
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
