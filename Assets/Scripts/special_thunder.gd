extends Node2D

## 雷电法杖（特殊武器）：挂在玩家节点下。
## - 每隔一段时间对屏幕内的敌人放电。
## - 优先攻击敌群密集区域（邻域敌人数越多越优先）。
## - 对命中目标及其周围敌人造成范围伤害（AoE）。
## - 升级：1★=1 道雷电，最多 5★=5 道；随星级变粗、伤害增加、间隔缩短。
## - 攻击范围 = 当前显示屏幕（相机视口）。
## 数值从 SkillManager.stars(skill_id) 实时读取。

var skill_id: String = "special_thunder"
var _player: Node2D = null

var _timer: float = 0.0
var _interval: float = 1.8
var _bolt_count: int = 1
var _bolt_dmg: float = 1.2
var _bolt_width: float = 2.0

const DENSITY_R: float = 130.0   # 计算"密集度"的邻域半径
const AOE_R: float = 80.0        # 雷电范围伤害半径
const AOE_MULT: float = 0.5      # 范围伤害系数（主目标已吃全额，周围吃一半）

const BOLT_TEX := preload("res://Assets/Sprites/Skills/thunder_bolt.png")

func _ready() -> void:
	_player = get_parent()
	_apply_stats()

func _apply_stats() -> void:
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		st = 1
	# 雷电间隔整体缩短约一倍（用户要求）
	_interval = max(1.1, 1.8 - 0.15 * float(st - 1))   # 1★≈1.8s … 5★≈1.1s
	_bolt_count = st                                   # 1★=1道 … 5★=5道
	_bolt_dmg = 1.2 + 0.7 * float(st - 1)
	_bolt_width = 3.0 + 4.0 * float(st - 1)   # 1★=3 … 5★=19，星间粗细差距为原设计的两倍（用户要求加倍增量）

func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		return
	if _interval != max(1.1, 1.8 - 0.15 * float(st - 1)):
		_apply_stats()
	_timer -= delta
	if _timer <= 0.0:
		_trigger()
		_timer = _interval

# 当前相机视口对应的世界矩形（攻击范围 = 显示屏幕）
func _in_view_rect() -> Rect2:
	var cam: Camera2D = null
	if _player != null and _player.has_method("get") and _player.get("camera") != null:
		cam = _player.get("camera")
	if cam == null:
		return Rect2(_player.global_position - Vector2(600, 350), Vector2(1200, 700))
	var vp: Vector2 = get_viewport_rect().size
	var half: Vector2 = vp * 0.5 / cam.zoom
	return Rect2(cam.global_position - half, half * 2.0)

func _trigger() -> void:
	var view: Rect2 = _in_view_rect()
	# 扩大判定范围（边缘留 padding），避免 BOSS 刚在屏幕外生成 / 处于屏幕边缘时漏打
	var pad: float = 180.0
	var big_view := Rect2(view.position - Vector2(pad, pad), view.size + Vector2(pad * 2.0, pad * 2.0))
	var enemies := get_tree().get_nodes_in_group("enemy")
	var alive := []
	for e in enemies:
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		alive.append(e)
	if alive.is_empty():
		return
	# 优先打屏幕内（含边缘 padding）的敌人；屏幕内没有时（如 BOSS 刚在屏外生成），兜底打离玩家最近的敌人
	var in_view := []
	for e in alive:
		if big_view.has_point(e.global_position):
			in_view.append(e)
	if in_view.is_empty():
		alive.sort_custom(func(a, b): return a.global_position.distance_to(_player.global_position) < b.global_position.distance_to(_player.global_position))
		# 仅纳入离玩家较近（≤1000px）的敌人，避免隔屏误伤远处刚刷的怪
		for e in alive:
			if _player != null and e.global_position.distance_to(_player.global_position) <= 1000.0:
				in_view.append(e)
	if in_view.is_empty():
		return
	# 按"邻域内敌人数"排序，优先密集区
	var scored := []
	for e in in_view:
		var d: int = 0
		for o in in_view:
			if o != e and e.global_position.distance_to(o.global_position) <= DENSITY_R:
				d += 1
		scored.append({"e": e, "d": d})
	scored.sort_custom(func(a, b): return a["d"] > b["d"])
	var n: int = mini(_bolt_count, scored.size())
	for i in n:
		var tgt = scored[i]["e"]
		var tpos: Vector2 = tgt.global_position
		# 主目标吃全额伤害
		if tgt.has_method("take_damage"):
			tgt.take_damage(_bolt_dmg)
		# 范围伤害：命中点周围敌人（除主目标外）受到溅射
		for o in in_view:
			if o == tgt:
				continue
			if not (o is Node2D):
				continue
			if o.has_method("is_dead") and o.is_dead():
				continue
			if tpos.distance_to(o.global_position) <= AOE_R:
				if o.has_method("take_damage"):
					o.take_damage(_bolt_dmg * AOE_MULT)
		_spawn_bolt(tpos)
		_spawn_effect(tpos)
		_spawn_ring(tpos)   # 不造成伤害，仅标示雷电攻击范围

# 从屏幕顶部劈下一道锯齿闪电到目标（核心亮线 + 外发光层，星越高越粗）
func _spawn_bolt(target: Vector2) -> void:
	var cam: Camera2D = null
	if _player != null and _player.has_method("get") and _player.get("camera") != null:
		cam = _player.get("camera")
	var top_y: float = target.y - 400.0
	if cam != null:
		var vp: Vector2 = get_viewport_rect().size
		var half: Vector2 = vp * 0.5 / cam.zoom
		top_y = cam.global_position.y - half.y
	# 生成锯齿路径
	var pts: PackedVector2Array = []
	pts.append(Vector2(target.x, top_y))
	var segs: int = 5
	for i in segs:
		var t: float = float(i + 1) / float(segs)
		var y: float = lerp(top_y, target.y, t)
		var x: float = target.x + randf_range(-18.0, 18.0) * (1.0 - abs(t - 0.5) * 2.0)
		pts.append(Vector2(x, y))
	pts.append(target)
	var world: Node = _player.get_parent()
	if world == null:
		return
	# 外发光层：半透明、宽度 = 核心 × 2.2，星越高整束越"胖"越亮
	var glow := Line2D.new()
	glow.width = _bolt_width * 2.2
	glow.default_color = Color(0.45, 0.8, 1.0, 0.35)
	glow.points = pts
	glow.z_index = 14
	world.add_child(glow)
	# 核心亮线：细而亮，承载主视觉
	var core := Line2D.new()
	core.width = _bolt_width
	core.default_color = Color(0.9, 0.97, 1.0, 1.0)
	core.points = pts
	core.z_index = 15
	world.add_child(core)
	# 一起淡出
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(core, "modulate:a", 0.0, 0.2)
	tw.tween_callback(glow.queue_free)
	tw.tween_callback(core.queue_free)

# 在命中点播放电击效果图片（从玩家素材复制过来的雷电电击效果）
func _spawn_effect(pos: Vector2) -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	var sp := Sprite2D.new()
	sp.texture = BOLT_TEX
	sp.z_index = 18
	sp.scale = Vector2(0.45, 0.45)
	sp.modulate.a = 0.95
	world.add_child(sp)
	sp.global_position = pos
	sp.rotation = randf_range(-0.26, 0.26)   # 随机 ±15°，避免所有效果角度一致
	var tw := create_tween()
	tw.tween_property(sp, "scale", Vector2(0.7, 0.7), 0.1)
	tw.tween_property(sp, "modulate:a", 0.0, 0.22)
	tw.tween_callback(sp.queue_free)

# 在命中点绘制一圈"雷圈"，标示雷电攻击范围（AOE_R）。
# 纯视觉、不造成伤害；从略小放大到满半径并淡出，像一道冲击波。
func _spawn_ring(pos: Vector2) -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	var ring := Line2D.new()
	ring.closed = true
	var pts: int = 40
	for i in pts:
		var a: float = TAU * float(i) / float(pts)
		ring.add_point(Vector2(cos(a), sin(a)) * AOE_R)
	ring.width = 3.0
	ring.default_color = Color(0.55, 0.9, 1.0, 0.9)
	ring.z_index = 17
	ring.scale = Vector2(0.82, 0.82)
	world.add_child(ring)
	ring.global_position = pos
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.05, 1.05), 0.35)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	tw.tween_callback(ring.queue_free)
