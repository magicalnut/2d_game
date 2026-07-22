extends CharacterBody2D

## 敌人：进入 "enemy" 组供玩家自动寻敌；
## 近战型（默认）：追击玩家，接触时周期性造成伤害；
## 远程型（ranged=true，如 agent）：与玩家保持距离并射击敌方子弹，命中玩家造成伤害；
## 被子弹命中后扣血，血量归零播放死亡动画并移除自身。

const EXP_ORB_SCENE := preload("res://Assets/Sprites/Pickups/exp_orb.tscn")
const HEALTH_BOTTLE_SCENE := preload("res://Assets/Sprites/Pickups/health_bottle.tscn")

@export var hp: float = 3.0
@export var speed: float = 90.0              # 移动速度
@export var touch_damage: float = 1.0        # 接触造成的伤害（近战）
@export var attack_interval: float = 1.0     # 两次接触伤害的最小间隔（秒）
@export var attack_range: float = 40.0       # 进入此距离即视为"接触"（近战）
@export var hp_bar_width: float = 44.0        # 血条长度（满血时）
@export var hp_bar_y: float = -46.0           # 血条相对人物原点的纵向偏移（头顶上方）
@export var exp_value: float = 1.0            # 死亡掉落的经验值（可按敌人类型调大）
@export var health_drop_chance: float = 0.016  # 额外掉落血瓶的概率（原 0.08 的 1/5，较低）

# —— 远程攻击（agent 等）——
@export var ranged: bool = false
@export var stationary: bool = false          # 固定不动且不攻击：刷出后原地站桩，仅作为可击杀目标（掉经验），不会移动也不会开火
@export var bullet_scene: PackedScene = null  # 远程子弹场景（如 enemy_bullet.tscn）
@export var fire_range: float = 560.0         # 进入此距离才开火（超出则先靠近）
@export var preferred_range: float = 360.0    # 倾向与玩家保持的距离（风筝）
@export var fire_rate: float = 1.5            # 开火间隔（秒）
@export var bullet_damage: float = 1.0        # 单发子弹伤害
@export var bullet_speed: float = 300.0       # 子弹飞行速度

@export var boss: bool = false                # BOSS 标记：放大体型、周期性环形弹幕、死亡高经验+回血
var _boss_timer: float = 0.0
const BOSS_FIRE_INTERVAL: float = 2.2         # BOSS 环形弹幕间隔（秒）
const KNOCKBACK_DECAY: float = 1100.0         # 击退速度衰减（px/s²），越大被击退时间越短

var _dead: bool = false
var _attack_timer: float = 0.0
var _facing: String = "toward"
var _max_hp: float = 1.0
var _frozen: bool = false   # 时空沙漏冻结：锁定移动与攻击，但仍可被伤害
var _hit_fx_timer: float = 0.0  # 受击火花冷却，避免连发弹幕时火花刷屏
var _knockback: Vector2 = Vector2.ZERO  # 当前击退速度（被毁灭重拳等击飞时），逐帧衰减

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")
	_max_hp = hp
	if boss:
		# BOSS：放大体型、加长头顶血条、向 HUD 暴露自身（供 BOSS 血条显示）
		if sprite != null:
			sprite.scale = Vector2(2.4, 2.4)
		hp_bar_width = 120.0
		hp_bar_y = -92.0
		if RunStats != null:
			RunStats.boss_ref = self
	queue_redraw()   # 初始化时绘制满血血条
	_play_idle()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_timer = max(_attack_timer - delta, 0.0)
	_hit_fx_timer = max(_hit_fx_timer - delta, 0.0)

	# 击退：被毁灭重拳等击飞时，沿击退方向滑行并逐渐衰减，期间跳过常规 AI 与攻击
	if _knockback.length() > 12.0:
		velocity = _knockback
		move_and_slide()
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		return

	# 时空沙漏冻结：锁住移动与攻击（含 BOSS 弹幕），但仍可被伤害
	if _frozen:
		velocity = Vector2.ZERO
		_play_idle()
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		_play_idle()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if stationary:
		# 站桩目标：原地不动、不追击、不开火；仅作为可击杀掉落经验的目标
		velocity = Vector2.ZERO
		_play_idle()
		return

	if ranged:
		_update_facing(to_player)
		if dist > fire_range:
			# 太远，靠近直到进入射程（此时不开火）
			velocity = to_player.normalized() * speed
			_play_walk()
			move_and_slide()
		elif dist > preferred_range:
			# 在射程内但尚未到理想站位：边靠近边开火
			velocity = to_player.normalized() * speed
			_play_walk()
			move_and_slide()
			if _attack_timer <= 0.0:
				_fire_at_player(player)
				_attack_timer = fire_rate
		elif dist < preferred_range * 0.7:
			# 太近，后撤保持距离（风筝走位）
			velocity = -to_player.normalized() * speed * 0.85
			_play_walk()
			move_and_slide()
			if _attack_timer <= 0.0:
				_fire_at_player(player)
				_attack_timer = fire_rate
		else:
			# 理想站位（preferred_range 附近），停下开火
			velocity = Vector2.ZERO
			_play_idle()
			if _attack_timer <= 0.0:
				_fire_at_player(player)
				_attack_timer = fire_rate
	else:
		# 近战：原有逻辑（追击 + 接触伤害）
		if dist > attack_range:
			velocity = to_player.normalized() * speed
			_update_facing(to_player)
			_play_walk()
			move_and_slide()
		else:
			velocity = Vector2.ZERO
			_play_idle()
			if _attack_timer <= 0.0 and player.has_method("take_damage"):
				player.take_damage(touch_damage)
				_attack_timer = attack_interval

	# BOSS：无论近战/远程分支，周期性向四周发射环形弹幕
	if boss:
		_boss_timer -= delta
		if _boss_timer <= 0.0:
			_boss_fire_ring(player)
			_boss_timer = BOSS_FIRE_INTERVAL

func _update_facing(dir: Vector2) -> void:
	if abs(dir.x) >= abs(dir.y):
		_facing = "right" if dir.x > 0.0 else "left"
	else:
		_facing = "toward" if dir.y > 0.0 else "back"

func _play_walk() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(_facing):
		sprite.play(_facing)

func _play_idle() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _fire_at_player(player: Node2D) -> void:
	if bullet_scene == null:
		return
	var b = bullet_scene.instantiate()
	b.global_position = global_position
	b.direction = (player.global_position - global_position).normalized()
	b.speed = bullet_speed
	b.damage = bullet_damage
	get_parent().add_child(b)

# BOSS 环形弹幕：以自身为中心向四周均匀发射一圈子弹
func _boss_fire_ring(player: Node2D) -> void:
	if bullet_scene == null:
		return
	var n: int = 16
	for i in n:
		var ang: float = TAU * float(i) / float(n)
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.direction = Vector2(cos(ang), sin(ang))
		b.speed = 220.0
		b.damage = 1.0
		get_parent().add_child(b)

func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	queue_redraw()   # 受伤后刷新血条
	# 受击火花：短暂冷却，避免密集火力时火花刷屏
	if _hit_fx_timer <= 0.0 and FXManager != null:
		var scale_mult: float = 2.4 if boss else 1.0
		FXManager.spawn_hit_spark(global_position, scale_mult)
		_hit_fx_timer = 0.08
	if hp <= 0.0:
		_die()

func is_dead() -> bool:
	return _dead

func get_hp_ratio() -> float:
	return clamp(hp / _max_hp, 0.0, 1.0)

# 击退：由毁灭重拳等技能调用。from 为爆发中心，force 为初速度(px/s)。
# 沿"远离中心"方向被击飞，随后逐帧衰减；BOSS 太重，击退力减半。
func apply_knockback(from: Vector2, force: float) -> void:
	if _dead:
		return
	var dir: Vector2 = global_position - from
	if dir.length() < 0.001:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	dir = dir.normalized()
	if boss:
		force *= 0.5
	_knockback = dir * force

# 时空沙漏调用：冻结/解冻；冻结时精灵偏蓝提示
func set_frozen(v: bool) -> void:
	_frozen = v
	if sprite != null:
		sprite.modulate = Color(0.55, 0.75, 1.0) if v else Color(1.0, 1.0, 1.0)

func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	# 死亡烟尘已移除（用户要求先去掉），保留各自 death 动画 + 掉落反馈
	# BOSS 死亡：清空 HUD 引用并治疗玩家
	if boss:
		if RunStats != null:
			RunStats.boss_ref = null
			RunStats.boss_defeated.emit()
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null and pl.has_method("heal"):
			pl.heal(3.0)
	# 单局击杀统计（RunStats 为 AutoLoad 单例；非战斗场景下不会触发）
	if RunStats != null:
		RunStats.add_kill()
	# 立即让尸体失效：移出 enemy 组并关闭碰撞，避免玩家/子弹继续攻击尸体
	remove_from_group("enemy")
	# 注意：_die 常由子弹 body_entered 信号触发，正处于物理查询刷新中，
	# 不能直接改碰撞状态，否则报 "Can't change this state while flushing queries"。
	# 用 set_deferred 延迟到下一物理帧再改。
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var cs := get_node_or_null("CollisionShape2D")
	if cs != null:
		cs.set_deferred("disabled", true)
	_drop_loot()
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	queue_free()

# 死亡掉落：每个敌人必掉 1 个经验球；并以 health_drop_chance 概率额外掉血瓶
func _drop_loot() -> void:
	var orb = EXP_ORB_SCENE.instantiate()
	orb.global_position = global_position
	orb.exp_value = exp_value
	get_parent().add_child(orb)
	if randf() < health_drop_chance:
		var hb = HEALTH_BOTTLE_SCENE.instantiate()
		hb.global_position = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		get_parent().add_child(hb)

# 头顶血条：无数字，仅用长度表示血量（满血=hp_bar_width，残血按比例缩短）
func _draw() -> void:
	var w: float = hp_bar_width
	var h: float = 6.0
	var x0: float = -w * 0.5
	var y0: float = hp_bar_y
	var ratio: float = clamp(hp / _max_hp, 0.0, 1.0)
	# 背景框
	draw_rect(Rect2(x0 - 1.0, y0 - 1.0, w + 2.0, h + 2.0), Color(0.0, 0.0, 0.0, 0.7), true)
	# 血量前景（敌人恒定纯红，与玩家的红→黄→绿渐变血条区分敌我）
	draw_rect(Rect2(x0, y0, w * ratio, h), Color(0.90, 0.16, 0.16), true)
