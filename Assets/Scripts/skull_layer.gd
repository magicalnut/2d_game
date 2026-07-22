extends Control

## 角落骷髅装饰层：扫描指定目录的 skull.png，
## 静态贴在左下角与右下角（不游荡，区别于背景鬼影）。
## 颜色由素材本身决定（初始页 White/ 透明、选角色页 Red/ 红色），脚本不再着色。

var skull_dir: String = "res://Assets/Sprites/Skulls/White/"
var skull_tint: Color = Color(1.0, 1.0, 1.0, 1.0)   # 默认白色=不着色；如需整体微调再设
var skull_target_h: float = 240.0                    # 骷髅目标高度（像素），按此等比缩放（约原 150 的 1.6 倍；要精确倍数改这里）
var skull_margin: float = 8.0                         # 距角落边缘的留白（尽量贴近角落、保持完整不被屏角裁掉）
var flip_right: bool = true    # 右角落骷髅水平镜像：素材原型朝左，右角落需左右颠倒（左角落保持原型）
var roll_in: bool = false      # 本层是否使用「从天而降」动画（初始页=true；选角色页=false 静态就位）
var auto_roll_in: bool = false # 是否自动触发滚入；若由外部（如标题入场后）控制，保持 false 并调用 begin_roll_in()

var _skulls: Array = []   # 每个 = {tr, left}
var _rolled_in: bool = false   # 是否已滚入到位；未滚入前骷髅藏在屏外、不可见

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_skulls()
	if not _skulls.is_empty():
		get_viewport().size_changed.connect(_reposition)
		if roll_in and auto_roll_in:
			call_deferred("_roll_in")                    # 自动滚入
		elif roll_in:
			call_deferred("_place_outside")              # 等待 begin_roll_in()：先藏到屏外、不可见
		else:
			call_deferred("_reposition")                 # 静态就位（选角色页）

func _load_skulls() -> void:
	var p: String = skull_dir + "skull.png"
	if not ResourceLoader.exists(p):
		return
	var tex: Texture2D = load(p)
	_skulls.append(_make(tex, true))    # 左下
	_skulls.append(_make(tex, false))   # 右下

func _make(tex: Texture2D, left: bool) -> Dictionary:
	# 预缩放纹理到目标高度，避免依赖 expand 枚举导致尺寸/溢出不确定
	var img := tex.get_image()
	var aspect: float = float(img.get_width()) / float(img.get_height())
	var h: int = int(skull_target_h)
	var w: int = int(h * aspect)
	img = img.duplicate()
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	if (not left) and flip_right:
		img.flip_x()   # 右角落：素材原型朝左 → 水平镜像，使朝向对称
	var it := ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = it
	tr.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = skull_tint
	tr.custom_minimum_size = Vector2(w, h)
	tr.size = Vector2(w, h)
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(tr)
	return {"tr": tr, "left": left}

func _reposition() -> void:
	if roll_in and not _rolled_in:
		return   # 尚在屏外待命，未滚入前不要把骷髅放到角落提前显示
	var vp := get_viewport_rect().size
	for s in _skulls:
		var tr: Control = s.tr
		var w: float = tr.size.x
		var h2: float = tr.size.y
		var x: float = skull_margin if s.left else (vp.x - w - skull_margin)
		var y: float = vp.y - h2 - skull_margin
		tr.position = Vector2(x, y)

# 初始页专用：像篮球一样从屏外「横向滚」进角落——
# 左骷髅从屏外左边滚入（向右、顺时针），右骷髅从屏外右边滚入（向左、逆时针），
# 到角落时正好转正（rotation=0）停住；绕中心翻滚（pivot=中心）。
# 仅在首次 _reposition 之后调用一次；窗口缩放触发的 _reposition 只瞬移就位、不重滚。
func _corner_pos(s: Dictionary) -> Vector2:
	var tr: Control = s.tr
	var w: float = tr.size.x
	var h2: float = tr.size.y
	var vp := get_viewport_rect().size
	var x: float = skull_margin if s.left else (vp.x - w - skull_margin)
	var y: float = vp.y - h2 - skull_margin
	return Vector2(x, y)

# 初始页专用：从屏幕「上方外面」从天而降，竖直落到当前角落位置；
# 落地时挤压回弹并迸发烟尘（FXManager 死亡烟尘，左右脚各一团）。
# 仅在触发时调用一次；窗口缩放触发的 _reposition 只瞬移就位、不重滚。
func _roll_in() -> void:
	for s in _skulls:
		var tr: Control = s.tr
		var w: float = tr.size.x
		var h2: float = tr.size.y
		var target: Vector2 = _corner_pos(s)            # 最终角落位置（独立计算，不依赖当前位置）
		tr.pivot_offset = Vector2(w * 0.5, h2 * 0.5)    # 绕中心挤压 / 翻转
		# 起点：屏幕上方外面，x 对齐最终 x，y 在屏幕顶之上（完全不可见）
		var start: Vector2 = Vector2(target.x, -h2 - skull_margin)
		tr.visible = true                               # 之前藏在屏外，现在显示并下落
		tr.position = start
		tr.rotation = randf_range(-0.18, 0.18)          # 轻微倾斜，增加自然动感
		var fall_dur: float = 0.9 + randf() * 0.25      # 0.9~1.15s，两骷髅略有错峰
		var t := create_tween()
		t.tween_property(tr, "position:y", target.y, fall_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(tr, "rotation", 0.0, fall_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(_land.bind(s))                # 落定：挤压回弹 + 烟尘
	_rolled_in = true

# 落地反馈：挤压回弹（绕中心压扁再恢复）+ 在骷髅底部左右各迸一团烟尘
func _land(s: Dictionary) -> void:
	var tr: Control = s.tr
	var w: float = tr.size.x
	var h2: float = tr.size.y
	var tw := create_tween()
	tw.tween_property(tr, "scale", Vector2(1.12, 0.86), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tr, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 落地烟尘（FXManager 死亡烟尘；FXManager 为 AutoLoad 单例，本工程已注册）
	var base: Vector2 = tr.get_global_transform() * Vector2(w * 0.5, h2)   # 骷髅底部中点（画布/世界坐标）
	FXManager.spawn_death_poof(base + Vector2(-w * 0.22, 0.0), 0.7)
	FXManager.spawn_death_poof(base + Vector2(w * 0.22, 0.0), 0.7)

# 由外部在合适时机调用（如标题出现之后）：播放滚入。
# delay>0 时先等待若干秒，可让滚入更「从容」地晚一点发生。
func begin_roll_in(delay := 0.0) -> void:
	if not roll_in or _skulls.is_empty():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_roll_in()

# 等待滚入触发前的待命状态：把骷髅移到屏外并隐藏，避免提前出现在角落
func _place_outside() -> void:
	var vp := get_viewport_rect().size
	for s in _skulls:
		var tr: Control = s.tr
		var w: float = tr.size.x
		var h2: float = tr.size.y
		var y: float = vp.y - h2 - skull_margin
		var x: float = (-w - skull_margin) if s.left else (vp.x + skull_margin)
		tr.position = Vector2(x, y)
		tr.visible = false
