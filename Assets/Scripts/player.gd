extends CharacterBody2D

@export var speed: float = 440.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.45        # 两发子弹最小间隔（秒）
@export var bullet_speed: float = 960.0
@export var auto_fire: bool = true         # 有目标时自动开火
@export var muzzle_offset: float = 26.0    # 子弹生成位置相对人物的偏移
@export var aim_radius: float = 400.0      # 发射时以玩家为圆心的锁敌半径
@export var bullet_damage: float = 1.0     # 单发子弹伤害（可升级）
@export var magnet_radius: float = 140.0   # 拾取吸附半径（可升级）
@export var max_hp: float = 15.0            # 玩家生命值
@export var hp_bar_width: float = 48.0     # 血条长度（满血时）
@export var hp_bar_y: float = -46.0        # 血条相对人物原点的纵向偏移（头顶上方）
@export var camera_zoom: float = 0.85      # 相机缩放（<1 = 拉远，视角更高更俯瞰）

signal leveled_up                     # 攒满经验触发升级（供升级 UI 监听）
signal died                            # 玩家死亡（供结算屏监听，不再直接重载场景）

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var facing: String = "toward"
var _fire_cooldown: float = 0.0
var _hp: float = 15.0
var _dead: bool = false
var shield_handler = null   # 守护圣盾节点注册于此；受击时先由它 absorb() 拦截
var _use_builtin_attack: bool = false   # 是否使用 player.gd 内置追踪子弹（仅特工为 true）

# 受击无敌帧 + 击退（来自 BOSS 近战/冲锋等重击）
var _invuln: float = 0.0
const INVULN_TIME: float = 0.5
var _kb_vel: Vector2 = Vector2.ZERO
var _stunned: bool = false
const KB_DECAY: float = 1800.0   # 击退速度衰减（像素/秒²）

# —— 经验 / 等级 ——
var _level: int = 1
var _exp: float = 0.0
var _exp_to_next: float = 5.0
var _pending_levels: int = 0
const _exp_base: float = 5.0
const _exp_growth: float = 1.3

# 被动影响的经验倍率（由 SkillManager.apply_passive 写入）
var xp_pickup_mult: float = 1.0   # 书籍：经验球价值
var xp_rate_mult: float = 1.0     # 股票：升级所需经验（越大越快升级）

# —— 宠物跟随视觉 ——
var _pet_node: Node2D = null
var _pet_side: float = -1.0       # 宠物相对角色的水平侧：-1=屏幕左，+1=屏幕右
var _pet_face_left: bool = false  # 宠物是否朝左（水平翻转）
var _pet_base: Vector2 = Vector2.ZERO   # 宠物缓动基准位置（脚边）
const _PET_FOOT_X: float = 18.0   # 角色左脚相对节点原点的水平偏移
const _PET_FOOT_Y: float = 28.0   # 角色脚部相对节点原点的垂直偏移（向下为正）
const _PET_WORLD_H: float = 32.0  # 宠物在战斗场景里的目标显示高度（像素）
const _PET_FOLLOW_LERP: float = 10.0   # 跟随缓动强度（越大越跟手）
const _PET_BOB_SPEED: float = 3.0      # 待机浮动角速度
const _PET_BOB_AMP: float = 3.0        # 待机浮动幅度（像素）
const _PET_BREATH_AMP: float = 0.06    # 呼吸缩放幅度（±6%）
const GEAR_ICON_DIR := "res://Assets/Sprites/UI/Gear/"


func _ready() -> void:
	_apply_character_skin()   # 按所选角色加载对应精灵图（缺失则保持流浪者外观）
	sprite.play("idle")
	camera.zoom = Vector2(camera_zoom, camera_zoom)   # 抬高视角：拉远相机，俯瞰感更强
	_setup_camera_limits()
	add_to_group("player")
	_hp = max_hp
	_exp_to_next = _next_threshold(_level) / xp_rate_mult
	queue_redraw()   # 初始化时绘制满血血条
	_apply_equipment_stats()   # 应用局外装备属性（在角色基础属性设置之后）

# 按所选角色加载独立外观：把角色 sheet 按 76×75 网格切成与流浪者一致的 5 段动画。
# sheet 文件不存在 / 尺寸不足则跳过，保留 tscn 默认的流浪者外观（绝不崩溃）。
func _apply_character_skin() -> void:
	if RunStats == null:
		return
	var def: Dictionary = RunStats.get_character_def()
	if def.is_empty() or not def.has("sheet"):
		return
	_use_builtin_attack = bool(def.get("builtin_attack", false))
	var path: String = def["sheet"]
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null or tex.get_width() < 228 or tex.get_height() < 300:
		return
	var fw: int = 76
	var fh: int = 75
	var frames := SpriteFrames.new()
	var layout := {
		"back":   [Vector2(0, 0),   Vector2(76, 0),   Vector2(152, 0)],
		"left":   [Vector2(0, 75),  Vector2(76, 75),  Vector2(152, 75)],
		"idle":   [Vector2(0, 150), Vector2(76, 150), Vector2(152, 150)],
		"right":  [Vector2(0, 225), Vector2(76, 225), Vector2(152, 225)],
	}
	var speeds := {"back": 4.0, "idle": 3.0, "left": 4.0, "right": 6.0, "toward": 6.0}
	for anim in layout.keys():
		frames.add_animation(anim)
		frames.set_animation_speed(anim, speeds.get(anim, 4.0))
		frames.set_animation_loop(anim, true)
		for cell in layout[anim]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(cell.x, cell.y, fw, fh)
			frames.add_frame(anim, at)
	# toward 复用 idle 帧
	frames.add_animation("toward")
	frames.set_animation_speed("toward", speeds.get("toward", 6.0))
	frames.set_animation_loop("toward", true)
	for cell in layout["idle"]:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(cell.x, cell.y, fw, fh)
		frames.add_frame("toward", at)
	sprite.sprite_frames = frames


func _setup_camera_limits() -> void:
	# 根据当前视口大小 + 相机缩放计算边界，避免画面露出背景外（zoom<1 时需放大可视半径）
	var viewport_size := get_viewport_rect().size
	var z: float = camera.zoom.x
	var _half_w := viewport_size.x * 0.5 / z
	var _half_h := viewport_size.y * 0.5 / z
	camera.limit_left = int(0)
	camera.limit_top = int(0)
	camera.limit_right = int(5088.0)
	camera.limit_bottom = int(2784.0)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_fire_cooldown -= delta
	_invuln = max(_invuln - delta, 0.0)
	_kb_vel = _kb_vel.move_toward(Vector2.ZERO, KB_DECAY * delta)

	# 宠物跟随：缓动到脚边 + 待机浮动 + 呼吸缩放，随角色左右朝向翻转
	if _pet_node != null:
		if facing == "left":
			_pet_side = 1.0
			_pet_face_left = true
		elif facing == "right":
			_pet_side = -1.0
			_pet_face_left = false
		# back / toward（上下移动）时沿用上一次的左右朝向
		var target := Vector2(_PET_FOOT_X * _pet_side, _PET_FOOT_Y)
		_pet_base = _pet_base.lerp(target, 1.0 - exp(-_PET_FOLLOW_LERP * delta))
		var t := Time.get_ticks_msec() * 0.001
		var bob := sin(t * _PET_BOB_SPEED) * _PET_BOB_AMP
		_pet_node.position = _pet_base + Vector2(0.0, bob)
		_pet_node.scale.x = -1.0 if _pet_face_left else 1.0
		_pet_node.scale.y = 1.0 + sin(t * _PET_BOB_SPEED * 0.5) * _PET_BREATH_AMP
		var glow := _pet_node.get_node_or_null("Glow")
		if glow != null:
			var ga: float = glow.get_meta("base_alpha", 0.3)
			glow.modulate.a = ga + 0.15 * (0.5 + 0.5 * sin(t * _PET_BOB_SPEED))

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _stunned:
		velocity = _kb_vel
	else:
		velocity = input_dir * speed + _kb_vel

	if input_dir.x < 0:
		facing = "left"
	elif input_dir.x > 0:
		facing = "right"
	elif input_dir.y < 0:
		facing = "back"
	elif input_dir.y > 0:
		facing = "toward"

	if input_dir != Vector2.ZERO:
		sprite.play(facing)
	else:
		sprite.play("idle")

	# 无敌帧闪烁（受击后短暂半透明闪烁，提示已免疫）
	if _invuln > 0.0:
		sprite.modulate.a = 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.03)
	else:
		sprite.modulate.a = 1.0

	move_and_slide()

	# 开火逻辑：发射瞬间以玩家为圆心判定锁敌；无敌人则朝人物前进方向直发
	var wants_fire := auto_fire
	if Input.is_action_pressed("shoot"):
		wants_fire = true
	if _use_builtin_attack and wants_fire and _fire_cooldown <= 0.0:
		_fire()
		_fire_cooldown = fire_rate

func _find_nearest_enemy_in_radius(radius: float) -> Node2D:
	# 以玩家为圆心、radius 为半径内的最近敌人
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_dist: float = radius
	for e in enemies:
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= best_dist:
			best_dist = d
			best = e
	return best

func _fire() -> void:
	if bullet_scene == null:
		return
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	var offset_dir: Vector2 = _facing_vector()
	b.global_position = global_position + offset_dir * muzzle_offset

	# 以玩家为圆心，aim_radius 内锁定最近敌人；圆内无敌人则朝人物前进方向直飞
	var locked: Node2D = _find_nearest_enemy_in_radius(aim_radius)
	if locked != null:
		b.target = locked
		b.direction = (locked.global_position - b.global_position).normalized()
	else:
		b.target = null
		b.direction = offset_dir
	b.speed = bullet_speed
	b.damage = bullet_damage

func _facing_vector() -> Vector2:
	match facing:
		"left": return Vector2(-1, 0)
		"right": return Vector2(1, 0)
		"back": return Vector2(0, -1)
		_: return Vector2(0, 1)   # toward

func take_damage(amount: float, knock_dir: Vector2 = Vector2.ZERO, knock_force: float = 0.0) -> void:
	if _dead:
		return
	if _invuln > 0.0:
		return   # 无敌帧内免疫（防止被 BOSS 连击/弹幕瞬间秒杀）
	# 护盾优先拦截：shield_handler 由守护圣盾节点注册，absorb 返回仍需扣血的量
	if shield_handler != null and shield_handler.has_method("absorb"):
		amount = shield_handler.absorb(amount)
	if amount <= 0.0:
		return
	_hp -= amount
	_invuln = INVULN_TIME          # 进入无敌帧
	if knock_force > 0.0 and knock_dir != Vector2.ZERO:
		_kb_vel = knock_dir * knock_force   # 击退
	queue_redraw()   # 受伤后刷新血条
	if _hp <= 0.0:
		_die()

# ——— 经验 / 等级 / 拾取 ———
func _next_threshold(lvl: int) -> float:
	return ceil(_exp_base * pow(_exp_growth, lvl - 1))

func gain_exp(amount: float) -> void:
	_exp += amount * xp_pickup_mult
	var leveled: bool = false
	while true:
		var need := _next_threshold(_level) / xp_rate_mult
		if _exp < need:
			break
		_exp -= need
		_level += 1
		_pending_levels += 1
		_exp_to_next = _next_threshold(_level) / xp_rate_mult
		leveled = true
	if leveled:
		leveled_up.emit()

func consume_level_up() -> void:
	_pending_levels = max(0, _pending_levels - 1)
	# 玩家选完升级卡后，在角色身上播放升级闪光（此时升级 UI 已收起，玩家能看到）
	if FXManager != null:
		FXManager.spawn_levelup_flash(global_position)

func get_pending_levels() -> int:
	return _pending_levels

func get_exp_ratio() -> float:
	return clamp(_exp / _exp_to_next, 0.0, 1.0)

func get_level() -> int:
	return _level

func get_magnet_radius() -> float:
	return magnet_radius

func get_hp() -> float:
	return clamp(_hp, 0.0, max_hp)

func get_max_hp() -> float:
	return max_hp

func get_hp_ratio() -> float:
	return clamp(_hp / max_hp, 0.0, 1.0)


func get_facing() -> String:
	return facing

# 角色出战：按角色属性修正基础数值（max_hp / speed），并刷新当前血量
func apply_run_mods(hp_mult: float, speed_mult: float) -> void:
	_base_max_hp = max_hp * hp_mult
	_base_speed = 440.0 * speed_mult
	max_hp = _base_max_hp
	speed = _base_speed
	_hp = max_hp
	queue_redraw()
	_apply_equipment_stats()   # 重新应用装备属性（叠加在角色基础之上）

# 装备属性的基础值快照（防止重复叠加）
var _base_max_hp: float = 15.0
var _base_speed: float = 440.0
var _base_bullet_damage: float = 1.0
var _base_bullet_speed: float = 960.0
var _base_magnet_radius: float = 140.0
var _base_xp_pickup_mult: float = 1.0

func _apply_equipment_stats() -> void:
	if EquipmentManager == null or RunStats == null:
		return
	var gear_stats: Dictionary = EquipmentManager.get_all_flat_stats(RunStats.equipped_gear)
	var hp_bonus: float = gear_stats.get("max_hp_bonus", 0.0)
	var spd_bonus: float = gear_stats.get("move_speed_bonus", 0.0)
	var atk_bonus: float = gear_stats.get("atk_bonus", 0.0)
	var pspd_bonus: float = gear_stats.get("projectile_speed", 0.0)
	var _def_bonus: float = gear_stats.get("def_bonus", 0.0)
	var pickup_bonus: float = gear_stats.get("pickup_radius", 0.0)
	var exp_bonus: float = gear_stats.get("exp_bonus", 0.0)

	# 从基础值重新计算，避免重复叠加（幂等）
	var prev_max_hp: float = max_hp
	max_hp = _base_max_hp + hp_bonus
	if max_hp > prev_max_hp:
		# 装上提升上限的装备（如石肤护符 +8）时，把当前血量同步补上这部分增量，
		# 避免读档 / 换装后血条"空出"这部分上限（正好 8 点的情况）。
		_hp += (max_hp - prev_max_hp)
		if _hp > max_hp:
			_hp = max_hp
	elif _hp > max_hp:
		_hp = max_hp
	speed = _base_speed + spd_bonus
	bullet_damage = _base_bullet_damage + atk_bonus
	bullet_speed = _base_bullet_speed * (1.0 + pspd_bonus)
	magnet_radius = _base_magnet_radius + pickup_bonus
	xp_pickup_mult = _base_xp_pickup_mult + exp_bonus

	# 宠物跟随：根据装备槽状态创建/移除跟随节点
	var has_pet: bool = RunStats.equipped_gear.has("pet") and not RunStats.equipped_gear["pet"].is_empty()
	var pet_id: String = RunStats.equipped_gear.get("pet", {}).get("def_id", "") if has_pet else ""
	var current_pet_id: String = ""
	if _pet_node != null:
		current_pet_id = _pet_node.get_meta("pet_id", "") as String
	if has_pet and (_pet_node == null or current_pet_id != pet_id):
		if _pet_node != null:
			_pet_node.queue_free()
		_pet_node = _create_pet_node(pet_id)
		_pet_node.set_meta("pet_id", pet_id)
		add_child(_pet_node)
		_pet_base = Vector2(_PET_FOOT_X * _pet_side, _PET_FOOT_Y)
	elif not has_pet and _pet_node != null:
		_pet_node.queue_free()
		_pet_node = null


	queue_redraw()

func _create_pet_node(pet_id: String) -> Node2D:
	var pet := Node2D.new()
	pet.name = "PetFollower"
	var icon_path: String = GEAR_ICON_DIR + pet_id + ".png"
	if ResourceLoader.exists(icon_path):
		# 使用素材 PNG 作为宠物外观（按目标世界高度等比缩放）
		var tex: Texture2D = load(icon_path)
		var spr := Sprite2D.new()
		spr.name = "Sprite"
		spr.texture = tex
		var sc: float = _PET_WORLD_H / float(max(tex.get_width(), tex.get_height()))
		spr.scale = Vector2(sc, sc)
		pet.add_child(spr)
		# 柔光底：让宠物更醒目（精灵光球偏冷、猎犬幼崽偏暖）
		var glow := Sprite2D.new()
		glow.name = "Glow"
		glow.texture = tex
		glow.scale = Vector2(sc * 1.5, sc * 1.5)
		glow.z_index = -1
		var glow_base: float = 0.35
		if pet_id == "pet_hound":
			glow.modulate = Color(1.0, 0.7, 0.4, 0.30)
			glow_base = 0.30
		else:
			glow.modulate = Color(0.6, 0.9, 1.0, 0.35)
			glow_base = 0.35
		glow.set_meta("base_alpha", glow_base)
		pet.add_child(glow)
	else:
		# 兜底：素材缺失时仍用程序绘制圆球（与原逻辑一致）
		var segs: int = 18
		var ball := Polygon2D.new()
		var pts: PackedVector2Array = []
		for i in range(segs):
			var ang: float = float(i) / segs * TAU
			pts.append(Vector2(cos(ang) * 8.0, sin(ang) * 8.0))
		ball.polygon = pts
		var col: Color = Color(0.45, 0.85, 1.0, 0.90)   # 精灵光球：青色
		if pet_id == "pet_hound":
			col = Color(0.90, 0.55, 0.25, 0.90)          # 猎犬幼崽：橙棕色
		ball.color = col
		pet.add_child(ball)
		var g2 := Polygon2D.new()
		var gpts: PackedVector2Array = []
		for i in range(segs):
			var ang: float = float(i) / segs * TAU
			gpts.append(Vector2(cos(ang) * 14.0, sin(ang) * 14.0))
		g2.polygon = gpts
		g2.color = Color(col.r, col.g, col.b, 0.25)
		pet.add_child(g2)
	return pet


func heal(amount: float) -> void:
	var before: float = _hp
	_hp = min(_hp + amount, max_hp)
	var healed: float = _hp - before

	queue_redraw()   # 回血后刷新血条
	if healed > 0.0:
		_spawn_float_text("+%d" % int(healed), Color(0.35, 1.0, 0.45))
		_flash_green()

# Boss 蛛网定身：禁止移动 duration 秒，之后自动恢复
func stun(duration: float) -> void:
	_stunned = true
	await get_tree().create_timer(duration).timeout
	_stunned = false

# 头顶飘字：向上浮动并淡出后自动销毁
func _spawn_float_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.position = Vector2(-16.0, -64.0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", Vector2(label.position.x, -112.0), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

# 回血时玩家整体绿闪一下
func _flash_green() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.55, 1.0, 0.55), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.35)

func export_state() -> Dictionary:
	return {
		"hp": _hp,
		"max_hp": max_hp,
		"level": _level,
		"exp": _exp,
		"exp_to_next": _exp_to_next,
		"pending_levels": _pending_levels,
		"facing": facing,
		"speed": speed,
		"bullet_damage": bullet_damage,
		"bullet_speed": bullet_speed,
		"magnet_radius": magnet_radius,
		"xp_pickup_mult": xp_pickup_mult,
		"xp_rate_mult": xp_rate_mult,
		"invuln": _invuln,
		"stunned": _stunned,
		"kb_vel_x": _kb_vel.x,
		"kb_vel_y": _kb_vel.y,
		"dead": _dead,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"base_max_hp": _base_max_hp,
		"base_speed": _base_speed,
		"base_bullet_damage": _base_bullet_damage,
		"base_bullet_speed": _base_bullet_speed,
		"base_magnet_radius": _base_magnet_radius,
		"base_xp_pickup_mult": _base_xp_pickup_mult,
	}

func restore_state(data: Dictionary) -> void:
	# 读档进游戏：血量重置为满血，不继承存档里残存的剩余血量。
	# 先恢复基础属性，再据此重新计算 max_hp（叠加当前装备加成），
	# 最后无条件满血——避免"读档后血条显示几乎空"的观感问题。
	_base_max_hp = data.get("base_max_hp", _base_max_hp)
	_base_speed = data.get("base_speed", _base_speed)
	_base_bullet_damage = data.get("base_bullet_damage", _base_bullet_damage)
	_base_bullet_speed = data.get("base_bullet_speed", _base_bullet_speed)
	_base_magnet_radius = data.get("base_magnet_radius", _base_magnet_radius)
	_base_xp_pickup_mult = data.get("base_xp_pickup_mult", _base_xp_pickup_mult)
	_apply_equipment_stats()   # 用恢复出的基础值 + 当前装备重算 max_hp
	_hp = max_hp               # 读档默认满血
	_level = data.get("level", 1)
	_exp = data.get("exp", 0.0)
	_exp_to_next = data.get("exp_to_next", _exp_to_next)
	_pending_levels = data.get("pending_levels", 0)
	facing = data.get("facing", "toward")
	speed = data.get("speed", speed)
	bullet_damage = data.get("bullet_damage", bullet_damage)
	bullet_speed = data.get("bullet_speed", bullet_speed)
	magnet_radius = data.get("magnet_radius", magnet_radius)
	xp_pickup_mult = data.get("xp_pickup_mult", xp_pickup_mult)
	xp_rate_mult = data.get("xp_rate_mult", xp_rate_mult)
	_invuln = data.get("invuln", 0.0)
	_stunned = data.get("stunned", false)
	_kb_vel = Vector2(data.get("kb_vel_x", 0.0), data.get("kb_vel_y", 0.0))
	_dead = data.get("dead", false)
	global_position = Vector2(data.get("position_x", global_position.x), data.get("position_y", global_position.y))
	queue_redraw()

func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	# 不再直接重载场景；改为发信号，由 main.gd 拉起结算屏（暂停游戏、可选重开/回主菜单）
	died.emit()

func _notification(what: int) -> void:
	# 窗口大小变化时重新计算相机边界
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_setup_camera_limits()

# 头顶血条：无数字，仅用长度表示血量（满血=hp_bar_width，残血按比例缩短）
func _draw() -> void:
	var w: float = hp_bar_width
	var h: float = 6.0
	var x0: float = -w * 0.5
	var y0: float = hp_bar_y
	var ratio: float = clamp(_hp / max_hp, 0.0, 1.0)
	# 背景框
	draw_rect(Rect2(x0 - 1.0, y0 - 1.0, w + 2.0, h + 2.0), Color(0.0, 0.0, 0.0, 0.7), true)
	# 血量前景（颜色随比例 红→黄→绿）
	draw_rect(Rect2(x0, y0, w * ratio, h), Color.from_hsv(0.33 * ratio, 0.85, 1.0), true)
