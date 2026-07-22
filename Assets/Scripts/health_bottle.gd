extends "res://Assets/Scripts/pickup.gd"

## 血瓶：被玩家拾取后回复生命值。掉率远低于经验球（见 enemy.gd）。

@export var heal_amount: float = 2.0

func _collect(player: Node2D) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	queue_free()
