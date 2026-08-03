class_name LevelManager
extends Node

signal stage_started(stage_index: int, stage_name: String)
signal stage_completed(stage_index: int)
signal level_completed(level_data: LevelData)
signal level_failed(reason: String)

enum StageState { WAITING, RUNNING, COMPLETED }

@export var level_data: LevelData = null

@onready var _wave_manager: Node = get_node_or_null("/root/WaveManager")

var _current_stage_index: int = -1
var _stage_state: int = StageState.WAITING
var _stage_runtime: float = 0.0
var _level_runtime: float = 0.0
var _objective_node: LevelObjective = null
var _player: Node2D = null
var _is_level_running: bool = false
var _stage_delay_timer: Timer = null
var _crystal: Node2D = null
var _crystal_max_hp: float = 200.0

func _ready() -> void:
	add_to_group("level_manager")
	_stage_delay_timer = Timer.new()
	_stage_delay_timer.name = "StageDelayTimer"
	_stage_delay_timer.one_shot = true
	_stage_delay_timer.wait_time = 2.0
	_stage_delay_timer.timeout.connect(_run_next_stage)
	add_child(_stage_delay_timer)
	if level_data == null:
		push_warning("LevelManager: level_data is null, level mode will not run.")
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and _player.has_signal("died"):
		_player.died.connect(_on_player_died)
	if _wave_manager != null and _wave_manager.has_method("set_level_mode"):
		_wave_manager.set_level_mode(true)
	if _wave_manager != null and _wave_manager.has_signal("stage_spawn_done"):
		if _wave_manager.stage_spawn_done.is_connected(_on_wave_stage_done):
			_wave_manager.stage_spawn_done.disconnect(_on_wave_stage_done)
		_wave_manager.stage_spawn_done.connect(_on_wave_stage_done)
	_start_level()

func _spawn_crystal() -> void:
	var crystal_scene = preload("res://Scenes/crystal.tscn")
	_crystal = crystal_scene.instantiate()
	_crystal.global_position = Vector2(2560, 1440)
	_crystal.max_hp = _crystal_max_hp
	_crystal.crystal_destroyed.connect(_on_crystal_destroyed)
	_crystal.crystal_damaged.connect(_on_crystal_damaged)
	add_child(_crystal)

func _on_crystal_destroyed() -> void:
	_fail_level("crystal_destroyed")

func _on_crystal_damaged(current_hp: float, max_hp: float) -> void:
	if _objective_node != null and _objective_node.objective_type == LevelObjective.Type.DEFEND_TARGET:
		var hp_ratio: float = current_hp / max_hp if max_hp > 0.0 else 0.0
		if RunStats != null:
			RunStats.crystal_hp_ratio = hp_ratio
		if hp_ratio <= 0.0:
			_objective_node.mark_failed()

func _process(delta: float) -> void:
	if not _is_level_running:
		return
	_level_runtime += delta
	# 时间限制仅对非防守/存活目标生效（防守/存活类由目标自身判定完成）
	if level_data.time_limit > 0.0 and _level_runtime >= level_data.time_limit:
		var is_defend_or_survive: bool = _objective_node != null and (
			_objective_node.objective_type == LevelObjective.Type.DEFEND_TARGET or
			_objective_node.objective_type == LevelObjective.Type.SURVIVE_TIME)
		if not is_defend_or_survive:
			_fail_level("time_limit")
			return
	if _stage_state == StageState.RUNNING:
		_stage_runtime += delta
		if _objective_node != null and _objective_node.objective_type == LevelObjective.Type.SURVIVE_TIME:
			_objective_node.set_progress(_stage_runtime)
		elif _objective_node != null and _objective_node.objective_type == LevelObjective.Type.DEFEND_TARGET:
			_objective_node.set_progress(_stage_runtime)

func get_level_id() -> String:
	return level_data.level_id if level_data != null else ""

func get_current_stage_index() -> int:
	return _current_stage_index

func get_objective_progress() -> Vector2:
	if _objective_node == null:
		return Vector2.ZERO
	return Vector2(_objective_node.get_current_value(), _objective_node.target_value)

func get_objective_type() -> LevelObjective.Type:
	if _objective_node == null:
		return LevelObjective.Type.KILL_COUNT
	return _objective_node.objective_type

func _start_level() -> void:
	_current_stage_index = -1
	_stage_state = StageState.WAITING
	_level_runtime = 0.0
	_is_level_running = true
	_run_next_stage()

func _run_next_stage() -> void:
	_current_stage_index += 1
	_stage_runtime = 0.0
	if _current_stage_index >= level_data.get_stage_count():
		_complete_level()
		return
	var stage: Dictionary = level_data.get_stage(_current_stage_index)
	if stage.is_empty():
		push_warning("LevelManager: empty stage config at index %d" % _current_stage_index)
		_complete_level()
		return
	_stage_state = StageState.RUNNING
	_stage_setup_objective(stage)
	stage_started.emit(_current_stage_index, stage.get("name", "阶段 %d" % (_current_stage_index + 1)))
	if _wave_manager != null and _wave_manager.has_method("start_level_stage"):
		_wave_manager.start_level_stage(stage)

func _stage_setup_objective(stage: Dictionary) -> void:
	if _objective_node != null:
		if _objective_node.objective_completed.is_connected(_on_stage_objective_completed):
			_objective_node.objective_completed.disconnect(_on_stage_objective_completed)
		if _objective_node.objective_failed.is_connected(_on_stage_objective_failed):
			_objective_node.objective_failed.disconnect(_on_stage_objective_failed)
		_objective_node.queue_free()
		_objective_node = null
	var obj_type: String = stage.get("objective_type", "kill_count")
	var target: float = float(stage.get("target_value", 0.0))
	_objective_node = LevelObjective.new()
	_objective_node.name = "LevelObjective_%d" % _current_stage_index
	match obj_type:
		"survive_time":
			_objective_node.objective_type = LevelObjective.Type.SURVIVE_TIME
			_objective_node.target_value = target
		"kill_boss":
			_objective_node.objective_type = LevelObjective.Type.KILL_BOSS
			_objective_node.target_value = 1.0
		"protect_target":
			_objective_node.objective_type = LevelObjective.Type.DEFEND_TARGET
			_objective_node.target_value = target
			_spawn_crystal()
		"boss_rush":
			_objective_node.objective_type = LevelObjective.Type.KILL_BOSS
			_objective_node.target_value = 5.0
		_:
			_objective_node.objective_type = LevelObjective.Type.KILL_COUNT
			_objective_node.target_value = target
	_objective_node.objective_completed.connect(_on_stage_objective_completed)
	_objective_node.objective_failed.connect(_on_stage_objective_failed)
	add_child(_objective_node)

	if RunStats != null and RunStats.has_signal("kill_added"):
		if RunStats.kill_added.is_connected(_on_kill_added):
			RunStats.kill_added.disconnect(_on_kill_added)
		# boss_rush不连接击杀信号，由wave_manager控制BOSS击败计数
		if obj_type != "boss_rush" and (_objective_node.objective_type == LevelObjective.Type.KILL_COUNT or _objective_node.objective_type == LevelObjective.Type.KILL_BOSS):
			RunStats.kill_added.connect(_on_kill_added)
	if RunStats != null and RunStats.has_signal("boss_defeated"):
		if RunStats.boss_defeated.is_connected(_on_boss_defeated):
			RunStats.boss_defeated.disconnect(_on_boss_defeated)
		if _objective_node.objective_type == LevelObjective.Type.KILL_BOSS:
			RunStats.boss_defeated.connect(_on_boss_defeated)

func _on_kill_added(_total: int) -> void:
	if _objective_node == null or _objective_node.objective_type != LevelObjective.Type.KILL_COUNT:
		return
	_objective_node.add_progress(1.0)

func _on_boss_defeated() -> void:
	if _objective_node == null or _objective_node.objective_type != LevelObjective.Type.KILL_BOSS:
		return
	_objective_node.add_progress(1.0)

func _on_stage_objective_completed() -> void:
	if _stage_state != StageState.RUNNING:
		return
	_stage_state = StageState.COMPLETED
	stage_completed.emit(_current_stage_index)
	_grant_stage_rewards(level_data.get_stage(_current_stage_index))
	if _stage_delay_timer != null:
		_stage_delay_timer.start()

# wave_manager发出的stage_spawn_done信号（猎杀行动BOSS被击败）
func _on_wave_stage_done() -> void:
	if _stage_state != StageState.RUNNING:
		return
	_stage_state = StageState.COMPLETED
	stage_completed.emit(_current_stage_index)
	if _current_stage_index + 1 >= level_data.get_stage_count():
		_complete_level()
	else:
		if _stage_delay_timer != null:
			_stage_delay_timer.start()

func _on_stage_objective_failed() -> void:
	_fail_level("objective_failed")

func _on_player_died() -> void:
	_fail_level("player_died")

func _complete_level() -> void:
	_is_level_running = false
	if _crystal != null and not _crystal.is_destroyed() and RunStats != null:
		RunStats.crystal_hp_ratio = _crystal.get_hp_ratio()
	if _stage_delay_timer != null:
		_stage_delay_timer.stop()
	if _wave_manager != null and _wave_manager.has_method("set_level_mode"):
		_wave_manager.set_level_mode(false)
	level_completed.emit(level_data)

func _fail_level(reason: String) -> void:
	_is_level_running = false
	if level_data != null and RunStats != null:
		if level_data.level_id == "level_05":
			RunStats.crystal_hp_ratio = 0.0
			RunStats.complete_level(level_data.level_id)
		elif level_data.level_id == "level_06":
			# BOSS连战：根据已击败BOSS数保存星级
			var kills: int = 0
			if _wave_manager != null:
				kills = _wave_manager.get("_boss_rush_kills") if _wave_manager.get("_boss_rush_kills") != null else 0
			if kills >= 5:
				RunStats.crystal_hp_ratio = 1.0
			elif kills >= 3:
				RunStats.crystal_hp_ratio = 0.6
			elif kills >= 1:
				RunStats.crystal_hp_ratio = 0.4
			else:
				RunStats.crystal_hp_ratio = 0.0
			RunStats.complete_level(level_data.level_id)
	if _stage_delay_timer != null:
		_stage_delay_timer.stop()
	if _wave_manager != null and _wave_manager.has_method("set_level_mode"):
		_wave_manager.set_level_mode(false)
	level_failed.emit(reason)

func _grant_stage_rewards(stage: Dictionary) -> void:
	var rewards: Dictionary = stage.get("rewards", {})
	var exp_amount: int = rewards.get("exp", 0) as int
	if exp_amount > 0 and _player != null and _player.has_method("gain_exp"):
		_player.gain_exp(exp_amount)

func _exit_tree() -> void:
	if _player != null and _player.has_signal("died"):
		if _player.died.is_connected(_on_player_died):
			_player.died.disconnect(_on_player_died)
	if _wave_manager != null and _wave_manager.has_signal("stage_spawn_done"):
		if _wave_manager.stage_spawn_done.is_connected(_on_wave_stage_done):
			_wave_manager.stage_spawn_done.disconnect(_on_wave_stage_done)
	if _objective_node != null:
		if _objective_node.objective_completed.is_connected(_on_stage_objective_completed):
			_objective_node.objective_completed.disconnect(_on_stage_objective_completed)
		if _objective_node.objective_failed.is_connected(_on_stage_objective_failed):
			_objective_node.objective_failed.disconnect(_on_stage_objective_failed)
	if RunStats != null and RunStats.has_signal("kill_added"):
		if RunStats.kill_added.is_connected(_on_kill_added):
			RunStats.kill_added.disconnect(_on_kill_added)
	if RunStats != null and RunStats.has_signal("boss_defeated"):
		if RunStats.boss_defeated.is_connected(_on_boss_defeated):
			RunStats.boss_defeated.disconnect(_on_boss_defeated)
