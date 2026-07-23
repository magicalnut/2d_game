extends Area2D

## 自动追踪子弹：发射时由 player.gd 设定 target（锁定敌人）或 direction（朝人物前进方向直飞）。
## 有 target 时持续转向跟踪该敌人；无 target 时按 direction 直线飞行。
## 飞出背景边界或超时则销毁。

@export var speed: float = 960.0
@export var damage: float = 1.0
@export var turn_speed: float = 12.0     # 每秒最大转向弧度（跟踪灵敏度）
@export var max_lifetime: float = 4.0     # 最大存活时间，防止无限飞行

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null
var _life: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		queue_free()
		return

	# 有锁定目标则持续转向跟踪；无目标则按 direction 直飞
	# 目标已死亡则放弃追踪，改为直飞，避免追着尸体
	if is_instance_valid(target) and target.is_inside_tree() \
	   and not (target.has_method("is_dead") and target.is_dead()):
		var desired: Vector2 = (target.global_position - global_position).normalized()
		# 注意：Godot 的 angle_difference(from, to) 返回 to - from，故这里传 (current, desired)
		# 得到 desired - current，再据此把 direction 朝目标旋转
		var diff: float = angle_difference(direction.angle(), desired.angle())
		var step: float = clamp(diff, -turn_speed * delta, turn_speed * delta)
		direction = direction.rotated(step).normalized()

	global_position += direction * speed * delta
	rotation = direction.angle()

	# 飞出背景边界则销毁
	if global_position.x < -80 or global_position.x > 5200 \
	   or global_position.y < -80 or global_position.y > 2960:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
