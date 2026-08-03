extends Node2D

## 主动武器行为节点（挂在 player 下，由 SkillManager.add_active 创建）。
##
## 设计准则（常识性修正）：
## - 不显示"头顶旋转图标"作装饰；武器是真弹道。
## - 无人机：悬浮在玩家身边（环绕），向最近敌人发射"激光弹体"（青色、高速，区别于通用子弹）。
## - 魔法书：悬浮在玩家周围（环绕），向最近敌人发射星形子弹（轻微追踪，随星级变大变强）。
## - 燃烧瓶：旋转丢出、途中体积逐渐增大，落地后生成持续火焰区（视觉用 燃烧效果.png）。
##   星瓶按"360° 均匀环绕"抛出（1★=1 瓶…5★=5 瓶），落点距玩家固定半径，5★ 在玩家四周构成一圈燃烧圈。
## - 巧乐兹：弹跳飞行、自旋碾压，随星级变大变强。
## 星级从 SkillManager.owned[skill_id] 读取，无需本地状态。

var skill_id: String = ""

const BULLET_TEX := preload("res://Assets/Sprites/Weapons/Bullet/bullet.png")
const DRONE_TEX := preload("res://Assets/Sprites/Skills/active_drone.png")
const FIREBOMB_TEX := preload("res://Assets/Sprites/Skills/active_firebomb.png")
const BASKETBALL_TEX := preload("res://Assets/Sprites/Skills/active_basketball.png")
const BOOK_TEX := preload("res://Assets/Sprites/Skills/active_book.png")
const STAR_TEX := preload("res://Assets/Sprites/Skills/star_bullet.png")
const BOW_ARROW_TEX := preload("res://Assets/Sprites/Weapons/bow/arrow.png")
const FIST_TEX := preload("res://Assets/Sprites/Weapons/punch/fist.png")
const BOLT_TEX := preload("res://Assets/Sprites/Weapons/lightning/bolt.png")
const MUZZLE_TEX := preload("res://Assets/Sprites/Effects/muzzle_flash.png")
const PROJ_SCRIPT := preload("res://Assets/Scripts/straight_projectile.gd")

const ORBIT_RADIUS: float = 58.0     # 无人机环绕半径
const ORBIT_SPEED: float = 1.9       # 无人机环绕角速度
const BOOK_ORBIT_RADIUS: float = 76.0  # 魔法书环绕半径（与无人机错开，避免重叠）
const BOOK_ORBIT_SPEED: float = 1.5

const BULLET_BASE_SCALE: float = 0.092   # 1★子弹缩放：384×216 源图 → 1★≈42×24 px（与玩家 76px 帧比约 0.55，体量清晰）
const BULLET_SCALE_PER_STAR: float = 0.017  # 5★≈68×38 px，随星明显变大（+62%），升级手感可见
const DRONE_DISP_PX: float = 46.0
# —— 特工手枪（闪现攻击）——
const PISTOL_FLASH_RADIUS: float = 46.0   # 手枪在玩家四周闪现的半径
const PISTOL_FLASH_STEP: float = TAU / 6.0  # 每次闪现绕玩家转动的角度（六等分环绕）
const PISTOL_DISP_PX: float = 44.0        # 闪现手枪的显示尺寸
const PISTOL_TEX_PATH := "res://Assets/Sprites/Skills/active_pistol.png"  # 优先使用技能卡图标（第一把枪）
const PISTOL_ALT_PATH := "res://Assets/Sprites/Weapons/pistol/pistol_alt.png"  # 第二把枪（用户提供的素材）
const PISTOL_DIR := "res://Assets/Sprites/Weapons/pistol/"                 # 可放自定义 pistol.png 覆盖
var PISTOL_TEX: Texture2D = null          # 闪现手枪贴图（缺省先加载技能卡图标，缺失再程序生成）
var PISTOL_TEX_2: Texture2D = null        # 第二把枪贴图（双枪绝杀用；缺省回退到第一把）
const LASER_TEX := preload("res://Assets/Sprites/Skills/drone_laser.png")
const LASER_TEX_SCALE: float = 0.089   # 原贴图 384px → 视觉约 34px 长光束（比原程序块稍长，更像激光）
const BOOK_DISP_PX: float = 52.0        # 悬浮魔法书显示尺寸
const STAR_BASE_SCALE: float = 0.06     # 1★星形子弹缩放（原图已升到384px，÷3 回到≈23px 视觉）
const STAR_SCALE_PER_STAR: float = 0.0167 # 每升一星星形子弹变大（5★≈55px）
const STAR_SPIN: float = 7.0            # 星形子弹自旋角速度(rad/s)，飞行中持续旋转
const BOOK_HOMING_START: float = 22.5  # 星星先直线飞出此距离后，才开始追踪附近敌人（再缩一半，更早拐弯）
const FIREBOMB_BASE_SCALE: float = 0.12 # 燃烧瓶初始体积（调小）
const FIREBOMB_SCALE_PER_STAR: float = 0.03
const FIREBOMB_RING_RADIUS: float = 150.0  # 燃烧瓶落点距玩家的半径：星瓶均匀环绕一圈，5★ 在玩家四周构成燃烧圈
const BASKETBALL_BASE_SCALE: float = 0.11 # 篮球初始体积（调小）
const BASKETBALL_SCALE_PER_STAR: float = 0.03
const BASKETBALL_ARENA_RADIUS: float = 192.0  # 巧乐兹"圆形竞技场"半径：以玩家为圆心，球在圈内弹来弹去（原240的0.8倍）

# —— 射箭（游侠）—— 箭源图 384×216，目标游戏内约 60~80px
const BOW_BASE_SCALE: float = 0.16
const BOW_SCALE_PER_STAR: float = 0.02
# —— 拳击（壮汉，近战）——
const PUNCH_RANGE: float = 100.0
const PUNCH_ARC: float = 0.30        # 前向弧余弦阈值（dot>0.30 视为前方）
const PUNCH_KNOCKBACK: float = 280.0
# —— 魔法电击（学者，单体）——
const LIGHTNING_RANGE: float = 440.0
const BOLT_BASE_WIDTH: float = 4.0

var _player: Node2D = null
var _drone_sprite: Sprite2D = null   # 单架无人机精灵（环绕玩家，向最近敌人扇形散射激光）
var _book_sprite: Sprite2D = null
var _fire_timer: float = 0.0
var _pistol_flash_angle: float = 0.0     # 特工闪现手枪：当前绕玩家的角度
var _bow_burst: int = 0          # 射箭连射：剩余待发的箭数
var _bow_subtimer: float = 0.0   # 连射相邻两根箭的间隔计时
var _bow_burst_dmg: float = 0.0  # 本轮连射单箭伤害
var _orbit_angle: float = 0.0
var _book_orbit: float = PI            # 魔法书起始角度（与无人机错位）
var _laser_tex: Texture2D = null

# —— 终极技能：可选专属贴图（放入 Assets/Sprites/Ultimate/ 对应文件自动启用；缺失则回退现有贴图/程序生成）——
var _tex_exec_bomb: Texture2D = null   # 双枪绝杀：绝杀爆弹弹体
var _tex_blast: Texture2D = null       # 通用爆炸（绝杀弹爆炸）
var _tex_big_arrow: Texture2D = null   # 万箭齐发：天降巨箭
var _tex_target_ring: Texture2D = null # 万箭齐发：落点预警环
var _tex_arrow_splash: Texture2D = null# 万箭齐发：落地溅射
var _tex_shock_ring: Texture2D = null  # 毁灭重拳：冲击波环
var _tex_big_fist: Texture2D = null    # 毁灭重拳：巨拳
var _tex_sky_strike: Texture2D = null  # 连锁雷暴：天降落雷光柱
var _tex_strike_ring: Texture2D = null # 连锁雷暴：落点冲击环
var _tex_arc: Texture2D = null         # 连锁雷暴：电弧
var _ring_fallback: Texture2D = null   # 程序生成的圆环贴图（冲击波/落点环回退）
var _exec_count: int = 0              # 双枪绝杀：绝杀爆弹周期计数

func _ready() -> void:
	_player = get_parent()
	# 无人机：多架无人机精灵在 _physics_process 中按星级动态创建（每星一架）
	if skill_id == "active_drone":
		_drone_sprite = Sprite2D.new()
		_drone_sprite.texture = DRONE_TEX
		var s: float = DRONE_DISP_PX / max(1.0, float(DRONE_TEX.get_width()))
		_drone_sprite.scale = Vector2(s, s)
		add_child(_drone_sprite)
		_laser_tex = LASER_TEX
	# 魔法书：创建一个可见的魔法书实体悬浮在玩家周围
	elif skill_id == "active_book":
		_book_sprite = Sprite2D.new()
		_book_sprite.texture = BOOK_TEX
		var s: float = BOOK_DISP_PX / max(1.0, float(BOOK_TEX.get_width()))
		_book_sprite.scale = Vector2(s, s)
		add_child(_book_sprite)
	elif skill_id == "active_pistol" or skill_id == "super_pistol":
		PISTOL_TEX = _tex_or(PISTOL_TEX_PATH, _tex_or(PISTOL_DIR + "pistol.png", _make_pistol_texture()))
		PISTOL_TEX_2 = _tex_or(PISTOL_ALT_PATH, PISTOL_TEX)   # 第二把枪；缺省回退到第一把
	# 终极技能：加载可选专属贴图（缺失自动回退），并生成程序圆环用于冲击波/落点环
	if skill_id.begins_with("super_"):
		_ring_fallback = _make_ring_texture()
		_load_ultimate_textures()
	# 控制器锚定在玩家原点：飞镖/篮球/燃烧瓶即从此（玩家身上）发射
	position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if _player == null or _player.is_queued_for_deletion():
		return
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		return
	match skill_id:
		"active_pistol":
			_fire_timer -= delta
			var interval: float = max(0.08, 0.42 - 0.075 * st)   # 星级越高，闪现越快
			if _fire_timer <= 0.0:
				_fire_pistol(st)
				_fire_timer = interval
		"active_drone":
			_orbit_angle += delta * ORBIT_SPEED
			position = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * ORBIT_RADIUS
			_fire_timer -= delta
			var interval: float = max(0.25, 0.70 - 0.08 * st)
			if _fire_timer <= 0.0:
				_fire_drone_shot(st)
				_fire_timer = interval
		"active_book":
			_book_orbit += delta * BOOK_ORBIT_SPEED
			position = Vector2(cos(_book_orbit), sin(_book_orbit)) * BOOK_ORBIT_RADIUS
			_fire_timer -= delta
			var bk_interval: float = max(0.3, 0.7 - 0.07 * st)
			if _fire_timer <= 0.0:
				_fire_book(st)
				_fire_timer = bk_interval
		"active_firebomb":
			_fire_timer -= delta
			var fb_interval: float = max(0.9, 1.8 - 0.15 * st)   # 投掷间隔 ×1.5（用户要求）
			if _fire_timer <= 0.0:
				_fire_firebomb(st)
				_fire_timer = fb_interval
		"active_basketball":
			_fire_timer -= delta
			var bb_interval: float = max(0.5, 1.0 - 0.08 * st)
			if _fire_timer <= 0.0:
				_fire_basketball(st)
				_fire_timer = bb_interval
		# —— 游侠：射箭（逐根连射，非并列；箭有限穿透并卡入最后命中的敌人）——
		"active_bow":
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_bow_burst = st                 # 一轮连射 st 根箭（按星级）
				_bow_subtimer = 0.0
				_bow_burst_dmg = 1.2 + 0.7 * st
				_fire_timer = max(0.30, 0.60 - 0.05 * st)   # 整轮冷却
			if _bow_burst > 0:
				_bow_subtimer -= delta
				if _bow_subtimer <= 0.0:
					var tgt: Node2D = _nearest_enemy(99999.0)
					_spawn_arrow(_bow_burst_dmg, st, false, tgt)
					_bow_burst -= 1
					_bow_subtimer = 0.14         # 相邻两根箭的间隔（一根跟一根）
		# —— 壮汉：拳击（近身前向弧判定，击退）——
		"active_punch":
			_fire_timer -= delta
			var pn_interval: float = max(0.35, 0.70 - 0.06 * st)
			if _fire_timer <= 0.0:
				_fire_punch(st)
				_fire_timer = pn_interval
		# —— 学者：魔法电击（锁定最近敌人，单体射线）——
		"active_lightning":
			_fire_timer -= delta
			var lt_interval: float = max(0.50, 1.0 - 0.08 * st)
			if _fire_timer <= 0.0:
				_fire_lightning(st)
				_fire_timer = lt_interval
		# —— 进化体（满星+专属被动后由升级卡授予）——
		"super_bow":
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_super_bow(st)
				_fire_timer = max(0.22, 0.45 - 0.04 * st)
		"super_punch":
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_super_punch(st)
				_fire_timer = max(0.30, 0.55 - 0.05 * st)
		"super_lightning":
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_super_lightning(st)
				_fire_timer = max(0.40, 0.80 - 0.06 * st)
		"super_pistol":
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_super_pistol(st)
				_fire_timer = max(0.07, 0.16 - 0.018 * st)   # 双枪弹幕流：开火极快

func _aim_dir() -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_d: float = 99999.0
	for e in enemies:
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null:
		return (best.global_position - global_position).normalized()
	return Vector2(0.0, 1.0)

# 在指定原点生成一把手枪子弹（直线飞行，不追踪）
func _spawn_pistol(dir: Vector2, dmg: float, st: int, origin: Vector2 = Vector2.ZERO) -> void:
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	p.direction = dir
	p.speed = 1120.0
	p.damage = dmg
	p.max_lifetime = 2.5
	p.tex = BULLET_TEX
	p.tex_scale = BULLET_BASE_SCALE + BULLET_SCALE_PER_STAR * st
	p.homing = 0.0                # 特工手枪弹：纯直线，不追踪（与另外三角色一致）
	p.homing_range = 0.0
	p.pierce = 0                  # 手枪子弹不穿透：命中第一个敌人即销毁，仅结算一次伤害
	p.hit_radius = 384.0 * p.tex_scale * 0.32   # 命中判定半径随视觉同步放大（约视觉宽 64%，略小于视觉，公平）
	p.visual_rotation_offset = 0.0
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = origin if origin != Vector2.ZERO else global_position

# 生成一个激光弹体（高速、青色、长轴朝向飞行方向，区别于通用子弹）
func _spawn_laser(dir: Vector2, dmg: float, origin: Vector2 = Vector2.ZERO) -> void:
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	p.direction = dir
	p.speed = 1440.0
	p.damage = dmg
	p.max_lifetime = 2.0
	p.tex = _laser_tex
	p.tex_scale = LASER_TEX_SCALE
	p.visual_rotation_offset = 0.0
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = origin if origin != Vector2.ZERO else global_position

# 特工：手枪在玩家四周"闪现"并射击；星级越高闪现越快（取消原"扇形多发"升级）
func _fire_pistol(st: int) -> void:
	var dmg: float = 1.0 + 0.8 * st
	_pistol_flash_angle += PISTOL_FLASH_STEP
	var offset := Vector2(cos(_pistol_flash_angle), sin(_pistol_flash_angle)) * PISTOL_FLASH_RADIUS
	var muzzle_pos: Vector2 = global_position + offset
	var dir: Vector2 = _aim_dir_from(muzzle_pos)
	_spawn_pistol_visual(muzzle_pos, dir, st)
	_spawn_muzzle_flash(muzzle_pos, dir)
	_spawn_pistol(dir, dmg, st, muzzle_pos)

# 在 pos 处闪现一把手枪（快速弹出 → 停留 → 淡出），枪口朝向发射方向
# tex 缺省用第一把枪；mirrored=true 表示该图原始朝向朝左，需要水平镜像后再旋转，使枪口朝右。
func _spawn_pistol_visual(pos: Vector2, dir: Vector2, st: int, tex: Texture2D = PISTOL_TEX, mirrored: bool = false) -> void:
	var world: Node = _player.get_parent()
	if world == null or tex == null or PISTOL_TEX == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	var disp: float
	if mirrored:
		# 按第一把枪的显示高度对齐，避免 384×384 正方图显得太胖
		var primary_h: float = PISTOL_DISP_PX * float(PISTOL_TEX.get_height()) / float(PISTOL_TEX.get_width())
		disp = primary_h / max(1.0, float(tex.get_height()))
	else:
		disp = PISTOL_DISP_PX / max(1.0, float(tex.get_width()))
	var target_scale: Vector2 = Vector2(-disp, disp) if mirrored else Vector2(disp, disp)
	s.scale = Vector2.ZERO
	s.global_position = pos
	if dir.length() > 0.001:
		s.rotation = dir.angle()
	s.z_index = 16
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", target_scale, 0.05)
	tw.tween_interval(0.05)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.08)
	tw.tween_callback(s.queue_free)

# 从指定位置找最近敌人方向（无敌人则朝下）
func _aim_dir_from(pos: Vector2) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_d: float = 99999.0
	for e in enemies:
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d: float = pos.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null:
		return (best.global_position - pos).normalized()
	return Vector2(0.0, 1.0)

# 在 pos 处闪现一束枪口火光（朝 dir），极短淡出，强化"枪"的视觉身份
func _spawn_muzzle_flash(pos: Vector2, dir: Vector2) -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	var s := Sprite2D.new()
	s.texture = MUZZLE_TEX
	s.scale = Vector2(0.5, 0.5)
	s.global_position = pos + dir * 14.0
	s.z_index = 17
	if dir.length() > 0.001:
		s.rotation = dir.angle()
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_interval(0.03)
	tw.tween_property(s, "scale", Vector2(0.7, 0.7), 0.04)
	tw.parallel().tween_property(s, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.09)
	tw.tween_callback(s.queue_free)

# 无人机：从悬浮的无人机处向最近敌人方向扇形散射一束激光（数量随星级递增）。
func _fire_drone_shot(st: int) -> void:
	var count: int = st
	var dmg: float = 1.0 + 0.5 * st
	_fire_cone(count, dmg, _spawn_laser)

# 通用：在 aim 方向两侧展开一个锥形，依次生成 count 发弹体（spawn 回调决定弹种）。
func _fire_cone(count: int, dmg: float, spawn: Callable, spread: float = 0.16) -> void:
	var base: Vector2 = _aim_dir()
	for i in count:
		var a: float = base.angle() + (float(i) - float(count - 1) / 2.0) * spread
		spawn.call(Vector2(cos(a), sin(a)), dmg)

# —— 魔法书：悬浮在玩家周围，星星初始朝四周（均匀 360°）射出（自旋），飞出一段距离后各自追踪附近敌人 ——
# 数量随星级：1★=1 发，每升一星 +1 发；星形子弹随星级变大、伤害变高、自旋。
# 设计：先向四周均匀方向抛出一束星星，飞行 BOOK_HOMING_START 距离后开启 homing，由弹体自行转向并贴向附近敌人，
# 呈现"向四周散射 → 飞出再寻的"的手感。
func _fire_book(st: int) -> void:
	var count: int = st
	var dmg: float = 1.0 + 0.7 * st
	# 星星初始朝四周（均匀 360° 圆周）射出，飞出 BOOK_HOMING_START 距离后各自追踪附近敌人
	for i in count:
		var a: float = TAU * float(i) / float(count)
		_spawn_book_star(Vector2(cos(a), sin(a)), dmg, st)

func _spawn_book_star(dir: Vector2, dmg: float, st: int) -> void:
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	p.direction = dir
	p.speed = 520.0
	p.damage = dmg
	p.max_lifetime = 2.5
	p.tex = STAR_TEX
	p.tex_scale = STAR_BASE_SCALE + STAR_SCALE_PER_STAR * st
	p.self_spin = STAR_SPIN     # 星星自旋
	p.homing = 60.0              # 追踪转向角速度极高，飞出 BOOK_HOMING_START 后近乎瞬间拐向敌人（瞬转）
	p.homing_range = 450.0
	p.homing_start_dist = BOOK_HOMING_START   # 先直线飞出一段再追踪，避免一出生就径直奔敌
	p.pierce = 2 + st            # 穿透：星形子弹可贯穿多个敌人，每个敌人仅结算一次伤害
	p.hit_radius = 384.0 * p.tex_scale * 0.32   # 命中判定半径随视觉同步放大（与手枪同公式）
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = global_position

# 燃烧瓶：星瓶按"360° 均匀环绕玩家"抛出（1★=1 瓶…5★=5 瓶），每瓶旋转飞行、途中体积渐增，
# 飞抵距玩家 FIREBOMB_RING_RADIUS 处落地生成持续火焰区（DOT）。
# 因落点均匀环绕，5★ 时五瓶在玩家四周构成一圈燃烧圈。
func _fire_firebomb(st: int) -> void:
	var count: int = st
	var base_phase: float = randf() * TAU   # 每次投掷整体随机旋转一个相位，避免永远对齐坐标轴
	for i in count:
		var a: float = base_phase + float(i) * TAU / float(count)
		_spawn_firebomb(Vector2(cos(a), sin(a)), 0.0, st)

func _spawn_firebomb(dir: Vector2, dmg: float, st: int) -> void:
	var s: float = FIREBOMB_BASE_SCALE + FIREBOMB_SCALE_PER_STAR * st
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	p.direction = dir
	p.speed = 840.0
	p.damage = 0.0                 # 伤害全部来自落地后的火焰区（入圈持续伤害）
	p.max_lifetime = 2.0
	p.tex = FIREBOMB_TEX
	p.tex_scale = s
	p.self_spin = 12.0             # 旋转丢出
	p.grow_over_life = true        # 飞行中体积逐渐增大
	p.grow_from = s
	p.grow_to = s * 1.9
	p.max_distance = FIREBOMB_RING_RADIUS   # 落点距玩家固定半径：环绕一圈，5★ 构成燃烧圈
	p.fire_on_impact = true
	p.fire_radius = 55.0 + 8.0 * st
	p.fire_duration = 2.0 + 0.4 * st
	p.fire_tick = 0.4
	p.fire_damage = 0.6 + 0.4 * st
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = global_position

# 巧乐兹：朝最近敌人发射一颗弹跳巧乐兹，在场景里来回弹、反复碾压敌群。
# 每星 +伤害 +体积 +弹跳速度 +存活时间。
func _fire_basketball(st: int) -> void:
	var dmg: float = 1.2 + 0.6 * st
	_spawn_basketball(_aim_dir(), dmg, st)

func _spawn_basketball(dir: Vector2, dmg: float, st: int) -> void:
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	p.direction = dir
	p.speed = 600.0 + 40.0 * st
	p.damage = dmg
	p.max_lifetime = 2.5 + 0.4 * st
	p.tex = BASKETBALL_TEX
	p.tex_scale = BASKETBALL_BASE_SCALE + BASKETBALL_SCALE_PER_STAR * st
	p.bounce = true
	p.arena_bounce = true              # 改为：在以玩家为圆心、BASKETBALL_ARENA_RADIUS 的圆内弹跳
	p.arena_radius = BASKETBALL_ARENA_RADIUS
	p.max_bounces = 0                  # 不再因弹射次数消失，只受寿命限制（圆内持续撞来撞去）
	p.self_spin = 9.0
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = global_position

# ===================== 游侠：射箭 =====================
# 生成一支箭：默认走抛物线弹道（ballistic）飞向 target 敌人——弧线明显且保证命中，与"直线子弹"形成强区分；
# target 为 null 时退回直线弹道。super 版更快、穿透更强。end_offset 用于进化体扇形展开。
func _spawn_arrow(dmg: float, st: int, is_super: bool, target: Node2D, end_offset: Vector2 = Vector2.ZERO) -> void:
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	var dir: Vector2 = _aim_dir()
	p.direction = dir
	p.speed = 1280.0 + (280.0 if is_super else 0.0)
	p.damage = dmg
	p.max_lifetime = 2.5
	p.tex = BOW_ARROW_TEX
	p.tex_scale = BOW_BASE_SCALE + BOW_SCALE_PER_STAR * st
	p.homing = 0.0
	p.homing_range = 0.0
	p.pierce = st + (3 if is_super else 0)   # 有限穿透：星级=可穿透敌人数（super 更强）
	p.sticky = false                         # 抛物线弹道下不再卡入敌人（会与弧线冲突），途中可穿透多个敌人
	p.hit_radius = 12.0             # 箭视觉约 45~60px，命中半径给到 12 避免"穿过敌人不命中"
	p.visual_rotation_offset = 0.0   # 箭贴图指向 +X，straight_projectile 旋到飞行方向
	p.ballistic_jitter = 2.8        # 飞行过程轻微抖动，模拟箭矢飘动（已减至 0.7 倍）
	if target != null and is_instance_valid(target):
		p.ballistic = true
		p._ball_start = global_position
		p._ball_target = target
		p._ball_end = target.global_position + end_offset
		var dist: float = global_position.distance_to(p._ball_end)
		p._ball_dur = clampf(dist / p.speed, 0.35, 0.9)
		p._ball_arc = clampf(dist * 0.28, 45.0, 170.0)
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = global_position

# ===================== 壮汉：拳击（近战） =====================
# 拳击（近战）：在前向弧内对敌人结算伤害（敌人 take_damage 仅接伤害值），并播放拳影
func _fire_punch(st: int) -> void:
	var facing: Vector2 = _aim_dir()
	var dmg: float = 2.0 + 1.0 * st
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > PUNCH_RANGE:
			continue
		if facing.dot(to.normalized()) < PUNCH_ARC:
			continue
		e.take_damage(dmg)
	_show_fist(global_position + facing * PUNCH_RANGE * 0.55, facing, false)

# 在 pos 处闪现一帧拳影（big=true 用于进化重拳，更大）
func _show_fist(pos: Vector2, facing: Vector2 = Vector2.RIGHT, big: bool = false) -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	var s := Sprite2D.new()
	s.texture = FIST_TEX
	# 目标显示尺寸：普通重拳 ~90px，进化重拳 ~130px（按源图宽度等比缩放）
	var target_px: float = 130.0 if big else 90.0
	var base: float = target_px / max(1.0, float(FIST_TEX.get_width()))
	s.scale = Vector2(base, base)
	s.global_position = pos
	s.z_index = 18
	# 让拳影朝向攻击方向（圆形素材无影响，但给方向性拳影素材预留正确方向）
	if facing.length() > 0.001:
		s.rotation = facing.angle()
	world.add_child(s)
	var tw := get_tree().create_tween()
	# 先短暂 solid 显示（看清素材），再缩放+淡出消失
	tw.tween_interval(0.06)
	tw.tween_property(s, "scale", Vector2(base * 1.15, base * 1.15), 0.06)
	tw.parallel().tween_property(s, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.16)
	tw.tween_callback(s.queue_free)

# ===================== 学者：魔法电击（单体） =====================
# 返回射程内最近的存活敌人（无则 null）
func _nearest_enemy(range_limit: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = range_limit
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

# 魔法电击（多体）：锁定射程内最近的 st 个敌人，各落一道魔法射线并结算伤害（每升一星+1 目标）
func _fire_lightning(st: int) -> void:
	var targets := _nearest_enemies(LIGHTNING_RANGE, st)
	if targets.is_empty():
		return
	var dmg: float = 2.5 + 1.2 * st
	for t in targets:
		t.take_damage(dmg)
		_show_beam(global_position, t.global_position, BOLT_BASE_WIDTH + float(st), Color(0.6, 0.9, 1.0))

# 返回射程内最近的 count 个存活敌人（按距离升序），不足则返回全部
func _nearest_enemies(range_limit: float, count: int) -> Array:
	var list: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= range_limit:
			list.append({"e": e, "d": d})
	list.sort_custom(func(a, b): return a["d"] < b["d"])
	var out: Array = []
	for i in min(count, list.size()):
		out.append(list[i]["e"])
	return out

# 在世界空间画一条从 a 到 b 的魔法射线：bolt.png 为完整光束（星芒端朝 a，尖端朝 b），直接拉伸到距离并旋转
func _show_beam(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	var dist: float = a.distance_to(b)
	if dist < 2.0:
		return
	var ang: float = (b - a).angle()
	var s := Sprite2D.new()
	s.texture = BOLT_TEX
	s.rotation = ang
	var thickness: float = max(width * 4.0, 24.0)
	s.scale = Vector2(dist / float(BOLT_TEX.get_width()), thickness / float(BOLT_TEX.get_height()))
	s.global_position = (a + b) * 0.5
	s.z_index = 18
	s.modulate = col
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", Vector2(s.scale.x, s.scale.y * 1.15), 0.06)
	tw.parallel().tween_property(s, "modulate", Color(col.r, col.g, col.b, 0.0), 0.25)
	tw.tween_callback(s.queue_free)

# =====================================================================
# ===================== 终极技能（四形态） =============================
# 四个专属终极：形态与玩法各不相同，凸显"酷炫 / 高伤害 / 大体积"。
# =====================================================================

const ULT_DIR := "res://Assets/Sprites/Ultimate/"

# 若指定路径存在则加载该贴图，否则回退到 fallback（保证缺素材也能跑）
func _tex_or(path: String, fallback: Texture2D) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t != null:
			return t
	return fallback

func _load_ultimate_textures() -> void:
	var fx_fire: Texture2D = preload("res://Assets/Sprites/Effects/fire_effect.png")
	var fx_hit: Texture2D = preload("res://Assets/Sprites/Effects/hit.png")
	_tex_exec_bomb    = _tex_or(ULT_DIR + "blast/execution_bomb.png", BULLET_TEX)
	_tex_blast        = _tex_or(ULT_DIR + "blast/blast.png", fx_fire)
	_tex_big_arrow    = _tex_or(ULT_DIR + "rain/big_arrow.png", BOW_ARROW_TEX)
	_tex_target_ring  = _tex_or(ULT_DIR + "rain/target_ring.png", _ring_fallback)
	_tex_arrow_splash = _tex_or(ULT_DIR + "rain/arrow_splash.png", fx_hit)
	_tex_shock_ring   = _tex_or(ULT_DIR + "shockwave/shockwave_ring.png", _ring_fallback)
	_tex_big_fist     = _tex_or(ULT_DIR + "shockwave/big_fist.png", FIST_TEX)
	_tex_sky_strike   = _tex_or(ULT_DIR + "thunder/strike.png", BOLT_TEX)
	_tex_strike_ring  = _tex_or(ULT_DIR + "thunder/strike_ring.png", _ring_fallback)
	_tex_arc          = _tex_or(ULT_DIR + "thunder/arc.png", BOLT_TEX)

# 程序生成一张"圆环"贴图（透明中心 + 羽化亮边），用于冲击波/落点环的零素材回退
func _make_ring_texture() -> Texture2D:
	var size: int = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = float(size) * 0.5
	var outer: float = c - 2.0
	var inner: float = c - 16.0
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - c, float(y) - c).length()
			if d <= outer and d >= inner:
				var a: float = clampf((outer - d) / 3.0, 0.0, 1.0) * clampf((d - inner) / 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# 程序生成一把手枪剪影贴图（枪口朝 +X），用于闪现手枪的零素材回退；可放 pistol.png 覆盖
func _make_pistol_texture() -> Texture2D:
	var size: int = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.90, 0.92, 0.97, 1.0)
	var dark := Color(0.55, 0.58, 0.66, 1.0)
	img.fill_rect(Rect2(26, 50, 78, 16), col)   # 套筒/枪管（指向 +X）
	img.fill_rect(Rect2(98, 53, 14, 10), col)   # 枪口
	img.fill_rect(Rect2(40, 66, 22, 36), col)   # 握把
	img.fill_rect(Rect2(34, 60, 16, 14), col)   # 连接处
	img.fill_rect(Rect2(46, 66, 10, 8), dark)   # 扳机护圈暗示
	return ImageTexture.create_from_image(img)

# 通用：对 center 半径 radius 内所有存活敌人结算伤害，可附带击退
func _aoe_burst(center: Vector2, radius: float, dmg: float, knockback: float = 0.0) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if center.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			if knockback > 0.0 and e.has_method("apply_knockback"):
				e.apply_knockback(center, knockback)

# 敌群中心：取最近敌人位置；无敌人时取瞄准方向前方一段
func _cluster_center() -> Vector2:
	var tgt: Node2D = _nearest_enemy(99999.0)
	if tgt != null:
		return tgt.global_position
	return global_position + _aim_dir() * 280.0

# 通用圆环/圆盘视觉：grow=true 从小扩张（冲击波/溅射）；grow=false 定住后淡出（落点标记）
func _show_ring(pos: Vector2, ring_tex: Texture2D, target_diameter: float, col: Color, grow: bool, dur: float, z: int = 16) -> void:
	var world: Node = _player.get_parent()
	if world == null or ring_tex == null:
		return
	var s := Sprite2D.new()
	s.texture = ring_tex
	s.global_position = pos
	s.z_index = z
	s.modulate = col
	var full: float = target_diameter / max(1.0, float(ring_tex.get_width()))
	world.add_child(s)
	var tw := get_tree().create_tween()
	if grow:
		s.scale = Vector2(full * 0.15, full * 0.15)
		tw.tween_property(s, "scale", Vector2(full, full), dur).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate", Color(col.r, col.g, col.b, 0.0), dur)
	else:
		s.scale = Vector2(full, full)
		tw.tween_interval(dur * 0.5)
		tw.tween_property(s, "modulate", Color(col.r, col.g, col.b, 0.0), dur * 0.5)
	tw.tween_callback(s.queue_free)

# 通用光束（指定贴图版）：从 a 到 b 拉伸旋转，短暂淡出（落雷/电弧）
func _show_strike_beam(a: Vector2, b: Vector2, width: float, beam_tex: Texture2D, col: Color) -> void:
	var world: Node = _player.get_parent()
	if world == null or beam_tex == null:
		return
	var dist: float = a.distance_to(b)
	if dist < 2.0:
		return
	var s := Sprite2D.new()
	s.texture = beam_tex
	s.rotation = (b - a).angle()
	var thickness: float = max(width * 4.0, 28.0)
	s.scale = Vector2(dist / float(beam_tex.get_width()), thickness / float(beam_tex.get_height()))
	s.global_position = (a + b) * 0.5
	s.z_index = 20
	s.modulate = col
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", Vector2(s.scale.x, s.scale.y * 1.2), 0.06)
	tw.parallel().tween_property(s, "modulate", Color(col.r, col.g, col.b, 0.0), 0.25)
	tw.tween_callback(s.queue_free)

# 通用纵向光束：贴图为竖向（高=长度轴，宽=粗细轴），用于天空落雷光柱（strike.png 为 64×512 竖柱）
func _show_vertical_beam(top: Vector2, bottom: Vector2, thickness: float, beam_tex: Texture2D, col: Color) -> void:
	var world: Node = _player.get_parent()
	if world == null or beam_tex == null:
		return
	var dist: float = top.distance_to(bottom)
	if dist < 2.0:
		return
	var s := Sprite2D.new()
	s.texture = beam_tex
	s.global_position = (top + bottom) * 0.5
	s.z_index = 20
	s.modulate = col
	s.scale = Vector2(thickness / float(beam_tex.get_width()), dist / float(beam_tex.get_height()))
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", Vector2(s.scale.x * 0.7, s.scale.y), 0.06)
	tw.parallel().tween_property(s, "modulate", Color(col.r, col.g, col.b, 0.0), 0.3)
	tw.tween_callback(s.queue_free)

# ---------------------------------------------------------------------
# 终极·双枪绝杀（特工）：双管交替狂射弹幕，每 5 次开火射出一枚命中爆炸的绝杀弹
# ---------------------------------------------------------------------
func _fire_super_pistol(st: int) -> void:
	var aim: Vector2 = _aim_dir()
	var perp: Vector2 = Vector2(-aim.y, aim.x)
	var spread: float = 22.0
	var muzzle_l: Vector2 = global_position + perp * spread   # 左枪（第一把）
	var muzzle_r: Vector2 = global_position - perp * spread   # 右枪（第二把）
	# 两把枪同时闪现：左枪=第一把图标(朝右)，右枪=第二把图标(原始朝左，需镜像)
	_spawn_pistol_visual(muzzle_l, aim, st, PISTOL_TEX)
	_spawn_pistol_visual(muzzle_r, aim, st, PISTOL_TEX_2, true)
	_spawn_muzzle_flash(muzzle_l, aim)
	_spawn_muzzle_flash(muzzle_r, aim)
	# 双枪齐射：每把各发一发黄子弹，形成密集弹幕
	var dmg: float = 1.6 + 1.0 * float(st)
	_spawn_super_pistol_bullet(aim, dmg, st, muzzle_l, false)
	_spawn_super_pistol_bullet(aim, dmg, st, muzzle_r, false)
	# 周期绝杀爆弹：更大、伤害更高、命中范围爆炸并击退
	_exec_count += 1
	if _exec_count % 5 == 0:
		_spawn_super_pistol_bullet(aim, 3.0 + 2.0 * float(st), st, global_position, true)

func _spawn_super_pistol_bullet(dir: Vector2, dmg: float, st: int, origin: Vector2, is_bomb: bool) -> void:
	var p := Area2D.new()
	p.set_script(PROJ_SCRIPT)
	p.direction = dir
	p.damage = dmg
	p.max_lifetime = 2.5
	p.homing = 0.0                # 终极·双枪绝杀：特工仍是直线射手，绝杀弹不追踪
	p.homing_range = 0.0
	p.visual_rotation_offset = 0.0
	if is_bomb:
		p.speed = 1040.0
		p.tex = _tex_exec_bomb
		p.tex_scale = (BULLET_BASE_SCALE + BULLET_SCALE_PER_STAR * st) * 2.4
		p.pierce = 0
		p.hit_radius = 24.0
		p.aoe_on_hit = true
		p.aoe_radius = 120.0 + 10.0 * float(st)
		p.aoe_damage = 3.0 + 2.0 * float(st)
		p.aoe_knockback = 160.0
		p.aoe_tex = _tex_blast
		p.aoe_color = Color(1.0, 0.55, 0.2, 0.95)
	else:
		p.speed = 1560.0
		p.tex = BULLET_TEX
		p.tex_scale = BULLET_BASE_SCALE + BULLET_SCALE_PER_STAR * st
		p.pierce = 2 + st
		p.hit_radius = 384.0 * p.tex_scale * 0.32
	var world: Node = _player.get_parent()
	if world == null:
		return
	world.add_child(p)
	p.global_position = origin

# ---------------------------------------------------------------------
# 终极·万箭齐发（游侠）：锁定敌群，10~14 支巨箭同时从天而降覆盖圆形区域，落地范围溅射
# ---------------------------------------------------------------------
func _fire_super_bow(st: int) -> void:
	var count: int = 9 + st                     # 5★≈14 支
	var center: Vector2 = _cluster_center()
	var dmg: float = 1.8 + 1.0 * float(st)
	var spread: float = 150.0 + 14.0 * float(st)
	for i in count:
		var ang: float = randf() * TAU
		var rad: float = sqrt(randf()) * spread   # 圆内均匀分布
		var tp: Vector2 = center + Vector2(cos(ang), sin(ang)) * rad
		var delay: float = randf() * 0.45          # 错落而下，营造箭雨
		get_tree().create_timer(delay).timeout.connect(_drop_arrow.bind(tp, dmg, st))

func _drop_arrow(tp: Vector2, dmg: float, st: int) -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	# 落点预警环
	_show_ring(tp, _tex_target_ring, 74.0, Color(0.95, 0.85, 0.4, 0.85), false, 0.4)
	# 巨箭从空中俯冲落下
	var arrow := Sprite2D.new()
	arrow.texture = _tex_big_arrow
	var sc: float = (BOW_BASE_SCALE + BOW_SCALE_PER_STAR * st) * 1.8
	arrow.scale = Vector2(sc, sc)
	arrow.rotation = 0.0                         # 箭矢贴图本身已朝下，直接俯冲
	arrow.z_index = 21
	arrow.global_position = tp + Vector2(0.0, -480.0)
	world.add_child(arrow)
	var tw := get_tree().create_tween()
	tw.tween_property(arrow, "global_position", tp, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_arrow_land.bind(arrow, tp, dmg, st))

func _arrow_land(arrow: Sprite2D, tp: Vector2, dmg: float, st: int) -> void:
	_aoe_burst(tp, 60.0 + 6.0 * float(st), dmg)
	_show_ring(tp, _tex_arrow_splash, 120.0 + 12.0 * float(st), Color(1.0, 0.9, 0.5, 0.95), true, 0.22)
	if is_instance_valid(arrow):
		arrow.queue_free()

# ---------------------------------------------------------------------
# 终极·毁灭重拳（壮汉）：巨拳砸地爆发环形冲击波，以自身为中心全向击退敌群
# ---------------------------------------------------------------------
func _fire_super_punch(st: int) -> void:
	var radius: float = 150.0 + 30.0 * float(st)     # 5★=300px 冲击波半径
	var dmg: float = 4.0 + 2.0 * float(st)
	var kb: float = 340.0 + 40.0 * float(st)         # 全向击退力度
	_aoe_burst(global_position, radius, dmg, kb)
	# 扩张的冲击波环（置于壮汉身后，不遮挡）
	_show_ring(global_position, _tex_shock_ring, radius * 2.0, Color(1.0, 0.8, 0.4, 0.95), true, 0.32, -1)
	# 巨拳砸地（置于壮汉身后）
	_show_big_fist(global_position, -1)

func _show_big_fist(pos: Vector2, z: int = 22) -> void:
	var world: Node = _player.get_parent()
	if world == null or _tex_big_fist == null:
		return
	var s := Sprite2D.new()
	s.texture = _tex_big_fist
	var base: float = 180.0 / max(1.0, float(_tex_big_fist.get_width()))
	s.scale = Vector2(base * 1.4, base * 1.4)
	s.global_position = pos
	s.z_index = z
	s.modulate = Color(1, 1, 1, 0)
	world.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "modulate", Color(1, 1, 1, 1), 0.05)
	tw.parallel().tween_property(s, "scale", Vector2(base, base), 0.10)
	tw.tween_property(s, "modulate", Color(1, 1, 1, 0), 0.14)
	tw.tween_callback(s.queue_free)

# ---------------------------------------------------------------------
# 终极·连锁雷暴（学者）：天空同时降下多道落雷范围轰击，并以电弧在被击敌人间连锁蔓延
# ---------------------------------------------------------------------
func _fire_super_lightning(st: int) -> void:
	var targets := _nearest_enemies(LIGHTNING_RANGE * 1.5, 4 + st)   # 5★=9 道落雷
	if targets.is_empty():
		return
	var dmg: float = 4.5 + 2.0 * float(st)
	var chain_dmg: float = dmg * 0.5
	var prev: Vector2 = Vector2.ZERO
	var has_prev: bool = false
	var chained: Array = []                       # 已受击/已连锁的敌人，避免重复结算
	for t in targets:
		if not (t is Node2D) or not is_instance_valid(t):
			continue
		var pos: Vector2 = t.global_position
		_sky_strike(pos, st)
		_aoe_burst(pos, 95.0 + 8.0 * float(st), dmg)   # 落点范围伤害提升
		chained.append(t)
		# 次级连锁：向落点附近尚未被直接命中的敌人迸射电弧，造成半额伤害（连锁蔓延）
		var chain_radius: float = 155.0 + 12.0 * float(st)
		var hops: int = 2 + int(st / 2)              # 高星级连锁更多目标
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D) or not is_instance_valid(e) or e in chained:
				continue
			if e.has_method("is_dead") and e.is_dead():
				continue
			if pos.distance_to(e.global_position) > chain_radius:
				continue
			_show_strike_beam(pos, e.global_position, BOLT_BASE_WIDTH + float(st), _tex_arc, Color(0.85, 0.95, 1.0))
			if e.has_method("take_damage"):
				e.take_damage(chain_dmg)
			chained.append(e)
			hops -= 1
			if hops <= 0:
				break
		# 落雷之间的主电弧串联
		if has_prev:
			_show_strike_beam(prev, pos, BOLT_BASE_WIDTH + float(st), _tex_arc, Color(0.8, 0.95, 1.0))
		prev = pos
		has_prev = true

func _sky_strike(pos: Vector2, st: int) -> void:
	# 天雷光柱：从落点正上方劈下（竖向贴图，宽为粗细、高为长度）
	var top: Vector2 = pos + Vector2(0.0, -520.0)
	_show_vertical_beam(top, pos, 42.0 + 5.0 * float(st), _tex_sky_strike, Color(0.9, 0.96, 1.0))
	# 落点冲击环
	_show_ring(pos, _tex_strike_ring, 110.0 + 10.0 * float(st), Color(0.75, 0.9, 1.0, 0.9), true, 0.26)
