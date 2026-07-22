extends Area2D

## 火焰区域：燃烧瓶命中敌人或飞抵终点后生成，持续对范围内敌人造成 DOT。
## 视觉直接用用户提供的"燃烧效果.png"（按半径缩放，带轻微闪烁）。
## 伤害模型：怪物处于火焰圈内时，每个 tick 持续结算（入圈即持续掉血）。

const FIRE_TEX := preload("res://Assets/Sprites/Effects/fire_effect.png")
const TEX_SIZE: float = 384.0

var radius: float = 60.0
var duration: float = 2.5
var tick_interval: float = 0.5
var damage: float = 1.0
var opacity: float = 0.5        # 火焰贴图透明度（0~1）；调低以免遮挡敌对生物

var _life: float = 0.0
var _tick: float = 0.0
var _sprite: Sprite2D = null
var _base_scale: float = 1.0

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = FIRE_TEX
	_sprite.modulate.a = opacity    # 降低不透明度，避免遮挡敌人
	# 火焰贴图直径应覆盖整个火焰圈
	_base_scale = (radius * 2.0) / TEX_SIZE
	_sprite.scale = Vector2(_base_scale, _base_scale)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		queue_free()
		return
	_tick += delta
	if _tick >= tick_interval:
		_tick -= tick_interval
		_damage_in_range()
	# 轻微闪烁：基准缩放上做 ±2% 脉动（频率放慢），让火焰有呼吸感但不再明显胀缩
	var pulse: float = 1.0 + 0.02 * sin(_life * 6.0)
	_sprite.scale = Vector2(_base_scale * pulse, _base_scale * pulse)

# 持续伤害：范围内（在圈内的）敌人每个 tick 结算一次
func _damage_in_range() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if global_position.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(damage)
