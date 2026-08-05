extends CharacterBody2D

## 独立 BOSS 实体（每累计清满 5 波降临一次，击败后给玩家一次特殊技能选择）。
## 与 enemy.gd 完全解耦：拥有自己的两阶段攻击状态机与带"预警(wind-up)"的多种攻击。
## 阶段划分（按血量比例）：
##   阶段1 (HP>50%)：环形弹幕 / 瞄准连射（简单、易读）
##   阶段2 (HP≤50% 狂暴)：环形爆发 + 螺旋弹幕 + 冲撞 + 瞄准 + 召唤，节奏更快、更激进
## 美术：每只 BOSS 的素材按 WaveManager.BOSS_DEFS 的路径放置。
##       Boss/BossN/{Body,Bullets,Telegraphs,Impacts}/*.png
##       Body=本体立绘  Bullets=弹幕外观  Telegraphs=预警圈/线  Impacts=命中/爆炸
##       没有贴图时自动显示占位圆（颜色取该 BOSS 的 tint）/沿用通用弹，保证无素材也能跑、可测试。

const EXP_ORB_SCENE := preload("res://Assets/Sprites/Pickups/exp_orb.tscn")
const ENEMY_BULLET  := preload("res://Assets/Sprites/Weapons/Bullet/enemy_bullet.tscn")
const BODY_TEX_PATH := "res://Assets/Sprites/Bosses/Boss1/Body/body.png"  # 仅当 def 缺失时的兜底路径（正常不会用到）

# —— 基础属性（wave_manager._spawn_boss 会覆盖 hp / touch_damage / exp_value）——
@export var hp: float = 360.0
@export var touch_damage: float = 4.0
@export var exp_value: float = 45.0
var boss: bool = true          # 供 WaveManager._boss_count() 识别
var def: Dictionary = {}        # 由 WaveManager 随机分配（贴图路径/配色/移速/攻击倾向等）
var boss_name: String = "BOSS"  # 出场横幅与（可选）HUD 显示用
var _bullet_tex: Texture2D = null  # 该 BOSS 专属弹幕贴图（def["bullet"] 指定；缺省用通用 enemy_bullet）
var _tele_tex: Texture2D = null    # 该 BOSS 专属预警贴图（def["telegraph"] 指定；缺省用代码绘制）
var _impact_tex: Texture2D = null  # 该 BOSS 专属命中特效（def["impact"] 指定；缺省复用全局受击火花）
var _tele_sprite: Sprite2D = null  # 预警贴图精灵（仅在 telegraph 存在时创建）

# —— 内部状态 ——
var _dead: bool = false
var _max_hp: float = 360.0
var _frozen: bool = false
var _hit_fx_timer: float = 0.0
var _fx_sprites: Array = []   # 本场 BOSS 产生的、挂在世界上的命中特效精灵（死亡时统一回收，避免残留）
var _enraged: bool = false
var _prev_phase: int = 1

# 移动
var _base_speed: float = 120.0    # 由 def["speed"] 覆盖（每只 BOSS 不同）
const _preferred_range: float = 250.0
const _contact_range: float = 78.0
const _melee_trigger: float = 110.0   # 玩家进入此距离才触发近战挥砍
const _swipe_range: float = 170.0    # 挥砍有效命中半径
const KB_FORCE: float = 340.0        # 命中玩家时的击退强度
var _melee_dir: Vector2 = Vector2.RIGHT  # 近战挥砍方向（预警时锁定）
var _attack_timer: float = 0.0
const _attack_interval: float = 0.6

# 攻击状态机：IDLE(冷却) -> TELEGRAPH(预警) -> RECOVER(出手+恢复)
enum AState { IDLE, TELEGRAPH, RECOVER }
var _astate: int = AState.IDLE
var _atimer: float = 1.2        # 出场后短暂缓冲再开始攻击
var _tele: float = 0.0
var _tele_dur: float = 0.6
var _tele_progress: float = 0.0
var _tele_kind: String = ""
var _recover_dur: float = 1.6
var _pending: String = ""

# 冲撞（charge）
var _charge_t: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_speed: float = 1440.0
var _charge_dist: float = 420.0

# 螺旋（spiral）
var _spiral_t: float = 0.0
var _spiral_acc: float = 0.0
var _spiral_angle: float = 0.0
var _spiral_arms: int = 4
var _spiral_step: float = 0.10
var _spiral_rot: float = 0.45
var _spiral_speed: float = 520.0
var _spiral_dmg: float = 1.0

# 召唤
var _summon_n: int = 2
# 新版螺旋（持续发射 + 独立冷却）——由 def["spiral_duration"] 激活
var _spiral_duration: float = 5.0
var _spiral_cooldown: float = 5.0
var _spiral_cooldown_timer: float = 0.0
var _spiral_bullets: int = 36
# 弯刀弹幕（wave）：弧形子弹像弯刀一样射向玩家
var _wave_cooldown: float = 3.0
var _wave_cooldown_timer: float = 0.0
var _wave_bullets: int = 10
var _wave_angle: float = 100.0
var _wave_speed: float = 280.0
var _wave_dmg: float = 1.0
var _wave_dir: Vector2 = Vector2.RIGHT

# 连射（burst，远程 BOSS 狂暴时朝玩家持续扫射）
var _burst_t: float = 0.0
var _burst_acc: float = 0.0
var _burst_step: float = 0.13
var _burst_speed: float = 680.0
var _burst_dmg: float = 1.0
var _burst_spread: float = 0.10

# 激光
var _laser_dir: Vector2 = Vector2.RIGHT
var _laser_range: float = 800.0
var _laser_width: float = 40.0
var _laser_t: float = 0.0
# 新版激光（长方形虚线预警 → 瞬发伤害）——由 def["laser_telegraph"] 激活
var _laser_telegraph_total: float = 1.7
var _laser_warning_dur: float = 1.0
var _laser_react_dur: float = 0.7
var _laser_length: float = 10000.0
var _laser_damage: float = 5.0
var _laser_cooldown: float = 3.0
var _laser_cooldown_timer: float = 0.0
var _laser_use_new: bool = false

# 预警绘制
var _tele_radius: float = 520.0
var _ring_count: int = 36
# distance_ring AI 模式（由 def["ai_mode"] 激活）——自动环形弹幕 + 定时冲撞 + 距离狂暴
var _ai_mode: String = ""
var _ring_distance: float = 500.0
var _ring_close_interval: float = 1.5
var _ring_far_interval: float = 1.0
var _ring_close_speed: float = 120.0
var _ring_far_speed: float = 180.0
var _ring_close_dmg: float = 0.5
var _ring_far_dmg: float = 1.0
var _ring_auto_count: int = 36
var _charge_auto_interval: float = 5.0
var _charge_auto_distance: float = 700.0
var _ring_auto_timer: float = 0.0
var _charge_auto_timer: float = 0.0
var _auto_ring_flash: float = 0.0
var _auto_aimed_interval: float = 0.0
var _auto_aimed_timer: float = 0.0
var _auto_melee_interval: float = 0.0
var _auto_melee_timer: float = 0.0
var _auto_burst_interval: float = 0.0
var _auto_burst_timer: float = 0.0
var _auto_laser_interval: float = 0.0
var _auto_laser_timer: float = 0.0
var _auto_laser_telegraph: float = 0.0
var _auto_laser_dir: Vector2 = Vector2.RIGHT
var _auto_laser_flash: float = 0.0
var _ringseq_interval: float = 0.0
var _ringseq_timer: float = 0.0
var _ringseq_angle: float = 0.0
var _ringseq_speed: float = 200.0
var _ringseq_dmg: float = 1.0
var _web_interval: float = 0.0
var _web_timer: float = 0.0
var _web_tex: Texture2D = null
var _sickle_interval: float = 0.0
var _sickle_timer: float = 0.0
var _sickle_tex: Texture2D = null

@onready var body_sprite: Sprite2D = $Body
@onready var anim_body: AnimatedSprite2D = $AnimatedBody
@onready var placeholder: Polygon2D = $Placeholder
var _body_base_scale: float = 1.0
@export var head_offset: float = -120.0   # 受击数字出生点：相对 Boss 原点向上偏移（头顶上方），按实际体型调
var _use_animated: bool = false

func _ready() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")
	_max_hp = hp

	# 读取该 BOSS 的专属配置（贴图路径 / 名称 / 移速 / 配色）
	var body_path: String = BODY_TEX_PATH
	if def.size() > 0:
		boss_name = def.get("name", "BOSS")
		if def.has("speed"):
			_base_speed = def["speed"]
		if def.has("auto_laser_interval"):
			_auto_laser_interval = def["auto_laser_interval"]
			_auto_laser_timer = 2.0
		if def.has("auto_aimed_interval"):
			_auto_aimed_interval = def["auto_aimed_interval"]
			_auto_aimed_timer = 1.0
		if def.has("auto_melee_interval"):
			_auto_melee_interval = def["auto_melee_interval"]
			_auto_melee_timer = 0.5
		if def.has("auto_burst_interval"):
			_auto_burst_interval = def["auto_burst_interval"]
			_auto_burst_timer = 2.0
		if def.has("ringseq_interval"):
			_ringseq_interval = def["ringseq_interval"]
			_ringseq_speed = def.get("ringseq_speed", 200.0)
			_ringseq_dmg = def.get("ringseq_dmg", 1.0)
			_ringseq_timer = 0.5
		if def.has("web_interval"):
			_web_interval = def["web_interval"]
			_web_timer = 2.0
			if def.has("web_tex") and ResourceLoader.exists(def["web_tex"]):
				_web_tex = load(def["web_tex"]) as Texture2D
		if def.has("sickle_interval"):
			_sickle_interval = def["sickle_interval"]
			_sickle_timer = 2.0
			if def.has("sickle_tex") and ResourceLoader.exists(def["sickle_tex"]):
				_sickle_tex = load(def["sickle_tex"]) as Texture2D
		body_path = def.get("path", BODY_TEX_PATH)
		# 专属弹幕贴图（可选）：有则加载，否则沿用通用 enemy_bullet
		if def.has("bullet") and ResourceLoader.exists(def["bullet"]):
			_bullet_tex = load(def["bullet"]) as Texture2D
		# 专属预警贴图（可选）：有则加载，并在脚下创建预警精灵（圈）
		if def.has("telegraph") and ResourceLoader.exists(def["telegraph"]):
			_tele_tex = load(def["telegraph"]) as Texture2D
			var ts := Sprite2D.new()
			ts.name = "Telegraph"
			ts.texture = _tele_tex
			ts.visible = false
			ts.centered = true
			ts.z_index = -2
			ts.position = Vector2(0, 8)
			add_child(ts)
			_tele_sprite = ts
		# 专属命中特效（可选）：有则加载，否则命中时复用全局受击火花
		if def.has("impact") and ResourceLoader.exists(def["impact"]):
			_impact_tex = load(def["impact"]) as Texture2D
		# AI 模式配置（distance_ring 等）
		if def.has("ai_mode"):
			_ai_mode = def["ai_mode"]
			if _ai_mode == "distance_ring":
				_ring_distance = def.get("ring_distance", 500.0)
				_ring_auto_count = def.get("ring_count", 36)
				_ring_close_interval = def.get("ring_close_interval", 1.5)
				_ring_close_speed = def.get("ring_close_speed", 120.0)
				_ring_close_dmg = def.get("ring_close_dmg", 0.5)
				_ring_far_interval = def.get("ring_far_interval", 1.0)
				_ring_far_speed = def.get("ring_far_speed", 180.0)
				_ring_far_dmg = def.get("ring_far_dmg", 1.0)
				_charge_auto_interval = def.get("charge_interval", 5.0)
				_charge_auto_distance = def.get("charge_distance", 700.0)
				_ring_auto_timer = 1.5   # 出场后短暂缓冲再开始环形弹幕
			# 弯刀弹幕参数
			if def.has("wave_cooldown"):
				_wave_cooldown = def["wave_cooldown"]
				_wave_bullets = def.get("wave_bullets", 10)
				_wave_angle = def.get("wave_angle", 100.0)
				_wave_speed = def.get("wave_speed", 280.0)
				_wave_dmg = def.get("wave_dmg", 1.0)
				_charge_auto_timer = 3.0  # 出场后3秒首次冲撞
			# 新版螺旋参数
			if def.has("spiral_duration"):
				_spiral_duration = def["spiral_duration"]
			if def.has("spiral_cooldown"):
				_spiral_cooldown = def["spiral_cooldown"]
			if def.has("spiral_bullets"):
				_spiral_bullets = def["spiral_bullets"]
			# 新版激光参数（长方形虚线预警）
			if def.has("laser_telegraph"):
				_laser_use_new = true
				_laser_telegraph_total = def["laser_telegraph"]
				_laser_warning_dur = def.get("laser_warning", 1.0)
				_laser_react_dur = def.get("laser_react", 0.7)
				_laser_length = def.get("laser_length", 10000.0)
				_laser_width = def.get("laser_width", 50.0)
				_laser_damage = def.get("laser_damage", 5.0)
				_laser_cooldown = def.get("laser_cooldown", 3.0)

	# 本体贴图：有则加载，无则显示占位圆
	if def.has("animated") and def["animated"]:
		_use_animated = true
		body_sprite.visible = false
		placeholder.visible = false
		anim_body.visible = true
		var frames_dir: String = def.get("frames_dir", "")
		if frames_dir != "":
			_setup_animated_frames(frames_dir)
		else:
			_body_show_placeholder()
	elif ResourceLoader.exists(body_path):
		var tex = load(body_path) as Texture2D
		if tex != null:
			body_sprite.texture = tex
			_body_base_scale = 1.0
			if tex.get_height() > 0:
				_body_base_scale = clamp(170.0 / float(tex.get_height()), 0.2, 6.0)
			body_sprite.scale = Vector2.ONE * _body_base_scale
			placeholder.visible = false
			anim_body.visible = false
		else:
			_body_show_placeholder()
	else:
		_body_show_placeholder()

	# 碰撞体
	var cs := CircleShape2D.new()
	cs.radius = 48.0
	var cnode := CollisionShape2D.new()
	cnode.shape = cs
	cnode.position = Vector2(0, 8)
	add_child(cnode)

	# 暴露给 HUD 顶部 BOSS 血条
	if RunStats != null:
		RunStats.boss_ref = self

func _setup_animated_frames(frames_dir: String) -> void:
	var sf := SpriteFrames.new()
	var paths := [frames_dir+"frame_01.png",frames_dir+"frame_02.png",frames_dir+"frame_03.png",frames_dir+"frame_04.png",frames_dir+"frame_05.png",frames_dir+"frame_06.png"]
	var loaded: Array = []
	for fp in paths:
		if ResourceLoader.exists(fp):
			var t = load(fp) as Texture2D
			if t != null: loaded.append(t)
	if loaded.size() == 0: _body_show_placeholder(); return
	sf.add_animation("idle"); sf.set_animation_loop("idle",true); sf.set_animation_speed("idle",4.0)
	sf.add_animation("walk"); sf.set_animation_loop("walk",true); sf.set_animation_speed("walk",7.0)
	sf.add_animation("hurt"); sf.set_animation_loop("hurt",false)
	sf.add_animation("death"); sf.set_animation_loop("death",false)
	for tex in loaded: sf.add_frame("idle",tex); sf.add_frame("walk",tex)
	sf.add_frame("hurt",loaded[0]); sf.add_frame("death",loaded[0])
	anim_body.sprite_frames = sf
	var max_h: float = 0.0
	for t in loaded:
		max_h = max(max_h, float(t.get_height()))
	_body_base_scale = clamp(170.0 / max(max_h, 1.0), 0.2, 6.0)
	anim_body.scale = Vector2.ONE * _body_base_scale
	anim_body.play("idle")

func _body_show_placeholder() -> void:
	body_sprite.visible = false
	placeholder.visible = true
	var pts: PackedVector2Array = []
	var segs: int = 28
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a) * 58.0, sin(a) * 58.0))
	placeholder.polygon = pts
	placeholder.color = def.get("tint", Color(0.82, 0.16, 0.55))

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_fx_timer = max(_hit_fx_timer - delta, 0.0)
	_attack_timer = max(_attack_timer - delta, 0.0)

	# auto aimed timer
	if _auto_aimed_interval > 0.0:
		_auto_aimed_timer -= delta
		if _auto_aimed_timer <= 0.0 and is_instance_valid(get_tree().get_first_node_in_group("player")):
			_auto_aimed_timer = _auto_aimed_interval
			_fire_aimed(5, 0.16, def.get("bullet_speed", 330.0), def.get("bullet_dmg", 1.2), get_tree().get_first_node_in_group("player"))
	# auto laser timer
	if _auto_laser_interval > 0.0:
		_auto_laser_timer -= delta
		if _auto_laser_flash > 0.0:
			_auto_laser_flash -= delta
		if _auto_laser_telegraph > 0.0:
			_auto_laser_telegraph -= delta
			if _auto_laser_telegraph <= 0.0 and is_instance_valid(get_tree().get_first_node_in_group("player")):
				_laser_dir = _auto_laser_dir
				_do_laser_rect_hit(get_tree().get_first_node_in_group("player"))
				_auto_laser_flash = 0.3
		elif _auto_laser_timer <= 0.0:
			var pl = get_tree().get_first_node_in_group("player")
			if is_instance_valid(pl):
				_auto_laser_timer = _auto_laser_interval
				_auto_laser_dir = (pl.global_position - global_position).normalized()
				_auto_laser_telegraph = 0.7
	# auto rotating ring fireballs (one per 0.5s, 10deg step, 36 bullets per circle)
	if _ringseq_interval > 0.0:
		_ringseq_timer -= delta
		while _ringseq_timer <= 0.0:
			_ringseq_timer += _ringseq_interval
			var ang: float = deg_to_rad(_ringseq_angle)
			_fire_bullet(Vector2(cos(ang), sin(ang)), _ringseq_speed, _ringseq_dmg)
			_ringseq_angle += 5.0
			if _ringseq_angle >= 360.0:
				_ringseq_angle = 0.0
				_ringseq_timer += 0.5
	# auto rotating sickle (every N sec, toward player)
	if _sickle_interval > 0.0:
		_sickle_timer -= delta
		if _sickle_timer <= 0.0:
			_sickle_timer = _sickle_interval
			var pl = get_tree().get_first_node_in_group("player")
			if is_instance_valid(pl) and ENEMY_BULLET != null:
				var b = ENEMY_BULLET.instantiate()
				b.global_position = global_position
				b.direction = (pl.global_position - global_position).normalized()
				b.speed = def.get("sickle_speed", 300.0)
				b.damage = def.get("sickle_damage", 3.0)
				b.max_lifetime = 20.0
				b.spin_speed = def.get("sickle_spin", TAU)
				if _sickle_tex != null:
					var sp = b.get_node_or_null("Sprite2D")
					if sp != null:
						sp.texture = _sickle_tex
						if def.has("sickle_px") and _sickle_tex.get_width() > 0:
							var tw: float = float(_sickle_tex.get_width())
							sp.scale = Vector2.ONE * (float(def["sickle_px"]) / tw)
					var cs = b.get_node_or_null("CollisionShape2D")
					if cs != null:
						var sz: float = float(def["sickle_px"]) / 3.0
						var new_shape := RectangleShape2D.new()
						new_shape.size = Vector2(sz, sz)
						cs.shape = new_shape
				get_parent().add_child(b)
	# auto web stun attack (every N sec, toward player)
	if _web_interval > 0.0:
		_web_timer -= delta
		if _web_timer <= 0.0:
			_web_timer = _web_interval
			var pl = get_tree().get_first_node_in_group("player")
			if is_instance_valid(pl) and ENEMY_BULLET != null:
				var b = ENEMY_BULLET.instantiate()
				b.global_position = global_position
				b.direction = (pl.global_position - global_position).normalized()
				b.speed = def.get("web_speed", 600.0)
				b.damage = def.get("web_damage", 0.5)
				b.max_lifetime = 20.0
				b.stun_duration = def.get("web_stun", 1.5)
				if _web_tex != null:
					var sp = b.get_node_or_null("Sprite2D")
					if sp != null:
						sp.texture = _web_tex
						if def.has("web_px") and _web_tex.get_width() > 0:
							var tw: float = float(_web_tex.get_width())
							sp.scale = Vector2.ONE * (float(def["web_px"]) / tw)
				var cs = b.get_node_or_null("CollisionShape2D")
				if cs != null:
					var sz: float = 170.0 / 3.0
					var new_shape := RectangleShape2D.new()
					new_shape.size = Vector2(sz, sz)
					cs.shape = new_shape
				get_parent().add_child(b)
	# auto melee swipe (close-range boss)
	if _auto_melee_interval > 0.0:
		_auto_melee_timer -= delta
		if _auto_melee_timer <= 0.0:
			_auto_melee_timer = _auto_melee_interval
			var pl = get_tree().get_first_node_in_group("player")
			if is_instance_valid(pl):
				var dist: float = global_position.distance_to(pl.global_position)
				if dist <= _melee_trigger + 60.0:
					_melee_dir = (pl.global_position - global_position).normalized()
					_do_melee_swipe(pl)
	# auto burst fire (ranged boss phase 2)
	if _auto_burst_interval > 0.0:
		_auto_burst_timer -= delta
		if _auto_burst_timer <= 0.0:
			_auto_burst_timer = _auto_burst_interval
			var pl = get_tree().get_first_node_in_group("player")
			if is_instance_valid(pl):
				_burst_t = 1.5
				_burst_speed = def.get("bullet_speed", 340.0)
				_burst_dmg = def.get("bullet_dmg", 1.2)
		# auto charge (periodic dash toward player)
		if _charge_auto_interval > 0.0:
			_charge_auto_timer -= delta
			if _charge_auto_timer <= 0.0:
				_charge_auto_timer = _charge_auto_interval
				var pl = get_tree().get_first_node_in_group("player")
				if is_instance_valid(pl):
					_charge_dir = (pl.global_position - global_position).normalized()
					_charge_dist = _charge_auto_distance
					_charge_t = 0.42
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if _frozen or not is_instance_valid(player):
		velocity = Vector2.ZERO
		_reset_telegraph_visual()
		return

	# 距离环形 AI：按玩家距离决定环形弹幕节奏与狂暴状态
	if _ai_mode == "distance_ring":
		_distance_ring_tick(delta, player)

	# 阶段切换（含狂暴）—— distance_ring 模式由距离驱动，跳过 HP 阶段
	var ph: int = _phase()
	if _ai_mode != "distance_ring" and ph != _prev_phase:
		_on_phase_change(ph)
		_prev_phase = ph

	_update_attack(delta, player)
	_update_movement(delta, player)
	_update_contact(delta, player)
	_update_facing(player)

	if _astate == AState.TELEGRAPH or _spiral_t > 0.0 or _ai_mode == "distance_ring" or _auto_laser_telegraph > 0.0 or _auto_laser_flash > 0.0:
		queue_redraw()

# —— 阶段 ——
func _phase() -> int:
	# 两阶段：HP>50% 为阶段1；HP≤50% 进入阶段2（狂暴）
	return 1 if get_hp_ratio() > 0.5 else 2

func _on_phase_change(p: int) -> void:
	if p == 2 and not _enraged:
		_enraged = true

# —— 攻击状态机 ——
func _update_attack(delta: float, player: Node2D) -> void:
	match _astate:
		AState.IDLE:
			_atimer -= delta
			if _atimer <= 0.0:
				_choose_attack(player)
				if _pending != "":
					_astate = AState.TELEGRAPH
					_tele = _tele_dur
		AState.TELEGRAPH:
			_tele -= delta
			_tele_progress = 1.0 - clamp(_tele / _tele_dur, 0.0, 1.0)
			_apply_telegraph_visual()
			if _tele <= 0.0:
				_execute_attack(player)
				_astate = AState.RECOVER
				_atimer = _recover_dur
				_tele_progress = 0.0
				_reset_telegraph_visual()
		AState.RECOVER:
			# 冷却计时器（螺旋/激光用后即进入冷却）
			if _spiral_cooldown_timer > 0.0:
				_spiral_cooldown_timer -= delta
			if _laser_cooldown_timer > 0.0:
				_laser_cooldown_timer -= delta
			if _wave_cooldown_timer > 0.0:
				_wave_cooldown_timer -= delta
			if _spiral_t > 0.0:
				_update_spiral(delta)
			if _burst_t > 0.0:
				_update_burst(delta, player)
			if _charge_t > 0.0:
				_charge_t -= delta
			if _laser_t > 0.0:
				_laser_t -= delta
				if not _laser_use_new:
					_do_laser_hit(player)
			if _atimer <= 0.0:
				_astate = AState.IDLE

# —— 距离环形 AI：自动环形弹幕 + 定时冲撞 + 距离狂暴 ——
func _distance_ring_tick(delta: float, player: Node2D) -> void:
	if _dead: return
	var dist: float = global_position.distance_to(player.global_position)
	var is_close: bool = dist <= _ring_distance

	# 根据距离切换狂暴状态（影响移速、外观、弹幕节奏）
	if is_close and _enraged:
		_enraged = false
	elif not is_close and not _enraged:
		_enraged = true

	# 自动环形弹幕计时
	_ring_auto_timer -= delta
	if _ring_auto_timer <= 0.0:
		var interval: float = _ring_close_interval if is_close else _ring_far_interval
		var spd: float = _ring_close_speed if is_close else _ring_far_speed
		var dmg: float = _ring_close_dmg if is_close else _ring_far_dmg
		_fire_ring(_ring_auto_count, spd, dmg)
		_ring_auto_timer = interval
		_auto_ring_flash = 0.22  # 发射瞬间闪烁作为视觉反馈

	_auto_ring_flash = max(_auto_ring_flash - delta, 0.0)

	# 自动冲撞计时：到期立即执行，无视当前状态（确保冲撞稳定触发）
	_charge_auto_timer -= delta
	if _charge_auto_timer <= 0.0:
		_charge_auto_timer = _charge_auto_interval
		_pending = "charge"
		_charge_dir = (player.global_position - global_position).normalized()
		_charge_dist = _charge_auto_distance
		_tele_kind = "charge"
		_tele_dur = 0.8
		_recover_dur = 1.5 * _cd_mul()
		_astate = AState.TELEGRAPH
		_tele = _tele_dur
		_tele_progress = 0.0
		# 清理进行中的螺旋/连射
		_spiral_t = 0.0
		_burst_t = 0.0
func _choose_attack(player: Node2D) -> void:
	var pool: Array = _attack_pool()
	if pool.is_empty():
		_pending = ""
		_astate = AState.IDLE
		_atimer = 0.5
		return
	_pending = pool[randi() % pool.size()]
	var ph: int = _phase()
	match _pending:
		"ring":
			_tele_kind = "ring"; _tele_radius = 540.0
			_tele_dur = 0.8; _recover_dur = 2.0 * _cd_mul()
			_ring_count = 36
		"aimed":
			_tele_kind = "aimed"
			_tele_dur = 0.5; _recover_dur = 1.3 * _cd_mul()
		"spiral":
			_tele_kind = "spiral"
			_spiral_arms = _spiral_bullets  # 每圈子弹数（阿基米德螺旋）
			_tele_dur = 0.7; _recover_dur = _spiral_duration + 0.6  # 后摇=持续+余量
		"charge":
			_tele_kind = "charge"
			_charge_dir = (player.global_position - global_position).normalized()
			_tele_dur = 0.8; _recover_dur = 1.5 * _cd_mul()
		"melee":
			_tele_kind = "melee"
			_melee_dir = (player.global_position - global_position).normalized()
			_tele_dur = 0.28; _recover_dur = 0.8 * _cd_mul()
		"summon":
			_tele_kind = "summon"; _summon_n = 2 + ph
			_tele_dur = 0.6; _recover_dur = 2.0 * _cd_mul()
		"nova":
			_tele_kind = "nova"; _tele_radius = 580.0
			_tele_dur = 0.9; _recover_dur = 2.2 * _cd_mul()
		"burst":
			_tele_kind = "burst"; _tele_radius = 300.0
			_tele_dur = 0.7; _recover_dur = 1.9 * _cd_mul()
		"wave":
			_tele_kind = "wave"
			_wave_dir = (player.global_position - global_position).normalized()
			_tele_dur = 0.7; _recover_dur = 2.0 * _cd_mul()

		"laser":
			_tele_kind = "laser"
			_laser_dir = (player.global_position - global_position).normalized()
			if _laser_use_new:
				_tele_dur = _laser_telegraph_total  # 1.7s 长方形虚线预警
				_recover_dur = 0.5
			else:
				_laser_range = 800.0
				_laser_width = 48.0
				_tele_dur = 1.0; _recover_dur = 2.0 * _cd_mul()

func _attack_pool() -> Array:
	var pool: Array
	if _ai_mode == "distance_ring":
		if def.has("pool"):
			pool = def["pool"] as Array
		else:
			pool = ["aimed"]
	elif def.has("pool1") or def.has("pool2"):
		pool = (def.get("pool2") if _phase() == 2 else def.get("pool1")) as Array
	elif def.has("pool"):
		pool = def["pool"] as Array
	else:
		match _phase():
			1: pool = ["ring", "aimed"]
			_: pool = ["nova", "spiral", "charge", "aimed", "summon"]
	# 冷却过滤：移除正在冷却中的攻击
	if _spiral_cooldown_timer > 0.0 and pool.has("spiral"):
		pool.erase("spiral")
	if _laser_cooldown_timer > 0.0 and _laser_use_new and pool.has("laser"):
		pool.erase("laser")
	if _wave_cooldown_timer > 0.0 and pool.has("wave"):
		pool.erase("wave")
	return pool

func _cd_mul() -> float:
	if _ai_mode == "distance_ring":
		return 0.8  # 距离环形模式固定冷却倍率
	return 1.0 if _phase() == 1 else 0.55

func _execute_attack(player: Node2D) -> void:
	var ph: int = _phase()
	match _pending:
		"ring":
			_fire_ring(_ring_count, 200.0, 1.2)
		"aimed":
			_fire_aimed(4 + ph, 0.16, def.get("bullet_speed", 330.0), def.get("bullet_dmg", 1.2), player)
		"spiral":
			_spiral_t = _spiral_duration; _spiral_acc = 0.0
			_spiral_angle = randf_range(0.0, TAU)
			_spiral_speed = 260.0; _spiral_dmg = 1.0
			_spiral_arms = _spiral_bullets
			_spiral_cooldown_timer = _spiral_cooldown
		"charge":
			_charge_t = 0.42
		"melee":
			_do_melee_swipe(player)
		"summon":
			if WaveManager != null and WaveManager.has_method("spawn_minions"):
				WaveManager.spawn_minions(global_position, _summon_n)
		"nova":
			_fire_ring(26 + ph * 5, 275.0, 1.2)
			_fire_ring(26 + ph * 5, 330.0, 1.2, 0.5 * TAU / float(26 + ph * 5))
		"burst":
			_burst_t = 1.1 + 0.5 * float(ph)
			_burst_acc = 0.0
			_burst_speed = def.get("bullet_speed", 340.0)
			_burst_dmg = def.get("bullet_dmg", 1.2)
		"wave":
			_fire_wave(player)
			_wave_cooldown_timer = _wave_cooldown

		"laser":
			if _laser_use_new:
				_laser_t = 0.3  # 激光视觉残留
				_do_laser_rect_hit(player)
				_laser_cooldown_timer = _laser_cooldown
			else:
				_laser_t = 0.5   # 激光持续伤害0.5秒
				if not _laser_use_new:
					_do_laser_hit(player)

# —— 攻击原语 ——
func _fire_bullet(dir: Vector2, speed: float, dmg: float) -> void:
	if ENEMY_BULLET == null:
		return
	var b = ENEMY_BULLET.instantiate()
	b.global_position = global_position
	b.direction = dir.normalized()
	b.speed = speed
	b.damage = dmg
	b.max_lifetime = 20.0  # Boss 弹幕全屏射程，不提前消失
	# 可选：整体缩放根节点（会同时缩放碰撞盒，慎用）
	if def.has("bullet_scale"):
		b.scale = Vector2.ONE * float(def["bullet_scale"])
	# 该 BOSS 有专属弹幕贴图则换上，否则用通用 enemy_bullet
	if _bullet_tex != null:
		var sp = b.get_node_or_null("Sprite2D")
		if sp != null:
			sp.texture = _bullet_tex
			# 仅缩放贴图（不动根节点碰撞盒）：def["bullet_px"] 指定子弹在屏幕上的目标像素宽度
			var tw: float = float(_bullet_tex.get_width())
			if def.has("bullet_px") and tw > 0.0:
				var root_s: float = b.scale.x if b.scale.x != 0.0 else 1.0
				sp.scale = Vector2.ONE * (float(def["bullet_px"]) / (tw * root_s))
			# 专属贴图绘制朝向可能与飞行方向不一致，用 def["bullet_angle_offset"] 修正弹尖方向
			if def.has("bullet_angle_offset"):
				sp.rotation = float(def["bullet_angle_offset"])
	# 该 BOSS 有专属命中特效则传给子弹（命中玩家时播放 impact.png）
	if _impact_tex != null:
		b.impact_tex = _impact_tex
	get_parent().add_child(b)

func _fire_ring(n: int, speed: float, dmg: float, offset: float = 0.0) -> void:
	for i in n:
		var ang: float = TAU * float(i) / float(n) + offset
		_fire_bullet(Vector2(cos(ang), sin(ang)), speed, dmg)

func _fire_aimed(n: int, spread: float, speed: float, dmg: float, player: Node2D) -> void:
	var base: float = (player.global_position - global_position).angle()
	for i in n:
		var t: float = float(i) - float(n - 1) / 2.0
		var ang: float = base + t * spread
		_fire_bullet(Vector2(cos(ang), sin(ang)), speed, dmg)
# 弯刀弹幕：弧形子弹向玩家位置发射，像弯刀一样
func _fire_wave(player: Node2D) -> void:
	var base_ang: float = (player.global_position - global_position).angle()
	var n: int = _wave_bullets
	var spread: float = deg_to_rad(_wave_angle)  # 总扇形角度
	for i in n:
		var t: float = float(i) - float(n - 1) / 2.0
		var ang: float = base_ang + t * spread / float(max(n - 1, 1))
		var speed: float = _wave_speed
		# 边缘子弹稍慢，形成弯刀弧度
		var edge: float = abs(t) / max(float(n - 1) / 2.0, 1.0)
		speed *= (1.0 - edge * 0.3)
		_fire_bullet(Vector2(cos(ang), sin(ang)), speed, _wave_dmg)

func _update_spiral(delta: float) -> void:
	_spiral_t -= delta
	_spiral_acc += delta
	var progress: float = 1.0 - (_spiral_t / max(_spiral_duration, 0.1))  # 0→1 螺旋展开进度
	var max_offset: float = 480.0  # 最大偏移半径（海螺壳效果）
	while _spiral_acc >= _spiral_step:
		_spiral_acc -= _spiral_step
		for k in _spiral_arms:
			var ang: float = _spiral_angle + float(k) * TAU / float(_spiral_arms)
			var dir := Vector2(cos(ang), sin(ang))
			var offset: float = progress * max_offset
			if ENEMY_BULLET == null: continue
			var b = ENEMY_BULLET.instantiate()
			b.global_position = global_position + dir * offset  # 子弹从螺旋臂上射出
			b.direction = dir
			b.speed = _spiral_speed
			b.damage = _spiral_dmg
			b.max_lifetime = 20.0
			get_parent().add_child(b)

# 连射：后摇期内每 _burst_step 秒朝玩家当前方向打一发（实时追踪 + 轻微散布）
func _update_burst(delta: float, player: Node2D) -> void:
	_burst_t -= delta
	_burst_acc += delta
	while _burst_acc >= _burst_step:
		_burst_acc -= _burst_step
		if is_instance_valid(player):
			var base: float = (player.global_position - global_position).angle()
			var ang: float = base + randf_range(-_burst_spread, _burst_spread)
			_fire_bullet(Vector2(cos(ang), sin(ang)), _burst_speed, _burst_dmg)
		_spiral_angle += _spiral_rot

# —— 移动 ——
@warning_ignore("unused_parameter")
func _update_movement(delta: float, player: Node2D) -> void:
	if _astate == AState.TELEGRAPH:
		velocity = Vector2.ZERO          # 预警时站定，更易读
		move_and_slide()
		return
	if _charge_t > 0.0:
		velocity = _charge_dir * _charge_speed
		move_and_slide()
		return
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	var pool: Array = _attack_pool()
	# 近战型主动贴近；远程型保持中远距离风筝；其余维持偏好距离
	var pref: float = _preferred_range * (0.5 if _enraged else 1.0)
	if pool.has("melee") or _auto_melee_interval > 0.0:
		pref = (_melee_trigger + 15.0) * (0.75 if _enraged else 1.0)
	elif pool.has("burst") or pool.has("aimed") or _auto_aimed_interval > 0.0 or _auto_burst_interval > 0.0:
		pref = _preferred_range * (0.85 if _enraged else 1.1)   # 远程：狂暴也不贴脸
	var spd: float = _base_speed * (1.8 if _enraged else 1.0)
	if d > pref + 40.0:
		velocity = to.normalized() * spd
	elif d < pref - 40.0:
		velocity = -to.normalized() * spd * 0.8
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _update_contact(_delta: float, player: Node2D) -> void:
	if _charge_t > 0.0 and global_position.distance_to(player.global_position) <= _contact_range + 30.0:
		if _attack_timer <= 0.0 and player.has_method("take_damage"):
			var dir: Vector2 = (player.global_position - global_position).normalized()
			player.take_damage(touch_damage * 2.0, dir, KB_FORCE)
			_spawn_impact(player.global_position)
			_attack_timer = _attack_interval
		return
	if global_position.distance_to(player.global_position) <= _contact_range:
		if _attack_timer <= 0.0 and player.has_method("take_damage"):
			var dir: Vector2 = (player.global_position - global_position).normalized()
			player.take_damage(touch_damage, dir, KB_FORCE * 0.6)
			_spawn_impact(player.global_position)
			_attack_timer = _attack_interval

func _update_facing(player: Node2D) -> void:
	if _use_animated and anim_body.visible:
		anim_body.flip_h = player.global_position.x < global_position.x
		var target := "walk" if velocity.length() > 10.0 else "idle"
		if anim_body.animation != target: anim_body.play(target)
	elif body_sprite.visible:
		body_sprite.flip_h = player.global_position.x < global_position.x

# —— 近战挥砍 + 命中特效 ——
func _do_melee_swipe(player: Node2D) -> void:
	var to_p: Vector2 = (player.global_position - global_position)
	var d: float = to_p.length()
	if d <= _swipe_range and d > 0.0:
		var dir: Vector2 = to_p.normalized()
		# 仅命中挥砍方向前方的目标（定向挥砍，非全向 AoE）
		if dir.dot(_melee_dir) > 0.25:
			if player.has_method("take_damage"):
				player.take_damage(touch_damage * 1.8, dir, KB_FORCE)
			_spawn_impact(player.global_position)
	else:
		# 落空：在挥砍末端播特效作为反馈
		_spawn_impact(global_position + _melee_dir * _swipe_range)

# 激光伤害检测
func _do_laser_hit(player: Node2D) -> void:
	if not is_instance_valid(player): return
	var to_p := player.global_position - global_position
	var proj := to_p.dot(_laser_dir)
	if proj <= 0.0 or proj > _laser_range: return
	if (to_p - _laser_dir * proj).length() > _laser_width: return
	if player.has_method("take_damage"):
		player.take_damage(touch_damage * 1.5, _laser_dir, KB_FORCE * 0.5)
# 新版激光命中检测（长方形区域，瞬发伤害）
func _do_laser_rect_hit(player: Node2D) -> void:
	if not is_instance_valid(player): return
	var to_p := player.global_position - global_position
	var proj := to_p.dot(_laser_dir)
	if proj <= 0.0 or proj > _laser_length: return
	var perp_len := (to_p - _laser_dir * proj).length()
	if perp_len > _laser_width * 0.5: return
	if player.has_method("take_damage"):
		player.take_damage(_laser_damage, _laser_dir, KB_FORCE * 0.3)


func _spawn_impact(pos: Vector2) -> void:
	if _impact_tex == null:
		if FXManager != null:
			FXManager.spawn_hit_spark(pos)   # 无专属贴图时回退到全局受击火花
		return
	var s := Sprite2D.new()
	s.texture = _impact_tex
	s.global_position = pos
	s.centered = true
	s.z_index = 16
	s.scale = Vector2.ONE * 0.6
	get_parent().add_child(s)
	_fx_sprites.append(s)
	# 用树级补间（而非挂在 BOSS 上的补间），保证 BOSS 死亡销毁后特效仍能正常淡出回收
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 1.4, 0.18)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.34)
	tw.tween_callback(s.queue_free)

# —— 预警视觉 ——
func _apply_telegraph_visual() -> void:
	var a: float = _tele_progress
	if body_sprite.visible:
		body_sprite.scale = Vector2.ONE * _body_base_scale * (1.0 + 0.12 * a)
		if _enraged:
			body_sprite.modulate = Color(1.0, 0.5 - 0.3 * a, 0.5 - 0.3 * a)
		else:
			body_sprite.modulate = Color(1.0, 1.0 - 0.25 * a, 1.0 - 0.25 * a)
	# 专属预警贴图：作为"圈"在脚下脉动（冲锋/近战/连射均显示）；线/扇形由 _draw 代码绘制
	if _tele_sprite != null and (_tele_kind == "charge" or _tele_kind == "melee" or _tele_kind == "burst"):
		_tele_sprite.visible = true
		var s: float = 0.6 + 0.4 * a
		if _tele_tex != null and _tele_tex.get_height() > 0:
			s *= clamp(150.0 / float(_tele_tex.get_height()), 0.2, 4.0)
		_tele_sprite.scale = Vector2.ONE * s
		_tele_sprite.modulate.a = 0.35 + 0.5 * a

func _reset_telegraph_visual() -> void:
	if body_sprite.visible:
		body_sprite.scale = Vector2.ONE * _body_base_scale
		body_sprite.modulate = Color.WHITE
	if _tele_sprite != null:
		_tele_sprite.visible = false
		_tele_sprite.modulate.a = 1.0

func _draw() -> void:
	# 距离环形模式：常驻显示判定圈（红圈），方便玩家识别近/远边界
	if _ai_mode == "distance_ring" and not _dead:
		var alpha: float = 0.15
		var col: Color = Color(1.0, 0.22, 0.18, alpha) if not _enraged else Color(1.0, 0.12, 0.04, alpha + 0.10)
		draw_arc(Vector2.ZERO, _ring_distance, 0.0, TAU, 64, col, 2.5)
		# 狂暴模式外圈额外一圈警示
		if _enraged:
			draw_arc(Vector2.ZERO, _ring_distance + 14.0, 0.0, TAU, 64, Color(1.0, 0.35, 0.1, 0.12), 1.5)
	# 自动环形弹幕闪烁反馈
	if _auto_ring_flash > 0.0:
		var fa: float = _auto_ring_flash / 0.22
		draw_arc(Vector2.ZERO, 210.0, 0.0, TAU, 36, Color(1.0, 0.5, 0.2, 0.50 * fa), 3.0)
	# auto laser telegraph - faint red dashed
	if _auto_laser_telegraph > 0.0:
		var hw: float = _laser_width * 0.5
		var end: Vector2 = _auto_laser_dir * _laser_length
		var perp: Vector2 = Vector2(-_auto_laser_dir.y, _auto_laser_dir.x)
		var alpha: float = 0.35 + 0.25 * sin(_auto_laser_telegraph * 12.0)
		var col: Color = Color(1.0, 0.25, 0.15, alpha)
		draw_line(Vector2.ZERO + perp*hw, end + perp*hw, col, 2.0)
		draw_line(Vector2.ZERO - perp*hw, end - perp*hw, col, 2.0)
		draw_line(Vector2.ZERO - perp*hw, Vector2.ZERO + perp*hw, col, 2.0)
		draw_line(end - perp*hw, end + perp*hw, col, 2.0)
	# auto laser flash - deep red filled
	if _auto_laser_flash > 0.0:
		var hw2: float = _laser_width * 0.5
		var end2: Vector2 = _auto_laser_dir * _laser_length
		var perp2: Vector2 = Vector2(-_auto_laser_dir.y, _auto_laser_dir.x)
		var remain: float = _auto_laser_flash / 0.3
		var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO+perp2*hw2, end2+perp2*hw2, end2-perp2*hw2, Vector2.ZERO-perp2*hw2])
		draw_colored_polygon(pts, Color(1.0, 0.02, 0.01, 0.40 * remain))
		var col2: Color = Color(1.0, 0.04, 0.01, 0.85 * remain)
		draw_line(Vector2.ZERO + perp2*hw2, end2 + perp2*hw2, col2, 5.0)
		draw_line(Vector2.ZERO - perp2*hw2, end2 - perp2*hw2, col2, 5.0)
		draw_line(Vector2.ZERO - perp2*hw2, Vector2.ZERO + perp2*hw2, col2, 5.0)
		draw_line(end2 - perp2*hw2, end2 + perp2*hw2, col2, 5.0)
	if _astate != AState.TELEGRAPH:
		return
	var a: float = _tele_progress
	match _tele_kind:
		"ring", "nova":
			draw_arc(Vector2.ZERO, _tele_radius, 0.0, TAU, 56,
				Color(1.0, 0.3, 0.3, 0.20 + 0.40 * a), 4.0)
			draw_arc(Vector2.ZERO, _tele_radius * (1.0 - a), 0.0, TAU, 56,
				Color(1.0, 0.6, 0.3, 0.55), 2.0)
		"melee":
			# 朝锁定方向的扇形，提示定向挥砍范围
			var base_ang: float = _melee_dir.angle()
			var half: float = 0.6
			draw_arc(Vector2.ZERO, 64.0, base_ang - half, base_ang + half, 20,
				Color(1.0, 0.45, 0.2, 0.30 + 0.45 * a), 6.0)
		"charge":
			var end: Vector2 = _charge_dir * _charge_dist
			draw_line(Vector2.ZERO, end, Color(1.0, 0.3, 0.3, 0.25 + 0.5 * a), 7.0)
		"spiral", "summon":
			var col: Color = Color(1.0, 0.5, 0.2, 0.4 + 0.4 * a) if _tele_kind == "spiral" else Color(0.6, 0.4, 1.0, 0.4 + 0.4 * a)
			draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 40, col, 3.0)
		"burst":
			draw_arc(Vector2.ZERO, _tele_radius, 0.0, TAU, 48,
				Color(0.30, 0.60, 1.0, 0.20 + 0.40 * a), 4.0)
			draw_arc(Vector2.ZERO, _tele_radius * (1.0 - a), 0.0, TAU, 48,
				Color(0.45, 0.80, 1.0, 0.55), 2.0)

		"wave":
			var base_ang: float = _wave_dir.angle()
			var half: float = deg_to_rad(_wave_angle * 0.5)
			draw_arc(Vector2.ZERO, 130.0, base_ang - half, base_ang + half, 24,
				Color(0.30, 0.80, 0.50, 0.30 + 0.45 * a), 5.0)

		"laser":
			if _laser_use_new:
				# 新版：红色长方形预警（高亮 + 半透明填充）
				var t: float = _tele_progress
				var warn_end: float = _laser_warning_dur / _laser_telegraph_total
				var is_react: bool = t >= warn_end
				var alpha: float = 0.55 + 0.3 * t
				var col := Color(1.0, 0.12, 0.04, alpha)
				if is_react:
					col.a = 0.6 + 0.4 * sin(_tele * 14.0)
				var hw := _laser_width * 0.5
				var end := _laser_dir * _laser_length
				var perp := Vector2(-_laser_dir.y, _laser_dir.x)
				# 半透明红色填充
				var pts := PackedVector2Array([Vector2.ZERO+perp*hw, end+perp*hw, end-perp*hw, Vector2.ZERO-perp*hw])
				draw_colored_polygon(pts, Color(1.0, 0.06, 0.02, alpha * 0.20))
				# 四条边框
				draw_line(Vector2.ZERO + perp*hw, end + perp*hw, col, 4.0)
				draw_line(Vector2.ZERO - perp*hw, end - perp*hw, col, 4.0)
				draw_line(Vector2.ZERO - perp*hw, Vector2.ZERO + perp*hw, col, 4.0)
				draw_line(end - perp*hw, end + perp*hw, col, 4.0)
			else:
				var end := _laser_dir * _laser_range
				draw_line(Vector2.ZERO, end, Color(1.0, 0.2, 0.2, 0.15 + 0.6 * a), _laser_width * 0.5)
				draw_line(Vector2.ZERO, end, Color(1.0, 0.4, 0.1, 0.6 * a), 3.0)

# —— 受伤 / 死亡 ——
func take_damage(amount: float, is_crit: bool = false) -> void:
	if _dead:
		return
	hp -= amount
	if _use_animated and anim_body.sprite_frames != null and anim_body.sprite_frames.has_animation("hurt"):
		anim_body.play("hurt")
	if _hit_fx_timer <= 0.0 and FXManager != null:
		FXManager.spawn_hit_spark(global_position, 2.4)
		# 受击数字从「头顶」出现（head_offset 为头顶上方偏移），原地出现后淡出
		FXManager.spawn_damage_number(global_position + Vector2(0.0, head_offset), amount)
		_hit_fx_timer = 0.08
	if hp <= 0.0:
		_die()

func get_hp_ratio() -> float:
	return clamp(hp / _max_hp, 0.0, 1.0)

# 时空沙漏：冻结移动与攻击，但仍可被伤害
func set_frozen(v: bool) -> void:
	_frozen = v
	if body_sprite.visible:
		body_sprite.modulate = Color(0.55, 0.75, 1.0) if v else Color.WHITE

func _die() -> void:
	_dead = true
	if _use_animated and anim_body.sprite_frames != null and anim_body.sprite_frames.has_animation("death"):
		anim_body.play("death")
	_dead_state_cleanup()
	velocity = Vector2.ZERO
	if FXManager != null:
		FXManager.spawn_death_poof(global_position, 2.6)
	if RunStats != null:
		RunStats.boss_ref = null
		RunStats.boss_defeated.emit()
		RunStats.add_kill()
	var pl: Node2D = get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("heal"):
		pl.heal(3.0)
	_drop_loot()
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var cs = get_node_or_null("CollisionShape2D")
	if cs != null:
		cs.set_deferred("disabled", true)
	queue_free()

# 复位所有攻击/预警状态，并回收挂在世界上的命中特效精灵，避免残影留在屏幕
func _dead_state_cleanup() -> void:
	_astate = AState.IDLE
	_spiral_t = 0.0
	_charge_t = 0.0
	_burst_t = 0.0
	_tele_kind = ""
	_pending = ""
	_reset_telegraph_visual()
	for s in _fx_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_fx_sprites.clear()

func _drop_loot() -> void:
	var orb = EXP_ORB_SCENE.instantiate()
	orb.global_position = global_position
	orb.exp_value = exp_value
	get_parent().add_child(orb)
	# BOSS连战：必定掉血瓶
	if RunStats != null and RunStats.game_mode == "level" and RunStats.selected_level_id == "level_06":
		var hb = preload("res://Assets/Sprites/Pickups/health_bottle.tscn").instantiate()
		hb.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		get_parent().add_child(hb)
