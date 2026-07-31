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
	var data := {
		"slot_level": slot_level,
		"diamonds": diamonds,
		"gear_inventory": gear_inventory,
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
			slot_level = clamp(data.get("slot_level", 1), 1, 12)
			diamonds = max(data.get("diamonds", 0), 0)
			var inv = data.get("gear_inventory", [])
			if inv is Array:
				gear_inventory = inv.duplicate(true)
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
	var equip_path := "user://equipment_save.json"
	var level_path := "user://level_progress.json"

	if FileAccess.file_exists(equip_path):
		var file := FileAccess.open(equip_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				slot_level = clamp(parsed.get("slot_level", 1), 1, 12)
				diamonds = max(parsed.get("diamonds", 0), 0)
				var inv = parsed.get("gear_inventory", [])
				if inv is Array:
					gear_inventory = inv.duplicate(true)

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

func load_in_game_slot(index: int) -> Dictionary:
	var slots := _read_slots_file()
	if index < 0 or index >= slots.size():
		return {}
	var data = slots[index]
	if data == null:
		return {}
	pending_restore_slot = index
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
