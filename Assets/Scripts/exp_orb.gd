extends "res://Assets/Scripts/pickup.gd"

## 经验球：被玩家拾取后增加经验值，攒满升级条后触发升级。

@export var exp_value: float = 2.0

func _collect(player: Node2D) -> void:
	if player.has_method("gain_exp"):
		player.gain_exp(exp_value)
	queue_free()
