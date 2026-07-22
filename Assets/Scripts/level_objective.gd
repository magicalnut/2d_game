class_name LevelObjective
extends Node

enum Type {
	KILL_COUNT,
	SURVIVE_TIME,
	DEFEND_TARGET,
	KILL_BOSS
}

signal objective_updated(current_value: float, target_value: float)
signal objective_completed
signal objective_failed

@export var objective_type: Type = Type.KILL_COUNT
@export var target_value: float = 0.0

var _current_value: float = 0.0
var _is_completed: bool = false
var _is_failed: bool = false

func _ready() -> void:
	add_to_group("level_objective")
	_current_value = 0.0
	objective_updated.emit(_current_value, target_value)

func get_current_value() -> float:
	return _current_value

func is_completed() -> bool:
	return _is_completed

func is_failed() -> bool:
	return _is_failed

func add_progress(amount: float) -> void:
	if _is_completed or _is_failed:
		return
	_current_value += amount
	_check_completion()
	objective_updated.emit(_current_value, target_value)

func set_progress(value: float) -> void:
	if _is_completed or _is_failed:
		return
	_current_value = value
	_check_completion()
	objective_updated.emit(_current_value, target_value)

func mark_failed() -> void:
	if _is_completed or _is_failed:
		return
	_is_failed = true
	objective_failed.emit()

func _check_completion() -> void:
	if _is_completed or _is_failed:
		return
	if objective_type == Type.SURVIVE_TIME or objective_type == Type.DEFEND_TARGET:
		if _current_value >= target_value:
			_is_completed = true
			objective_completed.emit()
	else:
		if _current_value >= target_value:
			_is_completed = true
			objective_completed.emit()
