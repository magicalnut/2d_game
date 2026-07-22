extends Node2D

## 一次性特效节点（由 FXManager 对象池复用）。
## 挂在世界层下，process_mode=ALWAYS，因此即使游戏暂停也能完成动画。

var _type: String = ""
var _tween: Tween = null

func play(type: String, tex: Texture2D, base_scale: float, duration: float) -> void:
	_type = type
	var sp: Sprite2D = get_node("Sprite")
	sp.texture = tex
	sp.rotation = 0.0

	# 重置状态，避免复用时残留上一帧的变形/透明
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2(base_scale, base_scale)
	rotation = 0.0

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()

	match type:
		"hit":
			# 受击火花：随机旋转、快速爆开一下立即淡出，形成清脆反馈
			sp.rotation = randf_range(-PI, PI)
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2(base_scale * 1.35, base_scale * 1.35), duration * 0.45)
			_tween.chain().tween_property(self, "modulate:a", 0.0, duration * 0.55)
		"poof":
			# 死亡烟尘：固定不旋转（对齐 x 轴），缓慢上浮并微微扩散，像一团被击散的尘土
			sp.rotation = 0.0
			_tween.set_parallel(true)
			_tween.tween_property(self, "scale", Vector2(base_scale * 1.35, base_scale * 1.35), duration)
			_tween.tween_property(self, "position:y", position.y - 16.0, duration)
			_tween.chain().tween_property(self, "modulate:a", 0.0, duration * 0.45)
		"levelup":
			# 升级闪光：从较小快速扩张到较大，然后淡出，强化成长爽感
			_tween.tween_property(self, "scale", Vector2(base_scale * 1.25, base_scale * 1.25), duration * 0.6)
			_tween.chain().tween_property(self, "modulate:a", 0.0, duration * 0.4)

	_tween.finished.connect(_on_finished, CONNECT_ONE_SHOT)

func _on_finished() -> void:
	FXManager.recycle(self, _type)
