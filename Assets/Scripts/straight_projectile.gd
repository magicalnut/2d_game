extends Area2D

## 直线飞行弹体（飞镖 / 激光 等）：由 active_weapon 在运行时实例化。
## 可沿 direction 直线飞行，也可开启轻微 homing 追踪；命中敌人造成伤害，按 pierce 决定穿透或销毁。
## 与玩家基础武器 bullet.gd（自动追踪子弹）是两种完全不同的弹道，视觉/行为均区分。

@export var speed: float = 1000.0
@export var damage: float = 1.0
@export var max_lifetime: float = 3.0
@export var pierce: int = 0          # 可穿透的敌人数（0=命中第一个即销毁）

var direction: Vector2 = Vector2.RIGHT
var tex: Texture2D = null            # 弹体贴图（飞镖用飞镖图，激光用程序生成贴图）
var tex_scale: float = 1.0
var hit_radius: float = 8.0         # 命中判定半径（默认 8，箭等细弹体可单独调大）
var max_distance: float = 0.0        # 飞行最大距离（0=不限）；达到后引爆/销毁，用于限制燃烧瓶投掷半径
var homing: float = 0.0              # 追踪转向角速度(rad/s)，0 表示不追踪
var homing_range: float = 600.0
var homing_start_dist: float = 0.0   # 追踪起始距离：飞行超过该距离后才开始追踪（实现"先飞一段再追踪"）
var visual_rotation_offset: float = 0.0  # 纹理自身朝向修正：让"头部/长轴"真正指向 direction

# —— 抛物线弹道（弓箭等）：按 t 在 start→target 间插值并叠加弧高，target 实时跟随，t≥1 引爆 ——
var ballistic: bool = false
var _ball_start: Vector2 = Vector2.ZERO
var _ball_end: Vector2 = Vector2.ZERO
var _ball_target: Node2D = null
var _ball_t: float = 0.0
var _ball_dur: float = 0.55
var _ball_arc: float = 70.0
var ballistic_jitter: float = 0.0   # 飞行抖动幅度(px)，给弓箭加一点飘动感；0=不抖
var _ball_jitter_phase: float = 0.0

# —— 扩展：弹跳 / 自旋 / 命中爆燃（篮球 / 燃烧瓶等）——
var bounce: bool = false                 # 开启后撞边界反弹、不直接销毁（篮球）
var self_spin: float = 0.0               # 贴图自旋角速度(rad/s)，篮球等物理旋转
var fire_on_impact: bool = false         # 命中或到期时生成火焰区域（燃烧瓶）
var fire_radius: float = 60.0
var fire_duration: float = 2.5
var fire_tick: float = 0.5
var fire_damage: float = 1.0

# —— 扩展：飞行中体积逐渐增大（燃烧瓶旋转丢出、途中变大）——
var grow_over_life: bool = false
var grow_from: float = 1.0
var grow_to: float = 1.0

# —— 扩展：命中即时范围爆炸（双枪绝杀"绝杀爆弹"、箭雨落点溅射）——
# 命中敌人或到期引爆时，对 aoe_radius 内所有敌人结算 aoe_damage，并可附带击退。
var aoe_on_hit: bool = false
var aoe_radius: float = 90.0
var aoe_damage: float = 3.0
var aoe_knockback: float = 0.0
var aoe_tex: Texture2D = null            # 爆炸视觉贴图（缺省用弹体贴图放大）
var aoe_color: Color = Color(1.0, 0.6, 0.2, 0.95)

const FIRE_ZONE_SCRIPT := preload("res://Assets/Scripts/fire_zone.gd")

var _life: float = 0.0
var _hit: Dictionary = {}
var _sprite: Sprite2D = null
var _spin_acc: float = 0.0
var _origin: Vector2 = Vector2.ZERO   # 发射原点（玩家位置），用于 max_distance 判定
var _origin_set: bool = false
var max_bounces: int = 0             # 弹射次数上限（0=不限，用寿命）；达上限后自动消失（篮球）
var _bounces: int = 0
# —— 扩展：圆形竞技场弹跳（巧乐兹）——
var arena_bounce: bool = false       # 开启后：以玩家为圆心、arena_radius 为半径的圆内反弹（替代世界边界反弹）
var arena_radius: float = 192.0
# 圆形竞技场模式下的"穿透碾压"：对单个敌人设定最小命中间隔，避免每物理帧重复结算刷伤害
var _enemy_hit_cd: Dictionary = {}
const PIERCE_HIT_INTERVAL: float = 0.3

# 取玩家当前位置作为"圆形竞技场"圆心（实时跟随玩家移动）
func _get_player_center() -> Vector2:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p is Node2D:
		return p.global_position
	return global_position
var _consumed: bool = false    # 已结算过伤害（非穿透弹）：保证只命中一个敌人，杜绝同帧多段判定

# —— 扩展：箭矢等"有限穿透"弹体 —— 穿透耗尽后卡在最后一个敌人身上，随其移动，敌人消失才消失
var sticky: bool = false
var _stuck_target: Node2D = null

func _ready() -> void:
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2(tex_scale, tex_scale)
		add_child(_sprite)
	if ballistic:
		_ball_jitter_phase = randf() * TAU
	var shape := CircleShape2D.new()
	shape.radius = hit_radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_update_visual_rotation()

func _physics_process(delta: float) -> void:
	if not _origin_set:
		# 延迟到首帧再记录发射原点：spawn 时 global_position 在 add_child 之后才赋值，
		# 若在 _ready 里记录会拿到世界原点(0,0)，导致 max_distance 判定首帧即引爆（燃烧瓶丢在脚下）。
		_origin = global_position
		_origin_set = true
	# 已卡在敌人身上：跟随敌人移动，敌人消失则自身销毁
	if _stuck_target != null:
		if is_instance_valid(_stuck_target):
			global_position = _stuck_target.global_position
			return
		else:
			_stuck_target = null
			queue_free()
			return
	# 抛物线弹道（弓箭等）：按 t 在 start→target 间插值并叠加弧高，target 实时跟随，t≥1 引爆
	if ballistic:
		if _ball_target != null and is_instance_valid(_ball_target) and _ball_target.is_inside_tree():
			_ball_end = _ball_target.global_position
		_ball_t += delta / _ball_dur
		if _ball_t >= 1.0:
			_detonate()
			return
		var np := _ball_start.lerp(_ball_end, _ball_t)
		np.y -= _ball_arc * 4.0 * _ball_t * (1.0 - _ball_t)
		if ballistic_jitter > 0.0:
			var perp: Vector2 = Vector2(-direction.y, direction.x)
			np += perp * sin(_ball_t * 16.0 + _ball_jitter_phase) * ballistic_jitter
		var old := global_position
		global_position = np
		if old != np:
			direction = (np - old).normalized()
		_update_visual_rotation()
		return
	_life += delta
	if _life >= max_lifetime:
		call_deferred("_detonate")
		return
	if homing > 0.0:
		if homing_start_dist <= 0.0 or (_origin_set and global_position.distance_to(_origin) >= homing_start_dist):
			_apply_homing(delta)
	global_position += direction * speed * delta
	if bounce and arena_bounce:
		# 圆形竞技场反弹：以玩家为圆心、arena_radius 为半径，巧乐兹始终在圈内弹来弹去
		var center: Vector2 = _get_player_center()
		var off: Vector2 = global_position - center
		var dist: float = off.length()
		if dist > arena_radius:
			var n: Vector2
			if dist > 0.0001:
				n = off / dist
			else:
				n = Vector2(1.0, 0.0)
			global_position = center + n * arena_radius
			direction = direction.bounce(n).normalized()
	elif bounce:
		# 撞世界边界反弹（遇强则反弹），并计入弹射次数
		var bounced: bool = false
		if global_position.x < -60.0:
			global_position.x = -60.0; direction.x = abs(direction.x); bounced = true
		elif global_position.x > 5180.0:
			global_position.x = 5180.0; direction.x = -abs(direction.x); bounced = true
		if global_position.y < -60.0:
			global_position.y = -60.0; direction.y = abs(direction.y); bounced = true
		elif global_position.y > 2940.0:
			global_position.y = 2940.0; direction.y = -abs(direction.y); bounced = true
		if bounced:
			_bounces += 1
			if max_bounces > 0 and _bounces >= max_bounces:
				_detonate()
				return
	elif global_position.x < -80.0 or global_position.x > 5200.0 \
	     or global_position.y < -80.0 or global_position.y > 2960.0:
		_detonate()
		return
	# 投掷范围限制：飞出玩家设定半径后引爆/销毁（燃烧瓶）
	if max_distance > 0.0 and global_position.distance_to(_origin) >= max_distance:
		_detonate()
		return
	_spin_acc += self_spin * delta
	_update_visual_rotation()
	if _sprite != null and self_spin != 0.0:
		_sprite.rotation += _spin_acc
	if grow_over_life and _sprite != null:
		var t: float = clampf(_life / max_lifetime, 0.0, 1.0)
		var gs: float = grow_from + (grow_to - grow_from) * t
		_sprite.scale = Vector2(gs, gs)

func _detonate() -> void:
	if fire_on_impact:
		_spawn_fire_zone()
	if aoe_on_hit:
		_do_aoe()
	queue_free()

# 命中即时范围爆炸：对半径内所有敌人结算伤害+击退，并生成一次性爆炸视觉
func _do_aoe() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for e in tree.get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if global_position.distance_to(e.global_position) <= aoe_radius:
			if e.has_method("take_damage"):
				e.take_damage(aoe_damage)
			if aoe_knockback > 0.0 and e.has_method("apply_knockback"):
				e.apply_knockback(global_position, aoe_knockback)
	_spawn_blast_visual(global_position, aoe_radius)

func _spawn_blast_visual(pos: Vector2, radius: float) -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var t: Texture2D = aoe_tex if aoe_tex != null else tex
	if t == null:
		return
	var s := Sprite2D.new()
	s.texture = t
	s.global_position = pos
	s.z_index = 19
	s.modulate = aoe_color
	var full: float = (radius * 2.0) / max(1.0, float(t.get_width()))
	s.scale = Vector2(full * 0.4, full * 0.4)
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", Vector2(full, full), 0.18)
	tw.parallel().tween_property(s, "modulate", Color(aoe_color.r, aoe_color.g, aoe_color.b, 0.0), 0.22)
	tw.tween_callback(s.queue_free)

# 卡在敌人身上：关闭碰撞检测，跟随敌人；敌人消失（tree_exiting）时自身销毁
func _stick_to(target: Node2D) -> void:
	_stuck_target = target
	monitoring = false
	monitorable = false
	global_position = target.global_position
	if target.has_signal("tree_exiting"):
		target.tree_exiting.connect(_on_stick_target_gone)

func _on_stick_target_gone() -> void:
	queue_free()

func _spawn_fire_zone() -> void:
	var n := Area2D.new()
	n.set_script(FIRE_ZONE_SCRIPT)
	n.radius = fire_radius
	n.duration = fire_duration
	n.tick_interval = fire_tick
	n.damage = fire_damage
	var world: Node = get_parent()
	if world == null:
		return
	world.add_child(n)
	n.global_position = global_position

func _apply_homing(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var enemies := tree.get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_d: float = homing_range
	for e in enemies:
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null:
		var desired: Vector2 = (best.global_position - global_position).normalized()
		var diff: float = angle_difference(direction.angle(), desired.angle())
		var step: float = clampf(diff, -homing * delta, homing * delta)
		direction = direction.rotated(step).normalized()

func _update_visual_rotation() -> void:
	if _sprite != null:
		_sprite.rotation = direction.angle() + visual_rotation_offset

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if body.is_in_group("enemy"):
		# 命中即时范围爆炸弹（绝杀爆弹等）：命中第一个敌人立即引爆，范围结算后销毁
		if aoe_on_hit:
			_consumed = true
			_do_aoe()
			call_deferred("queue_free")
			return
		if bounce and arena_bounce:
			# 巧乐兹（圆形竞技场模式）：穿透敌人、只在圈边缘反弹。
			# 同一敌人两次碾压间隔冷却，避免每物理帧重复结算造成刷伤害。
			var id: int = body.get_instance_id()
			var last: float = _enemy_hit_cd.get(id, -999.0)
			if _life - last < PIERCE_HIT_INTERVAL:
				return
			_enemy_hit_cd[id] = _life
			if body.has_method("take_damage"):
				body.take_damage(damage)
			return
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if fire_on_impact:
			call_deferred("_detonate")
			return
		if bounce:
			# 从敌人身上弹开（弹射），并计入弹射次数；达上限后自动消失
			var away: Vector2 = (global_position - body.global_position).normalized()
			if away == Vector2.ZERO:
				away = direction
			direction = away
			_bounces += 1
			if max_bounces > 0 and _bounces >= max_bounces:
				queue_free()
			return
		var id: int = body.get_instance_id()
		if _hit.has(id):
			return
		_hit[id] = true
		if pierce <= 0:
			_consumed = true        # 不再造成更多伤害
			if sticky and (body is Node2D) and is_instance_valid(body):
				_stick_to(body)     # 有限穿透耗尽：卡在最后命中的敌人身上
			else:
				queue_free()
		else:
			pierce -= 1
