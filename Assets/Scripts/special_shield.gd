extends Node2D

## 守护圣盾（特殊武器）：挂在玩家节点下。
## - 只在玩家头顶血条下方绘制护盾条 + 小盾牌图标。
## - 护盾条与血条等长、左右对齐（左缘对齐血条左缘，右缘对齐血条右缘）。
## - 拦截伤害：玩家受击时先扣护盾值，护盾归零才扣血。
## - 脱战（一段时间未受击）自动恢复护盾值。
## - 星级越高：护盾上限越高、回复越快。
## 数值全部从 SkillManager.stars(skill_id) 实时读取，升级即时生效。

var skill_id: String = "special_shield"
var _player: Node2D = null
var _val_label: Label = null

var _shield_max: float = 1.0
var _shield_value: float = 0.0
var _since_hit: float = 0.0
var _regen_delay: float = 4.0     # 脱战多少秒后开始回盾
var _regen_rate: float = 0.4      # 每秒回盾量

# 运行时按玩家 hp_bar_width / hp_bar_y 计算（与血条等长、左右对齐、置于血条下方）
var _bar_y0: float = -37.0
var _bar_x0: float = -24.0
var _bar_w: float = 48.0
var _icon_x: float = -43.0

const ICON_SIZE: float = 16.0
const BAR_H: float = 5.0
const GAP: float = 3.0

const SHIELD_TEX := preload("res://Assets/Sprites/Skills/special_shield.png")

func _ready() -> void:
	_player = get_parent()
	if _player != null and _player.has_method("get") and "shield_handler" in _player:
		_player.shield_handler = self

	# 读取玩家头顶血条几何，让护盾条与血条等长、左右对齐，并落在血条正下方
	var hpw: float = 48.0
	var hpy: float = -46.0
	if _player != null and _player.has_method("get"):
		if _player.get("hp_bar_width") != null:
			hpw = float(_player.hp_bar_width)
		if _player.get("hp_bar_y") != null:
			hpy = float(_player.hp_bar_y)
	_bar_w = hpw
	_bar_x0 = -hpw * 0.5               # 与血条左缘对齐 → 右缘自然与血条右缘对齐
	_bar_y0 = hpy + 9.0                # 血条下方 9px，不遮挡头部
	_icon_x = _bar_x0 - GAP - ICON_SIZE  # 小盾牌图标紧贴条左侧

	# 数值标签：叠在护盾条上，居中显示 "当前/最大"
	_val_label = Label.new()
	_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_val_label.add_theme_font_size_override("font_size", 9)
	_val_label.position = Vector2(_bar_x0, _bar_y0 - 3.0)
	_val_label.size = Vector2(_bar_w, 12.0)
	add_child(_val_label)

	_apply_stats()
	_shield_value = _shield_max
	_update_label()
	queue_redraw()

func _apply_stats() -> void:
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		st = 1
	_shield_max = 2.0 + 2.0 * float(st - 1)     # 1★=2 … 5★=10
	_regen_rate = 0.4 + 0.15 * float(st - 1)
	_update_label()
	queue_redraw()

# 玩家受伤时由 player.take_damage 调用：先吃护盾，返回还需扣血的量
func absorb(amount: float) -> float:
	if _shield_value <= 0.0:
		return amount
	var leftover: float = amount - _shield_value
	_shield_value = max(0.0, _shield_value - amount)
	_since_hit = 0.0
	_update_label()
	queue_redraw()
	return max(0.0, leftover)

func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		return
	# 星级变化时同步数值（升级即时生效），并补满盾
	if abs(_shield_max - (2.0 + 2.0 * float(st - 1))) > 0.001:
		_apply_stats()
		_shield_value = _shield_max
	# 护盾条不再跟随朝向移动，固定于头顶血条下方
	_since_hit += delta
	if _since_hit >= _regen_delay and _shield_value < _shield_max:
		var before: float = _shield_value
		_shield_value = min(_shield_max, _shield_value + _regen_rate * delta)
		if _shield_value != before:
			_update_label()
			queue_redraw()

func _update_label() -> void:
	if _val_label == null:
		return
	_val_label.text = "%d/%d" % [int(round(_shield_value)), int(round(_shield_max))]

# 在玩家头顶血条下方绘制：小盾牌图标 + 与血条等长且左右对齐的护盾值细条
func _draw() -> void:
	var st: int = SkillManager.stars(skill_id)
	if st <= 0:
		return
	var ratio: float = clamp(_shield_value / _shield_max, 0.0, 1.0)

	# 小盾牌图标（在条左侧，纵向居中于条）
	var icon_y: float = _bar_y0 - (ICON_SIZE - BAR_H) * 0.5
	draw_texture_rect(SHIELD_TEX, Rect2(_icon_x, icon_y, ICON_SIZE, ICON_SIZE), false, Color(1.0, 1.0, 1.0, 0.95))

	# 细条背景
	draw_rect(Rect2(_bar_x0 - 1.0, _bar_y0 - 1.0, _bar_w + 2.0, BAR_H + 2.0), Color(0.0, 0.0, 0.0, 0.7), true)
	draw_rect(Rect2(_bar_x0, _bar_y0, _bar_w, BAR_H), Color(0.22, 0.24, 0.28), true)
	# 护盾填充（浅蓝）
	draw_rect(Rect2(_bar_x0, _bar_y0, _bar_w * ratio, BAR_H), Color(0.55, 0.85, 1.0), true)
