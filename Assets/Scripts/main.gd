extends Node2D

const LEVEL_DATA_PATH := "res://Assets/Resources/Levels/"

func _ready() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p != null and p.has_signal("died"):
		p.died.connect(_on_player_died)

	if SaveManager != null and SaveManager.pending_restore_slot >= 0:
		_setup_restore()
		return

	if RunStats != null and RunStats.game_mode == "level":
		_setup_level_mode()
	else:
		_setup_endless_mode()
	# 猎杀行动：apply_run_mods 在 _setup_level_mode 中已被调用，现在回满血
	if RunStats != null and RunStats.game_mode == "level" and RunStats.selected_level_id == "level_05":
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null and pl.has_method("heal") and pl.has_method("get_max_hp") and pl.has_method("get_hp"):
			pl.heal(pl.get_max_hp() - pl.get_hp())

var _restore_player_state: Dictionary = {}
var _restore_wave_state: Dictionary = {}

func _setup_restore() -> void:
	var data: Dictionary = SaveManager.consume_pending_restore()
	_restore_player_state = data.get("player_state", {})
	_restore_wave_state = data.get("wave_state", {})
	# 进入游戏默认满血：不继承存档里的血量（restore_state 缺失 hp 时回退到 max_hp）
	_restore_player_state.erase("hp")
	var run_stats_data: Dictionary = data.get("run_stats", {})
	var skills_data: Dictionary = data.get("skills", {})

	if SkillManager != null and not skills_data.is_empty():
		SkillManager.owned = skills_data.duplicate(true)

	if RunStats != null and not run_stats_data.is_empty():
		RunStats.restore_from_save(run_stats_data)

	# 关卡模式快照读档：restore_from_save 已把 game_mode/selected_level_id 恢复为存档值，
	# 但本函数不像普通开局那样走 _setup_level_mode，必须在此重建 LevelManager，
	# 否则关卡模式会被静默降级成无尽模式（玩家读档后"只能进无尽模式"）。
	if RunStats != null and RunStats.game_mode == "level":
		_setup_restore_level_mode()

	# 读档：恢复该存档槽固化的养成数据（槽位等级/钻石/仓库）。放在 restore 之后，
	# 确保用存档值覆盖任何残留的运行时值。
	if EquipmentManager != null:
		var equip: Dictionary = data.get("equip", {})
		if not equip.is_empty():
			EquipmentManager.apply_equip_state(equip)

	_create_special_select_ui()

	call_deferred("_apply_restore_state")

func _apply_restore_state() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and not _restore_player_state.is_empty() and player.has_method("restore_state"):
		player.restore_state(_restore_player_state)
	if WaveManager != null and not _restore_wave_state.is_empty() and WaveManager.has_method("restore_state"):
		WaveManager.restore_state(_restore_wave_state)
	_restore_player_state.clear()
	_restore_wave_state.clear()

func _create_special_select_ui() -> void:
	var ss := CanvasLayer.new()
	ss.name = "SpecialSelectUI"
	ss.layer = 21
	ss.process_mode = Node.PROCESS_MODE_ALWAYS
	ss.set_script(preload("res://Assets/Scripts/special_select_ui.gd"))
	add_child(ss)

func _setup_endless_mode() -> void:
	if RunStats != null and SkillManager != null:
		SkillManager.grant(RunStats.get_character_def().get("start_weapon", ""))
	_create_special_select_ui()

func _setup_level_mode() -> void:
	var level_id: String = RunStats.selected_level_id
	if level_id.is_empty():
		push_warning("main.gd: level mode selected but selected_level_id is empty. Falling back to endless.")
		_setup_endless_mode()
		return

	var level_data: LevelData = _load_level_data(level_id)
	if level_data == null:
		push_error("main.gd: failed to load level data for '%s'" % level_id)
		_setup_endless_mode()
		return

	if RunStats != null and SkillManager != null:
		SkillManager.grant(RunStats.get_character_def().get("start_weapon", ""))

	var lm := Node.new()
	lm.name = "LevelManager"
	lm.set_script(preload("res://Assets/Scripts/level_manager.gd"))
	lm.set("level_data", level_data)
	add_child(lm)

	if lm.has_signal("level_completed"):
		lm.level_completed.connect(_on_level_completed)
	if lm.has_signal("level_failed"):
		lm.level_failed.connect(_on_level_failed)

# 快照读档专用的关卡模式建立：不重复授予技能（SkillManager.owned 已由 _setup_restore 恢复）、
# 不重复创建 special_select_ui（_setup_restore 已建），只重建 LevelManager 让关卡目标/进度接管。
func _setup_restore_level_mode() -> void:
	var level_id: String = RunStats.selected_level_id
	if level_id.is_empty():
		push_warning("main.gd: restore level mode but selected_level_id empty; skipping LevelManager.")
		return
	var level_data: LevelData = _load_level_data(level_id)
	if level_data == null:
		push_warning("main.gd: restore failed to load level data '%s'; skipping LevelManager." % level_id)
		return
	var lm := Node.new()
	lm.name = "LevelManager"
	lm.set_script(preload("res://Assets/Scripts/level_manager.gd"))
	lm.set("level_data", level_data)
	add_child(lm)
	if lm.has_signal("level_completed"):
		lm.level_completed.connect(_on_level_completed)
	if lm.has_signal("level_failed"):
		lm.level_failed.connect(_on_level_failed)

func _load_level_data(level_id: String) -> LevelData:
	var path: String = LEVEL_DATA_PATH + level_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as LevelData

func _on_player_died() -> void:
	if RunStats != null and RunStats.game_mode == "level":
		return
	var go = get_node_or_null("GameOverUI")
	if go != null and go.has_method("show_game_over"):
		go.show_game_over()

func _on_level_completed(_level_data: LevelData) -> void:
	RunStats.level_mode_result = "victory"
	var go = get_node_or_null("GameOverUI")
	if go != null and go.has_method("show_level_complete"):
		go.show_level_complete(_level_data)

func _on_level_failed(reason: String) -> void:
	RunStats.level_mode_result = "defeat"
	var go = get_node_or_null("GameOverUI")
	if go != null and go.has_method("show_level_failed"):
		go.show_level_failed(reason)
	elif go != null and go.has_method("show_game_over"):
		go.show_game_over()
