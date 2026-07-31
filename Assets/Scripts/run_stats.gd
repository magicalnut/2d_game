extends Node

## 单局统计（AutoLoad 单例）：存活时间、击杀数、当前等级。
## 进入战斗场景（Main 节点）即视为新一局开始，自动重置。
## 暂停/结算时整棵树被暂停，本节点随之停止 _process，计时自然冻结。
##
## 角色出战：chosen_character 由 character_setup 页写入，跨场景保留（不随重置清空）；
## CHARACTERS 定义三个可选角色（初始武器 + 属性修正）。

# —— 可选角色（每个角色拥有独立外观 sheet；sheet 缺失时回退配色占位）——
# sheet 与 idle 帧区域按角色独立配置：brute/mage/ranger 为 228×300（3列×4行，每帧76×75，idle 在第 3 行 y=150）；
# wanderer 为 692×303（10列×4行，每帧约69×75，idle 在第 2 行 y=75）。
# 每个角色拥有「主题自带攻击」：特工=子弹 / 壮汉=拳击(近战) / 学者=魔法电击(单体) / 游侠=射箭；
# 其初始武器由 start_weapon 指定，对应 active_weapon.gd 的 skill_id 分支；满星+专属被动可进化（见 skill_manager.gd EVOLVE）。
const CHARACTERS := {
	# builtin_attack=true 表示角色使用 player.gd 内置的追踪子弹作为基础攻击；现已全部关闭，四角色统一走各自 active_weapon 的直线弹
	"wanderer": {"name": "特工",   "start_weapon": "active_pistol",     "speed_mult": 1.00, "hp_mult": 1.0, "desc": "均衡型。手枪朝敌人直线射击，操作简单",
	             "sheet": "res://Assets/Sprites/Heroes/wanderer/sheet.png", "idle_region": Rect2(0, 75, 69, 75), "accent": Color(0.45, 0.85, 0.50), "builtin_attack": false},
	"brute":    {"name": "壮汉",   "start_weapon": "active_punch",      "speed_mult": 0.85, "hp_mult": 1.6, "desc": "高血量近战。拳击对前方扇形范围造成伤害并击退",
	             "sheet": "res://Assets/Sprites/Heroes/brute/sheet.png",   "idle_region": Rect2(0, 150, 76, 75), "accent": Color(0.95, 0.45, 0.30), "builtin_attack": false},
	"mage":     {"name": "学者",   "start_weapon": "active_lightning",  "speed_mult": 1.05, "hp_mult": 0.8, "desc": "远程法术。电击同时攻击多个目标，血量较低需注意走位",
	             "sheet": "res://Assets/Sprites/Heroes/mage/sheet.png",    "idle_region": Rect2(0, 150, 76, 75), "accent": Color(0.50, 0.55, 0.95), "builtin_attack": false},
	"ranger":   {"name": "游侠",   "start_weapon": "active_bow",        "speed_mult": 1.10, "hp_mult": 0.9, "desc": "高机动远程。射箭可穿透多个敌人，移速最快",
	             "sheet": "res://Assets/Sprites/Heroes/ranger/sheet.png",  "idle_region": Rect2(0, 150, 76, 75), "accent": Color(0.95, 0.85, 0.35), "builtin_attack": false},
}

signal kill_added(total_kills: int)
signal boss_defeated

var time_survived: float = 0.0
var kills: int = 0
var chosen_character: String = "mage"
var deploy_difficulty: int = 0   # 出战整备页选的难度：0=普通 1=困难 2=噩梦（跨场景保留）
var game_mode: String = ""       # 游戏模式：""=未选择 "level"=关卡模式 "endless"=无尽模式
var selected_level_id: String = ""
var level_mode_result: String = ""

# ===== 装备系统 =====
var equipped_gear: Dictionary = {}    # 本局携带的装备实例 {slot_id: gear_instance}
var character_gear: Dictionary = {}  # 角色专属装备配置 {character_id: {slot_id: gear_instance}}
var last_wave_reached: int = 0       # 本局到达的最高波次（用于钻石结算）
var run_diamonds: int = 0            # 本局已获得钻石（HUD 实时显示，结算/分解时累加）

# 难度基础偏移：作为 wave_manager 难度倍率公式的常数项，让手动难度真正生效
func get_difficulty_base() -> float:
	match deploy_difficulty:
		0: return 0.0
		1: return 0.7
		2: return 1.5
	return 0.0

# BOSS 引用：由 enemy(boss=true) 在 _ready 时写入、_die 时清空；HUD 读其血量显示 BOSS 血条
var boss_ref: Node2D = null
var skip_reset: bool = false

var _last_scene: Node = null

func _ready() -> void:
	_sync_from_save_manager()
	if SaveManager != null:
		SaveManager.save_loaded.connect(_sync_from_save_manager)

func _sync_from_save_manager() -> void:
	if SaveManager == null:
		return
	completed_levels = SaveManager.completed_levels.duplicate()
	unlocked_levels = SaveManager.unlocked_levels.duplicate()

func _process(delta: float) -> void:
	var cs: Node = get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		if cs != null and cs.name == "Main":
			if skip_reset:
				skip_reset = false
			else:
				_reset()
		else:
			boss_ref = null
	# 仅在战斗中累计时间（进入 Main 后；暂停时本节点不跑，自然冻结）
	if _last_scene != null and _last_scene.name == "Main":
		time_survived += delta

func _reset() -> void:
	time_survived = 0.0
	kills = 0
	run_diamonds = 0
	# boss_ref 不由 _reset 清空：防止 _process(_reset) 覆盖 boss._ready() 已设的引用
	# boss_ref 在离开 Main 时由 _process() else 分支清空，或在 boss._die() 中清空

func add_kill() -> void:
	kills += 1
	kill_added.emit(kills)

func get_time_string() -> String:
	var t: int = int(time_survived)
	var m: int = t / 60
	var s: int = t % 60
	return "%02d:%02d" % [m, s]

func get_character_def() -> Dictionary:
	return CHARACTERS.get(chosen_character, CHARACTERS["wanderer"])

# ===== 关卡进度 API =====

const LEVEL_ORDER: Array[String] = ["level_01", "level_02", "level_03"]
var completed_levels: Array[String] = []
var unlocked_levels: Array[String] = ["level_01"]

func is_level_completed(level_id: String) -> bool:
	return completed_levels.has(level_id)

func is_level_unlocked(level_id: String) -> bool:
	if unlocked_levels.has(level_id):
		return true
	var data: LevelData = load("res://Assets/Resources/Levels/" + level_id + ".tres") as LevelData
	if data == null:
		return false
	if data.unlock_requirement.is_empty():
		return true
	return completed_levels.has(data.unlock_requirement)

func complete_level(level_id: String) -> void:
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
	for id in LEVEL_ORDER:
		var data: LevelData = load("res://Assets/Resources/Levels/" + id + ".tres") as LevelData
		if data == null:
			continue
		if data.unlock_requirement == level_id and not unlocked_levels.has(id):
			unlocked_levels.append(id)
	_save_level_progress()

func _save_level_progress() -> void:
	if SaveManager == null:
		return
	SaveManager.completed_levels = completed_levels.duplicate()
	SaveManager.unlocked_levels = unlocked_levels.duplicate()
	SaveManager.save()

func save_character_gear() -> void:
	if SaveManager == null:
		return
	SaveManager.character_gear = character_gear.duplicate(true)
	SaveManager.save()

func load_character_gear() -> void:
	if SaveManager == null:
		return
	character_gear = SaveManager.character_gear.duplicate(true)

func restore_from_save(data: Dictionary) -> void:
	time_survived = data.get("time_survived", 0.0)
	kills = data.get("kills", 0)
	last_wave_reached = data.get("last_wave_reached", 0)
	chosen_character = data.get("chosen_character", chosen_character)
	deploy_difficulty = data.get("deploy_difficulty", deploy_difficulty)
	game_mode = data.get("game_mode", game_mode)
	selected_level_id = data.get("selected_level_id", selected_level_id)
	var gear = data.get("equipped_gear", {})
	if gear is Dictionary:
		equipped_gear = gear.duplicate(true)
	run_diamonds = data.get("run_diamonds", 0)
