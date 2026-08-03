extends StaticBody2D

## 水晶：关卡防守目标，敌人会主动攻击水晶。
## 水晶血量归零则关卡失败。

signal crystal_destroyed
signal crystal_damaged(current_hp: float, max_hp: float)

@export var max_hp: float = 100.0
var _current_hp: float = 100.0
var _dead: bool = false

func _ready() -> void:
	add_to_group("crystal")
	_current_hp = max_hp
	queue_redraw()

func _draw() -> void:
	# 绘制水晶主体（菱形）
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -40),
		Vector2(30, 0),
		Vector2(0, 40),
		Vector2(-30, 0)
	])
	var colors: PackedColorArray = PackedColorArray([
		Color(0.3, 0.7, 1.0, 0.9),
		Color(0.5, 0.85, 1.0, 0.95),
		Color(0.3, 0.7, 1.0, 0.9),
		Color(0.2, 0.5, 0.9, 0.85)
	])
	draw_polygon(points, colors)
	# 绘制发光效果
	draw_circle(Vector2.ZERO, 20.0, Color(0.4, 0.8, 1.0, 0.3))
	draw_circle(Vector2.ZERO, 12.0, Color(0.6, 0.9, 1.0, 0.5))
	# 绘制血条
	var bar_width: float = 60.0
	var bar_height: float = 6.0
	var bar_y: float = -55.0
	var hp_ratio: float = _current_hp / max_hp
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	var fill_color: Color = Color(0.2, 0.8, 0.2) if hp_ratio > 0.5 else Color(0.9, 0.5, 0.1) if hp_ratio > 0.25 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * hp_ratio, bar_height), fill_color)

func take_damage(amount: float) -> void:
	if _dead:
		return
	_current_hp = max(_current_hp - amount, 0.0)
	crystal_damaged.emit(_current_hp, max_hp)
	queue_redraw()
	if _current_hp <= 0.0:
		_dead = true
		crystal_destroyed.emit()

func get_hp_ratio() -> float:
	return _current_hp / max_hp if max_hp > 0.0 else 0.0

func is_destroyed() -> bool:
	return _dead
