extends Control

## 背景鬼影游荡层：扫描指定目录下的 ghost_N.png，
## 让若干鬼影在背景层缓慢游荡（缓动漂移 + 上下浮动 + 透明度呼吸 + 随机相位）。
## 颜色直接由素材本身决定（初始页用 White/ 子目录白色素材、选角色页用 Red/ 子目录红色素材），
## 脚本不再做着色，ghost_tint 默认为白色（即不着色、保留素材原色）。

var ghost_dir: String = "res://Assets/Sprites/Ghosts/White/"
var ghost_tint: Color = Color(1.0, 1.0, 1.0, 1.0)   # 默认白色=不着色；如需整体微调再设
var ghost_count_max: int = 6

var _ghosts: Array = []   # 每个 = {tr, pos, target, phase, speed, float_amp, float_speed, rs}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_ghosts()

func _load_ghosts() -> void:
	# 优先：单张素材 ghost.png（用户通常只准备一张），用同一纹理生成多个游荡鬼影
	var single: String = ghost_dir + "ghost.png"
	if ResourceLoader.exists(single):
		var tex: Texture2D = load(single)
		for i in ghost_count_max:
			_add_ghost(tex)
		return
	# 回退：多张变体 ghost_1.png … ghost_N.png（用户若准备了不同造型）
	var n := 1
	while n <= ghost_count_max:
		var p: String = ghost_dir + "ghost_%d.png" % n
		if not ResourceLoader.exists(p):
			break
		_add_ghost(load(p))
		n += 1

func _rand_point() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(randf_range(40.0, vp.x - 40.0), randf_range(40.0, vp.y - 40.0))

func _add_ghost(tex: Texture2D) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var sc: float = randf_range(0.45, 0.95)
	var rs := Vector2(tw, th) * sc
	tr.scale = Vector2(sc, sc)
	tr.modulate = ghost_tint
	tr.modulate.a = 0.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var start := _rand_point()
	tr.position = start - rs * 0.5
	_ghosts.append({
		"tr": tr, "pos": start, "target": _rand_point(),
		"phase": randf() * TAU,
		"speed": randf_range(16.0, 38.0),
		"float_amp": randf_range(8.0, 22.0),
		"float_speed": randf_range(0.5, 1.1),
		"rs": rs,
	})

func _process(delta: float) -> void:
	for g in _ghosts:
		var tr: Control = g.tr
		var to: Vector2 = g.target - g.pos
		if to.length() < 24.0:
			g.target = _rand_point()
		else:
			g.pos += to.normalized() * g.speed * delta
		g.phase += delta * g.float_speed
		var fy: float = sin(g.phase) * g.float_amp
		tr.position = g.pos + Vector2(0.0, fy) - g.rs * 0.5
		tr.modulate.a = 0.22 + 0.22 * (sin(g.phase * 0.7) * 0.5 + 0.5)
