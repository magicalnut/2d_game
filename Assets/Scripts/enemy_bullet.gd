extends Area2D

## 敌方子弹（由远程敌人 agent 等发射）：朝玩家方向直线飞行，不追踪，可被走位躲开。
## 命中 "player" 组的节点造成伤害；飞出背景边界或超时则销毁。
## 与玩家的追踪弹（bullet.gd）区分：只打玩家、纯直线、无锁定目标。

@export var speed: float = 600.0
@export var damage: float = 1.0
@export var max_lifetime: float = 5.0

var direction: Vector2 = Vector2.RIGHT
var impact_tex: Texture2D = null   # 命中玩家时播放的专属命中特效（由发射者设置，可选；缺省无特效）
var spin_speed: float = 0.0    # >0 时子弹自旋（弧度/秒），不影响飞行方向
var stun_duration: float = 0.0 # >0 时命中玩家后定身N秒
var _life: float = 0.0
var _spin_acc: float = 0.0

func _ready() -> void:
	add_to_group("enemy_bullet")   # 供时空沙漏在冻结时清除（"敌对攻击消失"）
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		queue_free()
		return
	global_position += direction * speed * delta
	rotation = direction.angle()
	if spin_speed > 0.0:
		_spin_acc += spin_speed * delta
		var sp: Sprite2D = get_node_or_null("Sprite2D")
		if sp != null:
			sp.rotation = _spin_acc
	# 飞出背景边界则销毁
	if global_position.x < -80.0 or global_position.x > 5200.0 \
	   or global_position.y < -80.0 or global_position.y > 2960.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if stun_duration > 0.0 and body.has_method("stun"):
			body.stun(stun_duration)
		_spawn_impact(global_position)
		queue_free()

# 命中玩家时播放专属命中特效（放到场景根，用树级补间，子弹销毁也不影响特效淡出）
func _spawn_impact(pos: Vector2) -> void:
	if impact_tex == null:
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var s := Sprite2D.new()
	s.texture = impact_tex
	s.global_position = pos
	s.centered = true
	s.z_index = 16
	s.scale = Vector2.ONE * 0.5
	root.add_child(s)
	var tw := get_tree().create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 1.05, 0.16)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.30)
	tw.tween_callback(s.queue_free)
