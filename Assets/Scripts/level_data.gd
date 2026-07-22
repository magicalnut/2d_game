class_name LevelData
extends Resource

@export var level_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var unlock_requirement: String = ""
@export var time_limit: float = 0.0
@export var stages: Array[Dictionary] = []
@export var rewards: Dictionary = {}
@export var difficulty_multiplier: float = 1.0

func get_stage_count() -> int:
	return stages.size()

func get_stage(index: int) -> Dictionary:
	if index < 0 or index >= stages.size():
		return {}
	return stages[index]

func get_diamond_reward() -> int:
	return rewards.get("diamonds", 0) as int

func get_first_clear_gear_id() -> String:
	return rewards.get("first_clear_gear", "") as String
