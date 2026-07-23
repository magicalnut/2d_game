extends Node

## 装备管理器（AutoLoad）：全局装备数据库、槽位等级系统、钻石经济、属性计算。
## 本局携带的装备由 RunStats.equipped_gear 存储；本节点只负责定义和计算。

# ===== 装备数据库（静态只读） =====
const GEAR_DB: Dictionary = {
	# 符文（攻击）
	"rune_of_fire": {
		"slot": "rune", "name": "烈焰符文", "rarity": 1, "max_level": 3,
		"base_stats": {"atk_bonus": 4}, "growth_stats": {"atk_bonus": 2},
		"flavor": "注入火焰之力，直接提升攻击力。"
	},
	"rune_of_wind": {
		"slot": "rune", "name": "疾风符文", "rarity": 1, "max_level": 3,
		"base_stats": {"atk_bonus": 2, "projectile_speed": 0.10},
		"growth_stats": {"atk_bonus": 1, "projectile_speed": 0.05},
		"flavor": "子弹飞行速度提升，命中更迅速。"
	},
	# 护符（防御）
	"amulet_of_vitality": {
		"slot": "amulet", "name": "生命护符", "rarity": 1, "max_level": 3,
		"base_stats": {"max_hp_bonus": 15}, "growth_stats": {"max_hp_bonus": 10},
		"flavor": "增加最大生命值，容错率更高。"
	},
	"amulet_of_stone": {
		"slot": "amulet", "name": "石肤护符", "rarity": 1, "max_level": 3,
		"base_stats": {"max_hp_bonus": 8, "def_bonus": 0.05},
		"growth_stats": {"max_hp_bonus": 5, "def_bonus": 0.03},
		"flavor": "增加最大生命值，并减少受到的伤害。"
	},
	# 药剂（简化：被动常驻）
	"potion_of_rage": {
		"slot": "potion", "name": "狂怒药剂", "rarity": 1, "max_level": 3,
		"base_stats": {"atk_bonus": 3}, "growth_stats": {"atk_bonus": 2},
		"flavor": "怒气化为力量，永久提升攻击力。"
	},
	# 圣物（机制）
	"relic_of_hunger": {
		"slot": "relic", "name": "贪婪圣物", "rarity": 1, "max_level": 3,
		"base_stats": {"pickup_radius": 20.0, "exp_bonus": 0.05},
		"growth_stats": {"pickup_radius": 10.0, "exp_bonus": 0.03},
		"flavor": "扩大拾取范围，并提升经验获取效率。"
	},
	# 宠物（辅助）
	"pet_wisp": {
		"slot": "pet", "name": "精灵光球", "rarity": 1, "max_level": 3,
		"base_stats": {"move_speed_bonus": 12.0, "pickup_radius": 15.0},
		"growth_stats": {"move_speed_bonus": 8.0, "pickup_radius": 10.0},
		"flavor": "提升移动速度，并扩大拾取范围。"
	},
	"pet_hound": {
		"slot": "pet", "name": "猎犬幼崽", "rarity": 1, "max_level": 3,
		"base_stats": {"atk_bonus": 2, "move_speed_bonus": 8.0},
		"growth_stats": {"atk_bonus": 2, "move_speed_bonus": 5.0},
		"flavor": "提升攻击力和移动速度。"
	},
	# 信物（幸运）
	"token_luck": {
		"slot": "token", "name": "幸运币", "rarity": 1, "max_level": 3,
		"base_stats": {"exp_bonus": 0.08, "projectile_speed": 0.06},
		"growth_stats": {"exp_bonus": 0.04, "projectile_speed": 0.04},
		"flavor": "提升经验获取效率和子弹飞行速度。"
	},
	"token_haste": {
		"slot": "token", "name": "疾风纹章", "rarity": 1, "max_level": 3,
		"base_stats": {"move_speed_bonus": 15.0, "projectile_speed": 0.08},
		"growth_stats": {"move_speed_bonus": 10.0, "projectile_speed": 0.05},
		"flavor": "提升移动速度和子弹飞行速度。"
	}
}


# 稀有度倍率（计算基础属性时乘以这个值）
const RARITY_MULT: Array[float] = [1.0, 1.0, 1.4, 2.0, 2.8, 4.0]   # 索引0占位，1=白,2=绿...

# 稀有度颜色
const RARITY_COLORS: Array[Color] = [
	Color.GRAY, Color.WHITE, Color.GREEN, Color.DODGER_BLUE, Color.PURPLE, Color.GOLD
]

# 槽位顺序（用于显示和迭代）
const SLOT_ORDER: Array[String] = ["rune", "pet", "amulet", "potion", "token", "relic"]
const SLOT_NAMES: Dictionary = {
	"rune": "符文", "pet": "宠物", "amulet": "护符",
	"potion": "药剂", "token": "信物", "relic": "圣物"
}

# ===== 槽位等级配置（1-12级） =====
# 升级消耗：目标等级 -> 所需钻石
const SLOT_UPGRADE_COST: Dictionary = {
	2: 100, 3: 200, 4: 400, 5: 800, 6: 1500,
	7: 2000, 8: 3000, 9: 4000, 10: 6000, 11: 8000, 12: 12000
}

# 每个等级解锁的槽位
const SLOT_UNLOCKS: Dictionary = {
	1: ["rune"],       # 1级：符文
	2: ["amulet"],     # 2级：护符
	3: ["pet"],        # 3级：宠物
	4: ["potion"],     # 4级：药剂
	5: ["token"],      # 5级：信物
	6: ["relic"],      # 6级：圣物
	8: [],             # 8级解锁高级位1
	10: [],
	12: []
}

 # 高级装备位（蓝/紫/金需要占用）
const ADVANCED_SLOT_LEVELS: Array[int] = [8, 10, 12]   # 达到这些等级时各解锁1个高级位

# 高级装备稀有度阈值
const ADVANCED_RARITY_MIN: int = 3   # 蓝=3，紫=4，金=5

# 合成费用（目标星级 → 钻石）
const SYNTH_COST: Dictionary = {2: 200, 3: 300, 4: 500, 5: 1000}
const BUY_GEAR_COST: int = 300       # 购买随机装备的费用
const MAX_RARITY: int = 5            # 最高稀有度

# ===== 运行时数据（持久化） =====
var slot_level: int = 1          # 当前槽位等级 1-12
var diamonds: int = 0            # 总钻石（局外积累）
var last_run_diamonds: int = 0   # 上局获得的钻石（结算显示用）
var gear_inventory: Array = []   # 仓库：装备实例数组（每个元素是 Dictionary）

# 持久化文件路径
const SAVE_PATH: String = "user://equipment_save.json"

func _ready() -> void:
	_load_progress()

# ===== 槽位等级查询 =====

func get_slot_level() -> int:
	return clamp(slot_level, 1, 12)

func get_diamonds() -> int:
	return max(diamonds, 0)

func get_unlocked_slots() -> Array[String]:
	var unlocked: Array[String] = []
	var lv: int = get_slot_level()
	for lvl in SLOT_UNLOCKS.keys():
		if int(lvl) <= lv:
			unlocked.append_array(SLOT_UNLOCKS[lvl])
	# 去重并保证顺序
	var result: Array[String] = []
	for sid in SLOT_ORDER:
		if sid in unlocked and sid not in result:
			result.append(sid)
	return result

func is_slot_unlocked(slot_id: String) -> bool:
	return slot_id in get_unlocked_slots()

func get_advanced_slot_count() -> int:
	var lv: int = get_slot_level()
	var count: int = 0
	for req in ADVANCED_SLOT_LEVELS:
		if lv >= req:
			count += 1
	return count

func get_next_upgrade_cost() -> int:
	var lv: int = get_slot_level()
	if lv >= 12:
		return -1
	return SLOT_UPGRADE_COST.get(lv + 1, -1)

func can_upgrade() -> bool:
	var cost: int = get_next_upgrade_cost()
	if cost < 0:
		return false
	return diamonds >= cost

func upgrade_slot() -> bool:
	var cost: int = get_next_upgrade_cost()
	if cost < 0 or diamonds < cost:
		return false
	diamonds -= cost
	slot_level += 1
	_save_progress()
	return true

func add_diamonds(amount: int) -> void:
	if amount > 0:
		diamonds += amount
		last_run_diamonds = amount
		_save_progress()

func calculate_run_diamonds(wave_reached: int, kills: int) -> int:
	return int(wave_reached * 10 + kills * 0.5)

# ===== 装备查询 =====

func get_gear_def(def_id: String) -> Dictionary:
	return GEAR_DB.get(def_id, {})

func is_valid_gear(def_id: String) -> bool:
	return GEAR_DB.has(def_id)

func get_gear_name(def_id: String) -> String:
	var def: Dictionary = get_gear_def(def_id)
	return def.get("name", def_id)

func get_gear_slot(def_id: String) -> String:
	var def: Dictionary = get_gear_def(def_id)
	return def.get("slot", "")

func get_gear_rarity(def_id: String) -> int:
	var def: Dictionary = get_gear_def(def_id)
	return def.get("rarity", 1)

func get_rarity_color(rarity: int) -> Color:
	var idx: int = clamp(rarity, 1, 5)
	return RARITY_COLORS[idx]

# 计算单件装备的属性（扁平化）
func get_gear_stats(gear_instance: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if gear_instance.is_empty():
		return result
	var def_id: String = gear_instance.get("def_id", "")
	var def: Dictionary = get_gear_def(def_id)
	if def.is_empty():
		return result

	var level: int = clamp(gear_instance.get("level", 1), 1, def.get("max_level", 1))
	var rarity: int = clamp(gear_instance.get("rarity", 1), 1, 5)
	var mult: float = RARITY_MULT[rarity]

	var base: Dictionary = def.get("base_stats", {})
	var growth: Dictionary = def.get("growth_stats", {})

	for key in base.keys():
		var b: float = float(base[key])
		var g: float = float(growth.get(key, 0.0))
		result[key] = b * mult + g * (level - 1)

	return result

# 计算一组装备的总属性（已解锁槽位才计入）
func get_all_flat_stats(equipped: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var unlocked: Array[String] = get_unlocked_slots()
	for slot_id in equipped.keys():
		if slot_id not in unlocked:
			continue
		var inst: Dictionary = equipped[slot_id]
		if inst.is_empty():
			continue
		var stats: Dictionary = get_gear_stats(inst)
		for key in stats.keys():
			result[key] = result.get(key, 0.0) + float(stats[key])
	return result

# ===== 装备校验 =====

func can_equip(gear_instance: Dictionary, equipped: Dictionary) -> Dictionary:
	## 返回 {"ok": bool, "reason": String}
	var result: Dictionary = {"ok": false, "reason": ""}
	if gear_instance.is_empty():
		result["reason"] = "装备为空"
		return result

	var def_id: String = gear_instance.get("def_id", "")
	if not is_valid_gear(def_id):
		result["reason"] = "未知装备"
		return result

	var slot_id: String = get_gear_slot(def_id)
	if not is_slot_unlocked(slot_id):
		result["reason"] = "%s槽位未解锁（需要槽位等级Lv.%d）" % [SLOT_NAMES.get(slot_id, slot_id), _get_slot_unlock_level(slot_id)]
		return result

	var rarity: int = gear_instance.get("rarity", 1)
	if rarity >= ADVANCED_RARITY_MIN:
		# 检查高级位
		var used_advanced: int = _count_advanced_equipped(equipped)
		var total_advanced: int = get_advanced_slot_count()
		if used_advanced >= total_advanced:
			result["reason"] = "高级装备位不足（当前%d/%d）" % [used_advanced, total_advanced]
			return result

	result["ok"] = true
	return result

func _get_slot_unlock_level(slot_id: String) -> int:
	for lvl in SLOT_UNLOCKS.keys():
		if slot_id in SLOT_UNLOCKS[lvl]:
			return int(lvl)
	return 1

func _count_advanced_equipped(equipped: Dictionary) -> int:
	var count: int = 0
	for slot_id in equipped.keys():
		var inst: Dictionary = equipped[slot_id]
		if inst.is_empty():
			continue
		var def_id: String = inst.get("def_id", "")
		var rarity: int = get_gear_rarity(def_id)
		if rarity >= ADVANCED_RARITY_MIN:
			count += 1
	return count

# ===== 装备实例创建 =====

func create_instance(def_id: String, level: int = 1, rarity: int = -1) -> Dictionary:
	if not is_valid_gear(def_id):
		return {}
	var def: Dictionary = get_gear_def(def_id)
	if rarity < 0:
		rarity = def.get("rarity", 1)
	var r: int = clamp(rarity, 1, 5)
	var l: int = clamp(level, 1, def.get("max_level", 1))
	return {
		"def_id": def_id,
		"level": l,
		"rarity": r,
		"uid": "%s_%d_%d_%d" % [def_id, r, l, Time.get_ticks_msec()]
	}

# 获取某槽位下所有可用的装备定义（用于局内随机掉落）
func get_gear_for_slot(slot_id: String) -> Array[String]:
	var result: Array[String] = []
	for def_id in GEAR_DB.keys():
		var def: Dictionary = GEAR_DB[def_id]
		if def.get("slot", "") == slot_id:
			result.append(def_id)
	return result

# 随机生成一件某槽位的装备（按稀有度权重）
func random_gear_for_slot(slot_id: String, target_rarity: int = 1) -> Dictionary:
	var candidates: Array[String] = get_gear_for_slot(slot_id)
	if candidates.is_empty():
		return {}
	var def_id: String = candidates[randi() % candidates.size()]
	var r: int = clamp(target_rarity, 1, 5)
	return create_instance(def_id, 1, r)

# ===== 仓库管理 =====

func get_inventory() -> Array:
	return gear_inventory.duplicate(true)

func add_to_inventory(inst: Dictionary) -> void:
	if inst.is_empty() or not inst.has("def_id"):
		return
	gear_inventory.append(inst.duplicate(true))
	_save_progress()

func remove_from_inventory(uid: String) -> bool:
	for i in range(gear_inventory.size()):
		if gear_inventory[i].get("uid", "") == uid:
			gear_inventory.remove_at(i)
			_save_progress()
			return true
	return false

func find_inventory_by_uid(uid: String) -> Dictionary:
	for inst in gear_inventory:
		if inst.get("uid", "") == uid:
			return inst
	return {}

func get_gear_for_slot_from_inventory(slot_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for inst in gear_inventory:
		var def_id: String = inst.get("def_id", "")
		var def: Dictionary = get_gear_def(def_id)
		if def.get("slot", "") == slot_id:
			result.append(inst)
	return result

func count_identical(inst: Dictionary) -> Array[Dictionary]:
	## 返回仓库中与 inst 同名同星的所有装备（包括自身）
	var def_id: String = inst.get("def_id", "")
	var rarity: int = inst.get("rarity", 1)
	var result: Array[Dictionary] = []
	for item in gear_inventory:
		if item.get("def_id", "") == def_id and item.get("rarity", 1) == rarity:
			result.append(item)
	return result

func can_synthesize(base: Dictionary, fodder: Dictionary) -> bool:
	if base.is_empty() or fodder.is_empty():
		return false
	if base.get("def_id") != fodder.get("def_id"):
		return false
	if base.get("rarity") != fodder.get("rarity"):
		return false
	if base.get("rarity", 1) >= MAX_RARITY:
		return false
	return true

func synthesize(base_uid: String, fodder_uid: String) -> Dictionary:
	## 合成两件装备，返回新装备；失败返回空字典
	var base: Dictionary = find_inventory_by_uid(base_uid)
	var fodder: Dictionary = find_inventory_by_uid(fodder_uid)
	if not can_synthesize(base, fodder):
		return {}

	var target_rarity: int = base.get("rarity", 1) + 1
	var cost: int = SYNTH_COST.get(target_rarity, 0)
	if diamonds < cost:
		return {}

	# 先删材料（先删后面的避免索引移位）
	var base_idx: int = -1
	var fodder_idx: int = -1
	for i in range(gear_inventory.size()):
		if gear_inventory[i].get("uid", "") == base_uid:
			base_idx = i
		elif gear_inventory[i].get("uid", "") == fodder_uid:
			fodder_idx = i
	if base_idx < 0 or fodder_idx < 0:
		return {}
	if base_idx > fodder_idx:
		var tmp = base_idx
		base_idx = fodder_idx
		fodder_idx = tmp
	gear_inventory.remove_at(fodder_idx)
	gear_inventory.remove_at(base_idx)

	diamonds -= cost
	var new_inst: Dictionary = create_instance(base.get("def_id", ""), 1, target_rarity)
	gear_inventory.append(new_inst)
	_save_progress()
	return new_inst

func buy_random_gear(slot_id: String = "") -> Dictionary:
	if diamonds < BUY_GEAR_COST:
		return {}
	var target_slot: String = slot_id
	if target_slot.is_empty():
		target_slot = SLOT_ORDER[randi() % SLOT_ORDER.size()]
	var candidates: Array[String] = get_gear_for_slot(target_slot)
	if candidates.is_empty():
		return {}
	var def_id: String = candidates[randi() % candidates.size()]
	diamonds -= BUY_GEAR_COST
	var inst: Dictionary = create_instance(def_id, 1, 1)
	add_to_inventory(inst)
	return inst

# ===== 持久化 =====

func _save_progress() -> void:
	var data: Dictionary = {
		"slot_level": slot_level,
		"diamonds": diamonds,
		"gear_inventory": gear_inventory
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		slot_level = clamp(data.get("slot_level", 1), 1, 12)
		diamonds = max(data.get("diamonds", 0), 0)
		var inv = data.get("gear_inventory", [])
		if inv is Array:
			gear_inventory = inv.duplicate(true)

func reset_progress() -> void:
	slot_level = 1
	diamonds = 0
	last_run_diamonds = 0
	gear_inventory.clear()
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and dir.file_exists("equipment_save.json"):
		dir.remove("equipment_save.json")
