extends Node2D

## 时空沙漏（特殊武器）：挂在玩家节点下。
## - 每隔一段时间（间隔不短，避免破坏平衡）冻结全场敌人：锁住移动与攻击。
## - 同时清除屏幕上所有敌方子弹（"敌对攻击也消失"）。
## - 升级：冻结时长增加；2★ 起对冻结中的敌人造成微量持续伤害。
## 数值从 SkillManager.stars(skill_id) 实时读取。

var skill_id: String = "special_hourglass"
var _player: Node2D = null

var _timer: float = 0.0
var _interval: float = 24.0
var _freeze_duration: float = 2.0
var _freeze_remaining: float = 0.0
var _active: bool = false

func _ready() -> void:
	_player = get_parent()
	_apply_stats()

func _apply_stats() -> void:
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		st = 1
	_interval = max(14.0, 24.0 - 2.5 * float(st - 1))   # 1★≈24s … 5★≈14s
	_freeze_duration = 2.0 + 0.5 * float(st - 1)         # 1★=2s … 5★=4s

func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		return
	if _interval != max(14.0, 24.0 - 2.5 * float(st - 1)):
		_apply_stats()
	if _active:
		_freeze_remaining -= delta
		# 进化（≥2★）后对冻结敌人造成微量持续伤害
		if st >= 2:
			var dps: float = 0.25 * float(st - 1)
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.has_method("take_damage") and e.has_method("is_dead") and not e.is_dead():
					e.take_damage(dps * delta)
		if _freeze_remaining <= 0.0:
			_unfreeze_all()
			_active = false
		return
	_timer -= delta
	if _timer <= 0.0:
		_trigger()

func _trigger() -> void:
	_active = true
	_freeze_remaining = _freeze_duration
	_timer = _interval
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("set_frozen"):
			e.set_frozen(true)
	# 敌对攻击消失：清掉屏幕上所有敌方子弹
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		b.queue_free()

func _unfreeze_all() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("set_frozen"):
			e.set_frozen(false)
