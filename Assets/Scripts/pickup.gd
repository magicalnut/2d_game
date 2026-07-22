extends Area2D

## 掉落物基类：玩家靠近时自动吸附（磁铁效果），进入拾取半径则被收集。
## 子类只需重写 _collect(player) 实现具体效果（加经验 / 回血等）。

@export var attract_radius: float = 130.0   # 玩家进入此范围，掉落物被吸向玩家
@export var attract_speed: float = 460.0    # 吸附飞行速度
@export var collect_radius: float = 16.0    # 进入此范围即被拾取

var _player: Node2D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
	# 重新获取玩家（可能延迟加入 / 重载场景）
	if _player == null or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return

	var dist: float = global_position.distance_to(_player.global_position)
	if dist <= collect_radius:
		_collect(_player)
		return

	var r: float = _get_attract_radius()
	if dist <= r:
		var dir: Vector2 = (_player.global_position - global_position).normalized()
		global_position += dir * attract_speed * delta

func _get_attract_radius() -> float:
	# 允许玩家用 magnet_radius 升级扩大拾取范围
	if _player != null and _player.has_method("get_magnet_radius"):
		return _player.get_magnet_radius()
	return attract_radius

func _collect(_player: Node2D) -> void:
	# 子类重写：具体效果；基类仅做销毁
	queue_free()
