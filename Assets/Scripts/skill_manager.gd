extends Node

## 技能系统单例（AutoLoad，节点名 SkillManager）。
## 统一管理：拥有哪些技能 / 星级 / 升级抽卡 / 被动生效 / 主动挂载 / 经验倍率。
##
## 设计要点：
## - 数据驱动：每个技能是 SKILLS 里的一条定义，加技能只加数据。
## - 类型：PASSIVE(被动,1~5星) / ACTIVE(主动自动攻击,1~5星,满星即最强) / SPECIAL(特殊,延时,占位)。
## - 被动永久改属性；主动自动攻击；特殊为后续阶段（先在数据占位，不进抽卡池）。
## - 场景重载（玩家死亡重开）时，owned 字典保留，本单例会自动把技能重新应用到新玩家节点。

enum SkillType { PASSIVE, ACTIVE, SPECIAL }

# 每个技能：type / name / desc / icon(预加载) / max_stars
const SKILLS := {
	# —— 被动（永久属性，1~5 星）——
	"passive_shoe":   {"type": SkillType.PASSIVE, "name": "球鞋",   "desc": "移动速度 +12%/星",        "icon": preload("res://Assets/Sprites/Skills/passive_shoe.png"),   "max_stars": 5},
	"passive_magnet": {"type": SkillType.PASSIVE, "name": "吸铁石", "desc": "拾取范围 +25%/星",        "icon": preload("res://Assets/Sprites/Skills/passive_magnet.png"), "max_stars": 5},
	"passive_book":   {"type": SkillType.PASSIVE, "name": "书籍",   "desc": "经验球价值 +20%/星",      "icon": preload("res://Assets/Sprites/Skills/passive_book.png"),   "max_stars": 5},
	"passive_stock":  {"type": SkillType.PASSIVE, "name": "股票",   "desc": "升级所需经验 -12%/星",     "icon": preload("res://Assets/Sprites/Skills/passive_stock.png"),  "max_stars": 5},
	# —— 角色专属被动（进化前置条件，1~5 星）——
	"passive_glove":    {"type": SkillType.PASSIVE, "name": "拳套",   "desc": "壮汉拳击进化前置 · 拳击伤害 +10%/星", "icon": preload("res://Assets/Sprites/Skills/passive_glove.png"),    "max_stars": 5, "exclusive_to": "brute"},
	"passive_staff":    {"type": SkillType.PASSIVE, "name": "法杖",   "desc": "学者电击进化前置 · 电击伤害 +10%/星", "icon": preload("res://Assets/Sprites/Skills/passive_staff.png"),    "max_stars": 5, "exclusive_to": "mage"},
	"passive_archery":  {"type": SkillType.PASSIVE, "name": "弓术",   "desc": "游侠射箭进化前置 · 箭伤 +10%/星",     "icon": preload("res://Assets/Sprites/Skills/passive_archery.png"),  "max_stars": 5, "exclusive_to": "ranger"},
	"passive_gun":      {"type": SkillType.PASSIVE, "name": "枪械",   "desc": "特工手枪进化前置 · 子弹伤害 +10%/星", "icon": preload("res://Assets/Sprites/Skills/passive_gun.png"),      "max_stars": 5, "exclusive_to": "wanderer"},

	# —— 主动（自动攻击，1~5 星；满星+专属被动可进化成 super_*，见 EVOLVE）——
	"active_pistol":     {"type": SkillType.ACTIVE, "name": "手枪",   "desc": "发射子弹，可有限穿透",         "icon": preload("res://Assets/Sprites/Skills/active_pistol.png"),     "max_stars": 5, "exclusive_to": "wanderer"},
	"active_bow":        {"type": SkillType.ACTIVE, "name": "射箭",   "desc": "逐根连射箭矢，有限穿透并卡入敌人", "icon": preload("res://Assets/Sprites/Skills/active_bow.png"),        "max_stars": 5, "exclusive_to": "ranger"},
	"active_punch":      {"type": SkillType.ACTIVE, "name": "拳击",   "desc": "近身重拳，击退前方敌人",       "icon": preload("res://Assets/Sprites/Skills/active_punch.png"),      "max_stars": 5, "exclusive_to": "brute"},
	"active_lightning":  {"type": SkillType.ACTIVE, "name": "魔法电击", "desc": "锁定最近数个敌人落魔法射线(每星+1目标)", "icon": preload("res://Assets/Sprites/Skills/active_lightning.png"),  "max_stars": 5, "exclusive_to": "mage"},
	"active_drone":      {"type": SkillType.ACTIVE, "name": "无人机", "desc": "环绕无人机会自动开火(通用)",   "icon": preload("res://Assets/Sprites/Skills/active_drone.png"),     "max_stars": 5},
	"active_firebomb":   {"type": SkillType.ACTIVE, "name": "燃烧瓶", "desc": "投掷燃烧瓶，留下持续火焰",     "icon": preload("res://Assets/Sprites/Skills/active_firebomb.png"),   "max_stars": 5},
	"active_basketball": {"type": SkillType.ACTIVE, "name": "巧乐兹", "desc": "弹跳巧乐兹，反复碾压敌群(通用)", "icon": preload("res://Assets/Sprites/Skills/active_basketball.png"), "max_stars": 5},
	"active_book":       {"type": SkillType.ACTIVE, "name": "魔法书", "desc": "发射魔法弹，远程轰炸(通用)",   "icon": preload("res://Assets/Sprites/Skills/active_book.png"),       "max_stars": 5},

	# —— 进化体（满星+专属被动后由升级卡授予；evolves_from 指明被替换的基础武器）——
	"super_pistol":     {"type": SkillType.ACTIVE, "name": "双枪绝杀", "desc": "终极 · 双管交替狂射，周期射出命中爆炸的绝杀弹", "icon": preload("res://Assets/Sprites/Skills/super_pistol.png"),     "max_stars": 5, "evolves_from": "active_pistol", "exclusive_to": "wanderer"},
	"super_bow":        {"type": SkillType.ACTIVE, "name": "万箭齐发", "desc": "终极 · 锁定敌群天降十余支巨箭，落地范围溅射", "icon": preload("res://Assets/Sprites/Skills/super_bow.png"),        "max_stars": 5, "evolves_from": "active_bow", "exclusive_to": "ranger"},
	"super_punch":      {"type": SkillType.ACTIVE, "name": "毁灭重拳", "desc": "终极 · 巨拳砸地爆发环形冲击波，全向击退敌群",   "icon": preload("res://Assets/Sprites/Skills/super_punch.png"),      "max_stars": 5, "evolves_from": "active_punch", "exclusive_to": "brute"},
	"super_lightning":  {"type": SkillType.ACTIVE, "name": "连锁雷暴", "desc": "终极 · 天降多道落雷范围轰击，并以电弧连锁蔓延", "icon": preload("res://Assets/Sprites/Skills/super_lightning.png"),  "max_stars": 5, "evolves_from": "active_lightning", "exclusive_to": "mage"},

	"special_shield":    {"type": SkillType.SPECIAL, "name": "守护圣盾", "desc": "悬浮身前替你挡伤，脱战自动回盾；升级更厚更大", "icon": preload("res://Assets/Sprites/Skills/special_shield.png"),    "max_stars": 5},
	"special_hourglass": {"type": SkillType.SPECIAL, "name": "时空沙漏", "desc": "周期冻结全场敌人并清掉敌弹；升级冻更久+微伤", "icon": preload("res://Assets/Sprites/Skills/special_hourglass.png"), "max_stars": 5},
	"special_thunder":   {"type": SkillType.SPECIAL, "name": "雷电法杖", "desc": "周期雷击屏幕内敌群，优先密集区；升级更多更粗更痛", "icon": preload("res://Assets/Sprites/Skills/special_thunder.png"),   "max_stars": 5},
}

# 升级可选池：4 通用被动 + 4 角色专属被动 + 4 角色主题武器 + 4 通用武器
# 注意：super_* 不进入随机池，只能由进化卡授予（见 EVOLVE / roll_choices）
const POOL := ["passive_shoe", "passive_magnet", "passive_book", "passive_stock",
	"passive_glove", "passive_staff", "passive_archery", "passive_gun",
	"active_pistol", "active_bow", "active_punch", "active_lightning",
	"active_drone", "active_basketball", "active_book", "active_firebomb"]

# 进化映射（VS 式成熟逻辑）：基础武器满星(5★) + 持有对应专属被动 → 进化成 super_*
# 进化后基础武器从战场移除（add_active 见 evolves_from 处理），其升级卡不再出现
const EVOLVE := {
	"active_pistol":    {"super": "super_pistol",    "passive": "passive_gun"},
	"active_bow":       {"super": "super_bow",       "passive": "passive_archery"},
	"active_punch":     {"super": "super_punch",     "passive": "passive_glove"},
	"active_lightning": {"super": "super_lightning", "passive": "passive_staff"},
}

var owned: Dictionary = {}        # id -> 当前星级(int)
var _player: Node2D = null
var _last_scene: Node = null
var _pending_apply: bool = false   # 新一局开始，待玩家就绪后授予初始武器+属性

const ACTIVE_SCRIPT := preload("res://Assets/Scripts/active_weapon.gd")
const SPECIAL_SHIELD_SCRIPT := preload("res://Assets/Scripts/special_shield.gd")
const SPECIAL_HOURGLASS_SCRIPT := preload("res://Assets/Scripts/special_hourglass.gd")
const SPECIAL_THUNDER_SCRIPT := preload("res://Assets/Scripts/special_thunder.gd")

func _process(delta: float) -> void:
	# 检测场景重载（玩家死亡重开 / 进入新一局），自动把技能重新应用到新玩家节点
	var cs: Node = get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		_player = null
		if cs != null and cs.name == "Main":
			# 新一局：清空上局技能，按所选角色授予初始武器 + 属性修正
			owned.clear()
			_pending_apply = true
		else:
			_player = null
	# 待玩家节点就绪后，应用本局角色配置（避免玩家 _ready 前就挂武器）
	if _pending_apply:
		_ensure_player()
		if _player != null and _player.is_inside_tree():
			_apply_character()
			_pending_apply = false

func _ensure_player() -> void:
	if _player == null or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as Node2D

# 当前出战角色 id（来自 RunStats.chosen_character，跨场景保留）
func _current_character() -> String:
	if RunStats != null:
		return RunStats.chosen_character
	return "wanderer"

# 获得或升级一个技能（最高升到 max_stars；super_* 由进化卡授予，见 EVOLVE / roll_choices）
func grant(id: String) -> void:
	_ensure_player()
	if not SKILLS.has(id):
		return
	var def: Dictionary = SKILLS[id]
	var t: int = int(def["type"])
	var maxs: int = int(def["max_stars"])
	if owned.has(id):
		owned[id] = min(owned[id] + 1, maxs)
	else:
		owned[id] = 1
	# 进化即前置消失：授予 super_* 时，把它进化自的基础武器从 owned 移除
	# （基础武器"进化"成了终极技能：从技能列表/抽卡池/战场消失；对应专属被动作为永久加成保留）
	var evolves_from: String = def.get("evolves_from", "")
	if evolves_from != "" and owned.has(evolves_from):
		owned.erase(evolves_from)
	if t == SkillType.PASSIVE:
		apply_passive(id)
	elif t == SkillType.ACTIVE:
		add_active(id)
	elif t == SkillType.SPECIAL:
		add_special(id)

# 升级时抽 n 张候选卡：未拥有的=新；已拥有但未满星=升级；已进化(super 在手)的基础武器不再出现。
# 进化候选：基础武器满星 + 持有对应专属被动 → 提供一张"进化卡"（优先级最高）。
# 保底：至少 1 张来自"主动武器升星"池（优先），加速强化主战武器；其余从全部候选随机。
func roll_choices(n: int = 3) -> Array:
	var active_up: Array = []    # 已有主动武器的升星卡（优先保底，不含已进化的基础武器）
	var other_up: Array = []     # 被动升星卡 / 其他
	var new_pool: Array = []     # 未拥有技能的新卡
	var evo_pool: Array = []     # 进化候选卡（super_*）
	var cur_char: String = _current_character()
	for id in POOL:
		# 角色专属技能：仅本人可从升级卡获得，其他角色屏蔽（专属攻击/被动/进化体）
		if SKILLS[id].get("exclusive_to", "") != "" and SKILLS[id]["exclusive_to"] != cur_char:
			continue
		# 若某基础武器已进化（其 super 在手），跳过它的升级卡（避免回退/重复）
		if EVOLVE.has(id) and owned.has(EVOLVE[id]["super"]):
			continue
		if not owned.has(id):
			new_pool.append({"id": id, "is_new": true, "stars": 0})
		else:
			var cur: int = int(owned[id])
			if cur < int(SKILLS[id]["max_stars"]):
				if int(SKILLS[id]["type"]) == SkillType.ACTIVE:
					active_up.append({"id": id, "is_new": false, "stars": cur})
				else:
					other_up.append({"id": id, "is_new": false, "stars": cur})
	# 进化候选：基础武器满星 + 持有对应专属被动 + 尚未进化
	for base in EVOLVE.keys():
		if not owned.has(base):
			continue
		if int(owned[base]) < int(SKILLS[base]["max_stars"]):
			continue
		var sup: String = EVOLVE[base]["super"]
		var req: String = EVOLVE[base]["passive"]
		if owned.has(sup) or not owned.has(req):
			continue
		evo_pool.append({"id": sup, "is_new": true, "stars": 0, "is_evo": true})
	var result: Array = []
	# 进化卡优先（最值得给）
	if not evo_pool.is_empty():
		evo_pool.shuffle()
		result.append(evo_pool.pop_back())
	# 主动武器升星保底
	if not active_up.is_empty():
		active_up.shuffle()
		result.append(active_up.pop_back())
	var rest := active_up + other_up + new_pool
	rest.shuffle()
	while result.size() < n and not rest.is_empty():
		result.append(rest.pop_back())
	return result

func stars(id: String) -> int:
	return int(owned.get(id, 0))

# 重新应用所有已拥有技能（场景重载后调用）
func _resync_all() -> void:
	for id in owned.keys():
		var t: int = int(SKILLS[id]["type"])
		if t == SkillType.PASSIVE:
			apply_passive(id)
		elif t == SkillType.ACTIVE:
			add_active(id)
		elif t == SkillType.SPECIAL:
			add_special(id)

# 特殊武器：在玩家节点下挂对应行为节点（去重）；星级由节点实时读取，升级即时生效
func add_special(id: String) -> void:
	_ensure_player()
	if _player == null:
		return
	for c in _player.get_children():
		if c.has_method("get") and c.get("skill_id") == id:
			return
	var node := Node2D.new()
	match id:
		"special_shield":    node.set_script(SPECIAL_SHIELD_SCRIPT)
		"special_hourglass": node.set_script(SPECIAL_HOURGLASS_SCRIPT)
		"special_thunder":   node.set_script(SPECIAL_THUNDER_SCRIPT)
	node.skill_id = id
	_player.add_child(node)

# 新一局开始：按 RunStats.chosen_character 授予初始武器并应用属性修正
func _apply_character() -> void:
	if RunStats == null:
		return
	var c: Dictionary = RunStats.get_character_def()
	var sw: String = c.get("start_weapon", "")
	if sw != "":
		grant(sw)
	var hp_mult: float = float(c.get("hp_mult", 1.0))
	var sp_mult: float = float(c.get("speed_mult", 1.0))
	_player.apply_run_mods(hp_mult, sp_mult)

# 被动：基于全部被动星级重算玩家属性（幂等，避免重复叠加）
func apply_passive(id: String) -> void:
	_ensure_player()
	if _player == null:
		return
	var shoe: int   = stars("passive_shoe")
	var magnet: int = stars("passive_magnet")
	var book: int   = stars("passive_book")
	var stock: int  = stars("passive_stock")
	_player.speed = 220.0 * (1.0 + 0.12 * shoe)
	_player.magnet_radius = 140.0 * (1.0 + 0.25 * magnet)
	_player.xp_pickup_mult = 1.0 + 0.20 * book
	_player.xp_rate_mult = 1.0 + 0.12 * stock

# 主动：在玩家节点下挂对应武器节点（去重）
# 进化体(super_*)：先移除其基础武器节点(evolves_from)；已被进化的基础武器则不再挂基础节点
func add_active(id: String) -> void:
	_ensure_player()
	if _player == null:
		return
	var def: Dictionary = SKILLS.get(id, {})
	var evolves_from: String = def.get("evolves_from", "")
	if evolves_from != "":
		for c in _player.get_children():
			if c.has_method("get") and c.get("skill_id") == evolves_from:
				c.queue_free()
	# 基础武器若已进化出 super，则不再挂基础节点（避免与超武并存）
	if EVOLVE.has(id) and owned.has(EVOLVE[id]["super"]):
		return
	for c in _player.get_children():
		if c.has_method("get") and c.get("skill_id") == id:
			return
	var node = Node2D.new()
	node.set_script(ACTIVE_SCRIPT)
	node.skill_id = id
	_player.add_child(node)
