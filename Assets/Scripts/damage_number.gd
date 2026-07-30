extends Node2D
class_name DamageNumber

## 受击数字：敌对单位受击时在其头顶显示一次，原地出现后淡出隐去。
## 数字用 0-9 的精灵图拼接（支持两位数）：文件名 num_0.png ~ num_9.png，
## 放在 Assets/Sprites/UI/DamageNumbers/ 下。
## 颜色为美术图自带（单一固定色），不再按伤害变色。
## 尺寸随伤害微微放大（GROW_K / GROW_MAX）；整体基准尺寸由 DMG_SCALE 控制。

const DMG_SCALE: float = 0.10       # 整体基准尺寸系数（旋钮：想整体放大就调大，想缩小就调小）
const GROW_K: float = 0.02          # 每点伤害放大系数（"微微"放大）
const GROW_MAX: float = 1.5         # 相对基准的最大放大幅度
const LIFE: float = 0.9             # 总存活时长（秒）
const POP_TIME: float = 0.10        # 出现时的弹入时长
const POP_START_SCALE: float = 0.6  # 弹入起点的初始缩放（略小于目标值，仅影响弹入手感，不影响最终稳态大小）
const FADE_TIME: float = 0.32       # 隐去淡出时长
const DIGIT_GAP: float = 2.0        # 相邻数字之间的像素间隙
const NUM_PREFIX: String = "res://Assets/Sprites/UI/DamageNumbers/num_"
const NUM_TINT := Color(1.0, 1.0, 1.0, 1.0)   # 单一固定颜色；若数字图是白色想染色，改这里（如 Color(1,0.4,0.4)）

var _tween: Tween = null

func _ready() -> void:
	top_level = true
	z_index = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func reset_state() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	for c in get_children():
		c.free()
	modulate = NUM_TINT
	scale = Vector2.ONE
	visible = false

# origin: 受击单位头顶世界坐标，数字在此原地出现并淡出（不再上浮）
func popup(amount: float, origin: Vector2) -> void:
	for c in get_children():
		c.free()
	var text := str(int(round(amount)))
	_build_digits(text)
	global_position = origin
	visible = true
	modulate = Color(NUM_TINT.r, NUM_TINT.g, NUM_TINT.b, 1.0)

	# 伤害越大，数字微微放大
	var grow: float = clamp(1.0 + amount * GROW_K, 1.0, GROW_MAX)
	var s: float = DMG_SCALE * grow
	scale = Vector2(s, s) * POP_START_SCALE   # 弹入起点（略小），随后弹回 s

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# 原地弹入（squash & stretch），不移动位置
	_tween.tween_property(self, "scale", Vector2(s, s), POP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 停留后原地淡出隐去（无位移）
	_tween.tween_interval(max(LIFE - POP_TIME - FADE_TIME, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(func(): FXManager.recycle_damage_number(self))

# 把数字字符串（如 "27"）拆成 0-9 精灵，水平居中、垂直居中排成一行
func _build_digits(text: String) -> void:
	var rects: Array = []
	var total_w: float = 0.0
	var max_h: float = 0.0
	for ch in text:
		var tr := TextureRect.new()
		tr.texture = _load_digit(ch)
		if tr.texture != null:
			var sz := tr.texture.get_size()
			tr.size = sz
			total_w += sz.x
			max_h = max(max_h, sz.y)
		add_child(tr)
		rects.append(tr)
	total_w += DIGIT_GAP * max(0, text.length() - 1)
	var x: float = -total_w / 2.0
	for tr in rects:
		tr.position = Vector2(x, -max_h / 2.0)
		if tr.texture != null:
			x += tr.texture.get_size().x + DIGIT_GAP

func _load_digit(ch: String) -> Texture2D:
	var p := NUM_PREFIX + ch + ".png"
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	push_warning("受击数字素材缺失: " + p)
	return null
