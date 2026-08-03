extends Node

const SAVE_PATH: String = "user://save.json"
const SLOTS_PATH: String = "user://slots.json"
const SLOT_COUNT: int = 4   # 存档槽总数（2×2 布局）

signal save_loaded

var slot_level: int = 1
var diamonds: int = 0
var gear_inventory: Array = []
var completed_levels: Array[String] = []
var unlocked_levels: Array[String] = ["level_01"]
var character_gear: Dictionary = {}
var settings: Dictionary = {
	"master_volume": 1.0,
	"fullscreen": false,
}

var pending_restore_slot: int = -1
var pending_restore_data: Dictionary = {}
var active_slot: int = -1     # 当前这一局绑定的存档槽（开始游戏/读档时设定；暂停「保存游戏」已移除，改为自动落档）
var menu_load_slot: int = -1   # 瞬态（不持久化）：主菜单「读取存档」点选后，待进入角色选择页的槽位；-1=非读档模式
var back_to_loadout: bool = false  # 瞬态：阵亡/关卡结束「返回战备页」标记，让角色选择页跳过转盘直接进战备（出战整备）页

func _ready() -> void:
	_load()
	apply_settings()

func apply_settings() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		var vol_linear: float = clampf(settings.get("master_volume", 1.0), 0.0, 1.0)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(vol_linear))
	var full: bool = settings.get("fullscreen", false)
	if full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func update_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save()

func save() -> void:
	# 注意：槽位等级/钻石/仓库(gear_inventory) 已改为「每存档槽独立」，存于 slots.json 的 per-slot state["equip"]，
	# 不再写入全局 save.json（否则会跨槽污染，导致新建/读档继承残留等级与钻石）。
	var data := {
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
		"character_gear": character_gear,
		"settings": settings,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

func _load() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file != null:
		var json_str: String = file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(json_str)
		if parsed is Dictionary:
			var data: Dictionary = parsed
			# slot_level/diamonds/gear_inventory 不再从全局读（已 per-slot 化）
			completed_levels.assign(data.get("completed_levels", []))
			unlocked_levels.assign(data.get("unlocked_levels", ["level_01"]))
			var cg = data.get("character_gear", {})
			if cg is Dictionary:
				character_gear = cg.duplicate(true)
			var st = data.get("settings", {})
			if st is Dictionary:
				settings = st.duplicate(true)
			save_loaded.emit()
			return

	_migrate_old_saves()

func _migrate_old_saves() -> void:
	var level_path := "user://level_progress.json"
	# 旧版 equipment_save.json 的全局养成数据已无意义（现 per-slot 化），不再迁移
	if FileAccess.file_exists(level_path):
		var file := FileAccess.open(level_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				completed_levels.assign(parsed.get("completed_levels", []))
				unlocked_levels.assign(parsed.get("unlocked_levels", ["level_01"]))

	_cleanup_old_saves()
	save()

func _cleanup_old_saves() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		for old in ["equipment_save.json", "level_progress.json"]:
			if dir.file_exists(old):
				dir.remove(old)

func reset_all() -> void:
	slot_level = 1
	diamonds = 0
	gear_inventory.clear()
	completed_levels.clear()
	unlocked_levels = ["level_01"]
	character_gear.clear()
	settings = {"master_volume": 1.0, "fullscreen": false}
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save.json"):
		dir.remove("save.json")

func get_slot_meta(index: int) -> Dictionary:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return {}
	var data = slots[index]
	if data == null:
		return {}
	return data.get("meta", {})

# 把一个存档槽绑定到某个角色（「一个存档对应一个角色」）。只更新 meta.character，
# 不影响 equip 等其它字段；槽位不存在或为空时安全跳过。
func set_slot_character(index: int, char_id: String) -> void:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return
	var state: Dictionary = {}
	if slots[index] is Dictionary:
		state = slots[index].duplicate(true)
	else:
		state = {"equip": {}, "meta": {}}
	if not (state.get("meta") is Dictionary):
		state["meta"] = {}
	state["meta"]["character"] = char_id
	slots[index] = state
	_write_slots_file(slots)

func save_in_game_slot(index: int, state: Dictionary) -> void:
	var slots := _read_slots_file()
	state["meta"] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"mode": state.get("run_stats", {}).get("game_mode", ""),
		"character": state.get("run_stats", {}).get("chosen_character", ""),
		"difficulty": state.get("run_stats", {}).get("deploy_difficulty", 0),
		"wave_info": state.get("wave_state", {}).get("wave_info", ""),
		"kills": state.get("run_stats", {}).get("kills", 0),
		"time_survived": state.get("run_stats", {}).get("time_survived", 0.0),
	}
	if index >= 0 and index < slots.size():
		slots[index] = state
	_write_slots_file(slots)

func clear_slot(index: int) -> void:
	var slots := _read_slots_file()
	if index >= 0 and index < slots.size():
		slots[index] = null
		_write_slots_file(slots)

# 新建存档：立刻在该槽落盘一份「初始养成存档」，让主菜单存档列表马上就能看到它。
# 只写 equip + meta，不含中途快照（player_state/wave_state/run_stats/skills），
# 因此读它会走「养成存档」分支 → 角色选择页 → 整备页，与阵亡档语义一致。
# 若不写 meta，主菜单按 meta.is_empty() 会判为「（空）」，玩家会以为新建失败。
func init_new_slot(index: int, equip: Dictionary) -> void:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return
	slots[index] = {
		"equip": equip.duplicate(true),
		"meta": {
			"timestamp": Time.get_datetime_string_from_system(),
			"mode": "",
			"character": "",
			"difficulty": 0,
			"wave_info": "新存档 · 尚未出战",
			"kills": 0,
			"time_survived": 0.0,
			"run_state": "new",
		},
	}
	_write_slots_file(slots)

# 本局结束（阵亡）：把该存档槽固化为「养成存档」。
# 保留局外养成（equip：槽位等级/钻石/仓库/出战配装），清除本局中途快照（player_state/wave_state/run_stats/skills），
# 并写入 meta。meta 是关键：槽内若只有 equip 而无 meta，主菜单会按 meta.is_empty() 判为「（空）」并禁用卡片，
# 玩家读不到自己攒下的养成，还会误当空槽新建而被 clear_slot 抹掉 —— 那才是真的白打。
func finalize_run_slot(index: int, summary: Dictionary) -> void:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return
	var state: Dictionary = {}
	if slots[index] is Dictionary:
		state = slots[index].duplicate(true)
	# 阵亡后不可再读回死前局面（roguelike：本局结束，养成留存）
	state.erase("player_state")
	state.erase("wave_state")
	state.erase("run_stats")
	state.erase("skills")
	# 出战配装随存档走，避免下次读该档时沿用别的存档槽残留的配装
	var equip: Dictionary = {}
	if state.has("equip") and state["equip"] is Dictionary:
		equip = state["equip"].duplicate(true)
	equip["equipped_gear"] = summary.get("equipped_gear", {})
	state["equip"] = equip
	state["meta"] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"mode": summary.get("mode", ""),
		"character": summary.get("character", ""),
		"difficulty": summary.get("difficulty", 0),
		"wave_info": summary.get("wave_info", ""),
		"kills": summary.get("kills", 0),
		"time_survived": summary.get("time_survived", 0.0),
		"run_state": "dead",
	}
	slots[index] = state
	_write_slots_file(slots)

# 把当前局外养成（槽位等级/钻石/仓库）固化进指定存档槽的 state["equip"]，
# 不动其它字段（run_stats/wave_state/skills/meta），实现「每存档独立」。
func write_slot_equip(index: int, equip: Dictionary) -> void:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return
	var state: Dictionary = {}
	if slots[index] is Dictionary:
		state = slots[index].duplicate(true)
	state["equip"] = equip.duplicate(true)
	slots[index] = state
	_write_slots_file(slots)

func load_in_game_slot(index: int) -> Dictionary:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return {}
	var data = slots[index]
	if data == null:
		return {}
	pending_restore_slot = index
	active_slot = index
	pending_restore_data = data.duplicate(true)
	return pending_restore_data

func consume_pending_restore() -> Dictionary:
	pending_restore_slot = -1
	var data = pending_restore_data.duplicate(true)
	pending_restore_data.clear()
	return data

func _read_slots_file() -> Array:
	var file := FileAccess.open(SLOTS_PATH, FileAccess.READ)
	if file == null:
		return _empty_slots()
	var json_str: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if parsed is Array:
		# 兼容旧版 3 槽存档：读到几个就保留几个，再补齐到 SLOT_COUNT
		var arr: Array = parsed
		while arr.size() < SLOT_COUNT:
			arr.append(null)
		return arr
	return _empty_slots()

func _empty_slots() -> Array:
	var a: Array = []
	for i in SLOT_COUNT:
		a.append(null)
	return a

func _write_slots_file(slots: Array) -> void:
	var file := FileAccess.open(SLOTS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(slots))
		file.close()
