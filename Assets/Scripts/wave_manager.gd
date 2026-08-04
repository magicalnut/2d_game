extends Node

## 波次系统（AutoLoad 单例）：按配置逐波"滴流"生成敌人（持续涌来、屏幕始终被填满），
## 清空一波后自动进入下一波。每种敌人有不同"角色分工"，生成时覆盖到 enemy.gd 的导出项。
##
## 玩法目标：营造"消灭人海"的割草爽感 —— 前期脆皮狼海让你体验清屏，
## 后期重甲/壮汉/远程混编制造压力。同屏存活上限(max_alive)保证既满又流畅。

# 各敌人角色场景（动态生成，不依赖主场景里的静态实例）
const ENEMY_SCENES := {
	"fox":     preload("res://Assets/Sprites/Enemies/Fox/fox.tscn"),
	"agent":   preload("res://Assets/Sprites/Enemies/Agent/agent.tscn"),
	"mario":   preload("res://Assets/Sprites/Enemies/Mario/mario.tscn"),
	"armored": preload("res://Assets/Sprites/Enemies/ArmoredPerson/armored_person.tscn"),
}

# 角色分工：fox=快速脆皮斥候(海)，agent=远程射手，mario=高血量壮汉，armored=慢速重甲坦克
# 移速已是"慢速基准值"（玩家反馈原速太快，已下调 ~25%~30%）。
# ⚠️ 关键：移速恒为下方基准值，绝不被难度倍率(_difficulty)抬升 ——
#    "人海"的压力全部来自【数量/密度】，而非移速。这样阶段推进后敌人依旧慢，
#    但屏幕上永远挤满，营造割草爽感。
const ENEMY_ROLES := {
	"fox":     {"hp": 2.0,  "speed": 190.0,  "touch_damage": 1.0},
	"agent":   {"hp": 3.0, "speed": 136.0,  "touch_damage": 1.0, "ranged": true, "fire_range": 560.0, "preferred_range": 360.0, "fire_rate": 1.5, "bullet_damage": 1.0, "bullet_speed": 600.0},
	"mario":   {"hp": 5.0,  "speed": 104.0,  "touch_damage": 1.0},
	"armored": {"hp": 10.0, "speed": 76.0,  "touch_damage": 2.0},
}

# 预设波次(WAVES)已移除：战斗一开始即进入程序化无尽模式（详见 _on_wave_cleared / _start_next_wave 的 _endless 直启逻辑）。
# 无尽波次由 _build_endless_wave() 按「层数 _endless_stage + 层内进度」程序化生成，难度随层数与存活时间平滑上升。

const ENEMY_SCRIPT := preload("res://Assets/Scripts/enemy.gd")
const ENEMY_BULLET_SCENE := preload("res://Assets/Sprites/Weapons/Bullet/enemy_bullet.tscn")
const BOSS_SCENE := preload("res://Assets/Sprites/Bosses/boss.tscn")

# 5 个独立 BOSS 定义；无尽模式每 5 波随机挑一只降临。
# 素材统一放：Boss/BossN/{Body,Bullets,Telegraphs,Impacts}/*.png
#   Body=本体立绘  Bullets=弹幕外观  Telegraphs=预警圈/线  Impacts=命中/爆炸
# 字段：name 名称 / tint 无素材时占位圆颜色 / hp 基础血量 / 其余见各 path/bullet/telegraph/impact 键
#       speed 移速 / touch 接触伤害 / exp 经验 / pool 该BOSS偏好的攻击组（可选，缺省用通用池）
const BOSS_DEFS: Array = [
	{"name":"老赛",   "tint":Color(0.90,0.22,0.20), "hp":1500.0, "speed":240.0, "touch":4.0, "exp":45.0, "pool":[], "auto_melee_interval":0.8, "auto_charge_interval":4.0, "charge_distance":700.0,
	 "path":"res://Assets/Sprites/Bosses/Boss1/Body/body.png",
	 "bullet_px":30.0, "bullet":"res://Assets/Sprites/Bosses/Boss1/Bullets/bullet.png",
	 "telegraph":"res://Assets/Sprites/Bosses/Boss1/Telegraphs/telegraph.png",
	 "impact":"res://Assets/Sprites/Bosses/Boss1/Impacts/impact.png"},
	{"name":"德牧蓝",   "tint":Color(0.30,0.55,0.95), "hp":1800.0, "speed":100.0, "touch":4.0, "exp":45.0, "pool":[], "auto_aimed_interval":0.8, "auto_burst_interval":2.5, "bullet_speed":500.0, "bullet_dmg":3.0,
	 "path":"res://Assets/Sprites/Bosses/Boss2/Body/body.png",
	 "bullet":"res://Assets/Sprites/Bosses/Boss2/Bullets/bullet.png", "bullet_px":38.0, "bullet_angle_offset":PI/4,
	 "telegraph":"res://Assets/Sprites/Bosses/Boss2/Telegraphs/telegraph.png",
	 "impact":"res://Assets/Sprites/Bosses/Boss2/Impacts/impact.png"},
	# 用户Boss3 - 暗影守卫 (HP 700, 瞄准射击, 5帧动画)
	{"name":"暗影守卫",   "tint":Color(0.20,0.50,0.30), "hp":700.0, "speed":80.0, "touch":2.5, "exp":30.0,
	 "pool":[], "auto_aimed_interval":1.0, "web_interval":5.0, "web_tex":"res://Assets/Sprites/Bosses/Boss3/Bullets/zhuwang_ding.png", "web_px":150.0, "web_damage":0.5, "web_speed":600.0, "web_stun":1.5, "bullet_px":30.0, "bullet":"res://Assets/Sprites/Bosses/Boss3/Bullets/spider_web.png", "bullet_speed":400.0, "path":"res://Assets/Sprites/Bosses/Boss3/Body/frame_01.png",
	 "animated":true, "frames_dir":"res://Assets/Sprites/Bosses/Boss3/Body/"},
	# 用户Boss4 - 深渊领主 (HP 900, 距离环形AI, 4帧翅膀动画)
		{"name":"深渊领主",   "tint":Color(0.70,0.30,0.20), "hp":900.0, "speed":80.0, "touch":3.5, "exp":38.0,
	 "ai_mode":"distance_ring", "ring_distance":500.0, "ring_count":36,
	 "ring_close_interval":1.5, "ring_close_speed":120.0, "ring_close_dmg":0.5,
	 "ring_far_interval":1.0, "ring_far_speed":180.0, "ring_far_dmg":1.0,
	 "charge_interval":5.0, "charge_distance":700.0, "pool":["aimed"],
	 "path":"res://Assets/Sprites/Bosses/Boss4/Body/frame_01.png",
	 "animated":true, "frames_dir":"res://Assets/Sprites/Bosses/Boss4/Body/"},
		# 用户Boss5 - 虚空霸主 (HP 1100, 激光专精)
		{"name":"虚空霸主",   "tint":Color(0.50,0.20,0.60), "hp":1100.0, "speed":100.0, "touch":4.0, "exp":45.0,
		 "pool":[], "bullet":"res://Assets/Sprites/Bosses/Boss5/Bullet/huoyanqiu.png", "bullet_px":60.0, "auto_laser_interval":3.0, "ringseq_interval":0.1, "ringseq_damage":1.5, "ringseq_speed":290.0, "sickle_interval":5.0, "sickle_tex":"res://Assets/Sprites/Bosses/Boss5/Bullet/huoyanliandao.png", "sickle_px":150.0, "sickle_damage":3.0, "sickle_spin":6.283, "sickle_speed":300.0,
		 "laser_telegraph":0.7, "laser_warning":0.0, "laser_react":0.7,
		 "laser_length":4500.0, "laser_width":48.0, "laser_damage":5.0, "laser_cooldown":3.0,
	 "path":"res://Assets/Sprites/Bosses/Boss5/Body/frame_01.png",
		 "animated":true, "frames_dir":"res://Assets/Sprites/Bosses/Boss5/Body/"},
]
var _last_boss_index: int = -1
var _boss_defeat_count: int = 0
var level_mode_active: bool = false
var _current_stage_config: Dictionary = {}
var _level_stage_repeating: bool = false
const _BOSS_ORDER: Array = [2, 3, 4, 0, 1]  # 暗影守卫/深渊领主/虚空霸主/老赛/德牧蓝

@export var map_width: float = 5088.0
@export var map_height: float = 2784.0
@export var edge_margin: float = 10.0             # 离地图边缘的安全距离
@export var spawn_ring_min: float = 460.0          # 生成环：离玩家的最小半径
@export var spawn_ring_max: float = 700.0          # 生成环：离玩家的最大半径
@export var inter_wave_delay: float = 3.0          # 两波之间的间隔（秒）
@export var first_wave_delay: float = 1.5          # 开局到第一波的延迟（秒）

enum State { INTERMISSION, FIGHTING, VICTORY, BOSS_FIGHT }

# 击败 BOSS（每累计清满 5 波降临一次）后触发一次特殊技能选择（SpecialSelectUI 监听）
signal special_choice_ready
signal stage_spawn_done  # 关卡模式：当前阶段敌人已全部生成完毕
var _state: int = State.INTERMISSION
var skip_reset: bool = false
var _wave_index: int = -1
var _endless: bool = false          # 第5波清完后进入无尽模式（持续刷最后一波）
var _timer: float = 0.0
var _player: Node2D = null
var _banner: Label = null
var _banner_timer: float = 0.0

# 当前波的生成组运行状态：{kind, remaining, interval, timer}
var _groups: Array = []
var _max_alive: int = 60
var _endless_stage: int = 0     # 无尽模式当前层（每击败一只 BOSS +1，主难度驱动）
var _endless_wave_count: int = 0   # 进入无尽后已清掉的波数（每 5 触发特殊选择）
var _waves_cleared: int = 0        # 本局累计清波数（统计用）
var _run_time: float = 0.0     # 本局已存活时间（秒），用于难度递增
var _difficulty: float = 1.0   # 难度倍率（敌人 hp/speed 倍率、同屏上限增幅）
var _last_scene: Node = null   # 用于检测场景重载（玩家死亡重开）以重置状态
var _crystal_defense_elapsed: float = 0.0  # 水晶防御模式已过去时间
var _kill_boss_timer: float = 0.0          # kill_boss关卡BOSS计时器
var _kill_boss_boss_spawned: bool = false  # kill_boss关卡BOSS是否已生成
var _boss_rush_kills: int = 0              # BOSS连战：已击败BOSS数
var _boss_rush_total: int = 5              # BOSS连战：总共BOSS数
var _boss_rush_active: bool = false        # BOSS连战模式激活
var _boss_rush_timer: float = 0.0          # BOSS连战：小怪阶段计时器
var _boss_rush_boss_phase: bool = false    # BOSS连战：是否进入BOSS阶段

func _ready() -> void:
	_create_banner()
	_timer = first_wave_delay

# 场景被重新加载时（玩家死亡 -> reload_current_scene），AutoLoad 不会自动重置，
# 这里检测到 current_scene 变化就重置整套波次状态，避免卡在旧波次。
func _ensure_fresh_scene() -> void:
	var cs: Node = get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		if cs != null and cs.name == "Main":
			if skip_reset:
				skip_reset = false
				return
			_wave_index = -1
			# 关键：以下累计量原本漏重置，导致「新开一局却继承上一局的层数/波数/难度」——
			# 新档一进场就是「无尽 · 第 N 层」、难度倍率残留，玩家瞬间被秒。必须一并清零。
			_endless_stage = 0
			_endless_wave_count = 0
			_waves_cleared = 0
			_boss_defeat_count = 0
			_run_time = 0.0
			_level_stage_repeating = false
			_boss_rush_timer = 0.0
			_boss_rush_boss_phase = false
			_current_stage_config = {}
			if RunStats != null:
				RunStats.last_wave_reached = 0
			var is_level: bool = RunStats != null and RunStats.game_mode == "level"
			if is_level:
				level_mode_active = true
				_endless = false
				_difficulty = 1.0 + RunStats.get_difficulty_base()
			else:
				level_mode_active = false
				_endless = true
				_state = State.INTERMISSION
				_timer = first_wave_delay
				_groups.clear()
				_max_alive = 60
				_difficulty = 1.0 + RunStats.get_difficulty_base()
		if _banner != null:
			_banner.visible = false
		_banner_timer = 0.0

func _create_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.modulate = Color(1.0, 0.85, 0.5)
	_banner.visible = false
	layer.add_child(_banner)

func _physics_process(delta: float) -> void:
	_ensure_fresh_scene()
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner != null:
			_banner.visible = false

	if level_mode_active:
		# kill_boss关卡：5分钟后生成BOSS
		if _current_stage_config.get("objective_type", "") == "kill_boss" and not _kill_boss_boss_spawned:
			_kill_boss_timer += delta
			if _kill_boss_timer >= 300.0:
				_kill_boss_boss_spawned = true
				_enter_boss_fight()
		# BOSS连战：1分钟后进入BOSS阶段
		if _boss_rush_active and not _boss_rush_boss_phase:
			_boss_rush_timer += delta
			if _boss_rush_timer >= 60.0:
				_boss_rush_boss_phase = true
				_groups.clear()
				_spawn_next_boss_rush_boss()
		match _state:
			State.FIGHTING:
				# kill_boss关卡BOSS已生成后停止刷小兵
				if _kill_boss_boss_spawned:
					pass
				else:
					_drip_spawn(delta)
				if _level_stage_repeating and not _current_stage_config.is_empty() and _current_stage_config.get("objective_type", "") == "protect_target":
					pass  # 水晶防御：由 _update_crystal_defense_difficulty 动态管理，不重置
				elif _level_stage_repeating and not _kill_boss_boss_spawned and _count_total() < 30:
					_setup_level_stage_groups(_current_stage_config)
				# BOSS连战：不触发普通清波完成，由BOSS击败计数控制
				if not _boss_rush_active and _all_groups_done() and get_tree().get_nodes_in_group("enemy").size() == 0:
					_on_wave_cleared()
			State.BOSS_FIGHT:
				if _boss_count() == 0:
					_on_boss_defeated()
		return

	# 存活时间累计（暂停时本节点随树暂停，自然冻结）；难度随存活时间递增
	_run_time += delta
	_difficulty = min(1.0 + RunStats.get_difficulty_base() + _endless_stage * 0.30 + _run_time / 240.0, 6.0)

	match _state:
		State.INTERMISSION:
			_timer -= delta
			if _timer <= 0.0:
				_start_next_wave()
		State.FIGHTING:
			_drip_spawn(delta)
			if _all_groups_done() and get_tree().get_nodes_in_group("enemy").size() == 0:
				_on_wave_cleared()
			# 安全阀：超过90秒未清波则强制推进
			_timer -= delta
			if _timer <= -90.0:
				print("[WaveManager] 安全阀触发：强制清波")
				_on_wave_cleared()
		State.BOSS_FIGHT:
			# BOSS 战：只等 BOSS 被击败（场上 boss 数归零），期间不刷普通敌潮
			if _boss_count() == 0:
				_on_boss_defeated()
		State.VICTORY:
			pass

func _drip_spawn(delta: float) -> void:
	var alive := get_tree().get_nodes_in_group("enemy").size()
	# 水晶防御模式：随时间递增难度
	if level_mode_active and _level_stage_repeating:
		_crystal_defense_elapsed += delta
		_update_crystal_defense_difficulty()
	# 水晶防御：每组每次可刷多只（慢慢递增）
	var multi: int = 1
	if level_mode_active and _level_stage_repeating:
		multi = min(2, 1 + int(_crystal_defense_elapsed / 60.0))
	for grp in _groups:
		if grp["remaining"] <= 0:
			continue
		grp["timer"] -= delta
		if grp["timer"] <= 0.0 and alive < _max_alive:
			for _i in multi:
				if alive >= _max_alive:
					break
				_spawn_one(grp["kind"])
				grp["remaining"] -= 1
				alive += 1
			grp["timer"] = grp["interval"]

func _update_crystal_defense_difficulty() -> void:
	var t: float = _crystal_defense_elapsed
	# 慢慢递增：每30秒一个阶段
	var phase: int = int(t / 30.0)
	# 狐狸开局，壮汉30秒，重甲60秒，射手90秒
	var types: Array[String] = ["fox"]
	if phase >= 1:
		types.append("mario")
	if phase >= 2:
		types.append("armored")
	if phase >= 3:
		types.append("agent")
	# 检查是否需要添加新的敌人组
	var existing_kinds: Array = []
	for grp in _groups:
		existing_kinds.append(grp["kind"])
	for kind in types:
		if not existing_kinds.has(kind):
			_groups.append({
				"kind": kind,
				"remaining": 99999,
				"interval": max(0.8, 2.0 - phase * 0.15),
				"timer": 0.0,
			})
	# 逐步缩短生成间隔（后期放缓）
	var base_interval: float = max(0.8, 2.0 - phase * 0.15)
	for grp in _groups:
		grp["interval"] = base_interval

func _all_groups_done() -> bool:
	for grp in _groups:
		if grp["remaining"] > 0:
			return false
	return true

func _count_total() -> int:
	var s := 0
	for grp in _groups:
		s += grp["remaining"]
	return s

func _enter_intermission() -> void:
	_state = State.INTERMISSION
	_timer = inter_wave_delay
	var next := _wave_index + 2   # 即将开始的是第几波
	_show_banner("下一波 %d / 5" % next, 2.0)

# 每层最后一波 → BOSS 降临（层内波数由 _build_endless_wave 决定，默认 5 波/层）
const _WAVES_PER_LAYER: int = 5
func _on_wave_cleared() -> void:
	if level_mode_active:
		stage_spawn_done.emit()
		if _level_stage_repeating and not _current_stage_config.is_empty():
			_restart_level_stage()
		return
	_waves_cleared += 1
	_endless_wave_count += 1
	if _endless_wave_count % _WAVES_PER_LAYER == 0:
		_enter_boss_fight()
	else:
		_enter_endless_intermission()

# 进入 BOSS 战：刷出 BOSS，切到 BOSS_FIGHT 状态，专心等它被击败
func _enter_boss_fight() -> void:
	_state = State.BOSS_FIGHT
	if AudioManager != null:
		AudioManager.play_boss_music()
	_spawn_boss()

# BOSS 被击败：给一次特殊技能选择，然后继续下一波（无尽间歇）
func _on_boss_defeated() -> void:
	_boss_defeat_count += 1
	emit_signal("special_choice_ready")
	if AudioManager != null:
		AudioManager.stop_boss_music()
	if level_mode_active:
		# BOSS连战：击败一只后刷下一只
		if _boss_rush_active:
			_boss_rush_kills += 1
			if _boss_rush_kills >= _boss_rush_total:
				# 全部击败：通关
				_calc_boss_rush_level_stars()
				_state = State.VICTORY
				stage_spawn_done.emit()
			else:
				# 还有BOSS：刷下一只
				_spawn_next_boss_rush_boss()
			return
		# 猎杀行动
		if _current_stage_config.get("objective_type", "") == "kill_boss":
			_calc_boss_rush_stars()
		_state = State.VICTORY
		stage_spawn_done.emit()
		return
	if _endless:
		_endless_stage += 1
		_enter_endless_intermission()
	else:
		_enter_intermission()

# 无尽模式后续每一波清完后的间歇（与首次进入无尽区分开，便于累计波数）
func _enter_endless_intermission() -> void:
	_state = State.INTERMISSION
	_timer = inter_wave_delay
	_show_banner("无尽 · 第 %d 层" % (_endless_stage + 1), 2.5)

func _start_next_wave() -> void:
	_wave_index += 1
	# 更新 RunStats 波次记录
	if RunStats != null:
		RunStats.last_wave_reached = _wave_index + 1   # 1-based 波次
	# 始终处于无尽模式：直接用程序化生成的波次（按层数与层内进度缩放）
	var wave: Dictionary = _build_endless_wave()
	_max_alive = int(wave.get("max_alive", 60))
	_groups.clear()
	for g in wave["groups"]:
		_groups.append({
			"kind": g["kind"],
			"remaining": int(g["count"]),
			"interval": float(g["interval"]),
			"timer": 0.0,
		})
	# 开局先砸一批(burst)，制造即时压迫感
	for gi in range(_groups.size()):
		var g: Dictionary = wave["groups"][gi]
		var b: int = int(g.get("burst", 0))
		var n: int = mini(b, _groups[gi]["remaining"])
		for k in n:
			_spawn_one(_groups[gi]["kind"])
			_groups[gi]["remaining"] -= 1
		_groups[gi]["timer"] = _groups[gi]["interval"]
	_state = State.FIGHTING
	_timer = 0.0  # 重置安全阀计时
	_show_banner(wave["name"], 2.2)

# 无尽模式：按"当前层(_endless_stage) + 层内进度"程序化生成一波，
# 取代原先"永远重复最后一波"的糟糕设计。层数主驱动难度，层内逐波小幅升压。
func _build_endless_wave() -> Dictionary:
	var s: int = _endless_stage
	var ew: int = _endless_wave_count + 1       # 进入无尽后的第几波（1-based），用已清波数+1 避免负索引
	var within: int = (ew - 1) % 5              # 层内进度 0..4
	var ramp: float = 1.0 + within * 0.12       # 层内逐波小幅升压
	var fox_n: int = int((42 + s * 16) * ramp)
	var mario_n: int = int((4 + s * 6) * ramp)
	var armored_n: int = int((2 + s * 4) * ramp)
	var agent_n: int = int((2 + s * 4) * ramp)
	var groups: Array = []
	groups.append({"kind":"fox", "count": fox_n,
		"interval": max(0.10, 0.26 - s * 0.012 - within * 0.005),
		"burst": int(12 + s * 2 + within * 2)})
	if s >= 1 or within >= 1:
		groups.append({"kind":"mario", "count": mario_n,
			"interval": max(0.40, 0.70 - s * 0.03), "burst": int(2 + s)})
	if s >= 1:
		groups.append({"kind":"agent", "count": agent_n,
			"interval": max(0.50, 1.00 - s * 0.03), "burst": int(1 + s / 2)})
	if s >= 2 or within >= 3:
		groups.append({"kind":"armored", "count": armored_n,
			"interval": max(0.50, 0.90 - s * 0.03), "burst": int(1 + s / 2)})
	var max_alive: int = mini(int(55 + s * 20 + within * 6), 240)
	return {"name":"无尽 · 第 %d 层 · 第 %d 波" % [s + 1, within + 1], "max_alive": max_alive, "groups": groups}

func _spawn_one(kind: String) -> void:
	var scene: PackedScene = ENEMY_SCENES.get(kind)
	if scene == null:
		return
	var e = scene.instantiate()
	e.set_script(ENEMY_SCRIPT)
	var role: Dictionary = ENEMY_ROLES.get(kind, {})
	# ⚠️ 移速 = 基准值，绝不乘 _difficulty。阶段推进后敌人依旧慢 → "人海"全靠数量。
	if role.has("hp"):           e.hp = role["hp"] * _difficulty        # 血量随难度微增，保持挑战
	if role.has("speed"):        e.speed = role["speed"]                # 移速恒定，不受难度影响
	if role.has("touch_damage"): e.touch_damage = role["touch_damage"]
	if role.has("ranged"):          e.ranged = role["ranged"]
	if role.has("stationary"):      e.stationary = role["stationary"]
	if role.has("fire_range"):      e.fire_range = role["fire_range"]
	if role.has("preferred_range"): e.preferred_range = role["preferred_range"]
	if role.has("fire_rate"):       e.fire_rate = role["fire_rate"]
	if role.has("bullet_damage"):   e.bullet_damage = role["bullet_damage"]
	if role.has("bullet_speed"):    e.bullet_speed = role["bullet_speed"]
	if role.has("ranged") and role["ranged"]:
		e.bullet_scene = ENEMY_BULLET_SCENE
	# fox / mario 精灵图只有右向行走素材，向左走时需水平镜像
	if kind == "fox" or kind == "mario":
		e.flip_left_walk = true
	e.global_position = _pick_spawn_pos()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(e)

# 当前场上存活的 BOSS 数量（用于避免重复刷）
func _boss_count() -> int:
	var c: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("get") and e.get("boss") == true:
			c += 1
	return c


# 出场顺序：暗影守卫→深渊领主→虚空霸主→老赛→德牧蓝，之后随机
const _ACTIVE_BOSS_INDICES: Array = [0, 1, 2, 3, 4]
func _pick_boss_def() -> Dictionary:
	var idx: int
	if _boss_defeat_count < _BOSS_ORDER.size():
		idx = _BOSS_ORDER[_boss_defeat_count]
	else:
		idx = _ACTIVE_BOSS_INDICES[randi() % _ACTIVE_BOSS_INDICES.size()]
		if _ACTIVE_BOSS_INDICES.size() > 1 and idx == _last_boss_index:
			idx = _ACTIVE_BOSS_INDICES[(idx + 1) % _ACTIVE_BOSS_INDICES.size()]
	_last_boss_index = idx
	return BOSS_DEFS[idx]

# 刷一只 BOSS（独立场景 boss.tscn，自带两阶段攻击状态机；随机选一只）
func _spawn_boss() -> void:
	var d: Dictionary = _pick_boss_def()
	var e = BOSS_SCENE.instantiate()
	# 猎杀行动：BOSS血量固定1000（新手关卡调低为 1/16）
	if _current_stage_config.get("objective_type", "") == "kill_boss":
		e.hp = 1000.0 / 8.0
	# BOSS连战：固定血量，不乘难度
	elif _boss_rush_active:
		e.hp = d["hp"]
	elif level_mode_active:
		e.hp = d["hp"] * _difficulty
	else:
		# 无尽模式：直接使用基础血量
		e.hp = d["hp"] * _difficulty
	e.touch_damage = d["touch"]
	# BOSS连战：经验值×2
	e.exp_value = d["exp"] * 2.0 if _boss_rush_active else d["exp"]
	e.def = d
	e.global_position = _pick_spawn_pos()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(e)
	# boss 名字改由 HUD 顶部 _boss_label 显示，不再单独弹横幅（避免与顶部重复）

# BOSS 召唤小怪：在 center 周围环形生成 n 只随机普通敌人（阶段2+使用）
func spawn_minions(center: Vector2, n: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var keys: Array = ENEMY_ROLES.keys()
	for i in n:
		var kind: String = keys[randi() % keys.size()]
		var sc = ENEMY_SCENES.get(kind)
		if sc == null:
			continue
		var en = sc.instantiate()
		en.set_script(ENEMY_SCRIPT)
		var role: Dictionary = ENEMY_ROLES[kind]
		for k in role.keys():
			en.set(k, role[k])
		en.hp = role["hp"] * _difficulty
		if kind == "fox" or kind == "mario":
			en.flip_left_walk = true
		var ang: float = randf_range(0.0, TAU)
		var r: float = randf_range(70.0, 170.0)
		en.global_position = center + Vector2(cos(ang), sin(ang)) * r
		scene_root.add_child(en)

# 计算当前相机可见区域的"世界坐标矩形"（相机跟随玩家、zoom<1 时可见范围更大）
func _visible_world_rect() -> Rect2:
	var center: Vector2 = _player.global_position if _player != null else Vector2(map_width * 0.5, map_height * 0.5)
	var vpsize: Vector2 = get_viewport().size
	var z: float = 1.0
	if _player != null:
		var cam: Camera2D = _player.get_node_or_null("Camera2D")
		if cam != null:
			z = cam.zoom.x
	var world_w: float = vpsize.x / z
	var world_h: float = vpsize.y / z
	return Rect2(center.x - world_w * 0.5, center.y - world_h * 0.5, world_w, world_h)

# 小怪只在"屏幕边缘带"生成（边界外一点），且离玩家不小于 spawn_ring_min，
# 不会凭空出现在玩家脸上。随机方向 → 包围感均匀、不会只从一侧涌来。
func _pick_spawn_pos() -> Vector2:
	if _player == null:
		return Vector2(map_width * 0.5, map_height * 0.5)
	var r: Rect2 = _visible_world_rect()
	var hw: float = r.size.x * 0.5
	var hh: float = r.size.y * 0.5
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	var ang: float = randf_range(0.0, TAU)
	var dx: float = cos(ang)
	var dy: float = sin(ang)
	# 沿该方向到达可视矩形边界的距离（视角外缘）
	var tx: float = hw / abs(dx) if abs(dx) > 0.0001 else INF
	var ty: float = hh / abs(dy) if abs(dy) > 0.0001 else INF
	var boundary: float = min(tx, ty)
	# 边缘外 40px 生成（刚好在屏幕外、随即走入），并保底不小于 spawn_ring_min
	var dist: float = max(boundary + 40.0, spawn_ring_min)
	var p := Vector2(cx + dx * dist, cy + dy * dist)
	p.x = clamp(p.x, edge_margin, map_width - edge_margin)
	p.y = clamp(p.y, edge_margin, map_height - edge_margin)
	return p

func _show_banner(text: String, duration: float) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.visible = true
	_banner_timer = duration

# HUD 用：当前波次/无尽层级标签
func get_wave_label() -> String:
	if level_mode_active:
		return "关卡模式"
	if _state == State.BOSS_FIGHT:
		return "⚠ BOSS 战"
	if _endless:
		return "无尽 · 第 %d 层" % (_endless_stage + 1)
	return "准备中"

func get_difficulty() -> float:
	return _difficulty

# 猎杀行动：根据玩家血量计算星级
func _calc_boss_rush_stars() -> void:
	if RunStats == null:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("get_hp") and p.has_method("get_max_hp"):
		var hp: float = p.get_hp()
		var max_hp: float = p.get_max_hp()
		var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0
		if ratio > 0.8:
			RunStats.crystal_hp_ratio = 1.0   # 3星
		elif ratio > 0.6:
			RunStats.crystal_hp_ratio = 0.6   # 2星
		elif ratio > 0.4:
			RunStats.crystal_hp_ratio = 0.4   # 1星
		else:
			RunStats.crystal_hp_ratio = 0.0   # 0星

# BOSS连战：刷下一只BOSS
func _spawn_next_boss_rush_boss() -> void:
	_state = State.BOSS_FIGHT
	_spawn_boss()
	_show_banner("第 %d / 5 只 BOSS" % (_boss_rush_kills + 1), 2.0)

# BOSS连战：根据击败数计算星级
func _calc_boss_rush_level_stars() -> void:
	if RunStats == null:
		return
	if _boss_rush_kills >= 5:
		RunStats.crystal_hp_ratio = 1.0   # 3星
	elif _boss_rush_kills >= 3:
		RunStats.crystal_hp_ratio = 0.6   # 2星
	elif _boss_rush_kills >= 1:
		RunStats.crystal_hp_ratio = 0.4   # 1星
	else:
		RunStats.crystal_hp_ratio = 0.0   # 0星

# ===== 关卡模式接口 =====

func set_level_mode(enabled: bool) -> void:
	level_mode_active = enabled
	if not enabled:
		_current_stage_config.clear()
		_level_stage_repeating = false
		_boss_rush_active = false
		if RunStats != null and RunStats.has_signal("boss_defeated"):
			if RunStats.boss_defeated.is_connected(_on_boss_defeated):
				RunStats.boss_defeated.disconnect(_on_boss_defeated)

func start_level_stage(stage: Dictionary) -> void:
	level_mode_active = true
	_current_stage_config = stage.duplicate(true)
	_state = State.FIGHTING
	_groups.clear()
	_crystal_defense_elapsed = 0.0
	_kill_boss_timer = 0.0
	_kill_boss_boss_spawned = false
	_boss_rush_kills = 0
	_boss_rush_total = 5
	_boss_rush_active = stage.get("objective_type", "") == "boss_rush"
	_boss_rush_timer = 0.0
	_boss_rush_boss_phase = false
	# 防止 _ensure_fresh_scene 在下一帧重置状态
	_last_scene = get_tree().current_scene
	# 水晶防御模式：提高同屏上限
	if stage.get("objective_type", "") == "protect_target":
		_max_alive = 100

	var enemy_types: Array = stage.get("enemy_types", [])
	var enemy_count: int = stage.get("enemy_count", 0) as int
	var spawn_interval: float = float(stage.get("spawn_interval", 1.0))
	var stage_difficulty: float = float(stage.get("difficulty_multiplier", 1.0))

	_level_stage_repeating = enemy_count == 0

	# BOSS连战：先刷1分钟小怪
	if _boss_rush_active:
		if RunStats != null and RunStats.has_signal("boss_defeated"):
			if RunStats.boss_defeated.is_connected(_on_boss_defeated):
				RunStats.boss_defeated.disconnect(_on_boss_defeated)
			RunStats.boss_defeated.connect(_on_boss_defeated)
		# 设置小怪组（fox海）
		_groups.clear()
		_groups.append({
			"kind": "fox",
			"remaining": 99999,
			"interval": 0.3,
			"timer": 0.0,
		})
		_level_stage_repeating = true
		_show_banner("BOSS连战 - 准备迎战！", 2.0)
		return

	if enemy_types.is_empty() and enemy_count == 0:
		# BOSS 关：直接刷 BOSS
		if has_method("_enter_boss_fight"):
			_enter_boss_fight()
		return

	if enemy_count > 0:
		var per_type: int = max(1, enemy_count / max(1, enemy_types.size()))
		for kind in enemy_types:
			if not ENEMY_SCENES.has(kind):
				continue
			_groups.append({
				"kind": kind,
				"remaining": per_type,
				"interval": spawn_interval,
				"timer": 0.0,
			})
		_difficulty = (1.0 + RunStats.get_difficulty_base()) * stage_difficulty
		_show_banner(stage.get("name", "阶段开始"), 2.0)
	else:
		_setup_level_stage_groups(stage)
		_show_banner(stage.get("name", "阶段开始"), 2.0)

func _setup_level_stage_groups(stage: Dictionary) -> void:
	var enemy_types: Array = stage.get("enemy_types", [])
	var spawn_interval: float = float(stage.get("spawn_interval", 0.8))
	_groups.clear()
	for kind in enemy_types:
		if not ENEMY_SCENES.has(kind):
			continue
		_groups.append({
			"kind": kind,
			"remaining": 99999,
			"interval": spawn_interval,
			"timer": 0.0,
		})

func _restart_level_stage() -> void:
	if _current_stage_config.is_empty():
		return
	_setup_level_stage_groups(_current_stage_config)

func export_state() -> Dictionary:
	var groups_out: Array = []
	for g in _groups:
		groups_out.append({
			"kind": g["kind"],
			"remaining": g["remaining"],
			"interval": g["interval"],
			"timer": g["timer"],
		})
	return {
		"state": _state,
		"wave_index": _wave_index,
		"endless": _endless,
		"endless_stage": _endless_stage,
		"endless_wave_count": _endless_wave_count,
		"waves_cleared": _waves_cleared,
		"run_time": _run_time,
		"difficulty": _difficulty,
		"max_alive": _max_alive,
		"boss_defeat_count": _boss_defeat_count,
		"last_boss_index": _last_boss_index,
		"groups": groups_out,
		"level_mode_active": level_mode_active,
		"current_stage_config": _current_stage_config.duplicate(true),
		"level_stage_repeating": _level_stage_repeating,
		"timer": _timer,
		"wave_info": get_wave_label(),
	}

func restore_state(data: Dictionary) -> void:
	_state = data.get("state", State.INTERMISSION)
	if _state == State.BOSS_FIGHT or _state == State.VICTORY:
		_state = State.INTERMISSION
		_timer = 1.0
	_wave_index = data.get("wave_index", -1)
	_endless = data.get("endless", true)
	_endless_stage = data.get("endless_stage", 0)
	_endless_wave_count = data.get("endless_wave_count", 0)
	_waves_cleared = data.get("waves_cleared", 0)
	_run_time = data.get("run_time", 0.0)
	_difficulty = data.get("difficulty", 1.0)
	_max_alive = data.get("max_alive", 60)
	_boss_defeat_count = data.get("boss_defeat_count", 0)
	_last_boss_index = data.get("last_boss_index", -1)
	level_mode_active = data.get("level_mode_active", false)
	_current_stage_config = data.get("current_stage_config", {}).duplicate(true)
	_level_stage_repeating = data.get("level_stage_repeating", false)
	_timer = data.get("timer", 0.0)
	var saved_groups: Array = data.get("groups", [])
	_groups.clear()
	for g in saved_groups:
		_groups.append({
			"kind": g.get("kind", "fox"),
			"remaining": g.get("remaining", 0),
			"interval": g.get("interval", 0.5),
			"timer": g.get("timer", 0.0),
		})
