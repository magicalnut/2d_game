extends Node

## FXManager（AutoLoad）
## 负责统一生成一次性特效：受击火花、死亡烟尘、升级闪光。
## 维护对象池减少频繁 instantiate/free 的 GC 压力；所有特效节点 process_mode=ALWAYS，
## 确保暂停菜单弹出时已有的特效仍能完整播完。

const HIT_TEX := preload("res://Assets/Sprites/Effects/hit.png")
const POOF_TEX := preload("res://Assets/Sprites/Effects/poof.png")
const LEVELUP_TEX := preload("res://Assets/Sprites/Effects/levelup.png")

const FX_SCRIPT := preload("res://Assets/Scripts/fx_one_shot.gd")

# 视觉尺寸：384×384 原图按内容占比折算后的目标屏幕尺寸
const HIT_SCALE: float = 0.0375     # 受击火花 ≈ 原 0.15 的 1/4（≈10~13px）
const POOF_SCALE: float = 0.22      # 死亡烟尘 ≈ 60~80px
const LEVELUP_SCALE: float = 0.32   # 升级闪光 ≈ 100~130px

# 动画时长：短促反馈，避免长时间遮挡角色
const HIT_DUR: float = 0.14
const POOF_DUR: float = 0.45
const LEVELUP_DUR: float = 0.75

const POOL_LIMIT: int = 24   # 每种特效最多缓存 24 个节点

# —— 受击数字 ——
const DMG_SCRIPT := preload("res://Assets/Scripts/damage_number.gd")

var _pools: Dictionary = {}
var _dmg_pool: Array = []

func _ready() -> void:
	_pools = {"hit": [], "poof": [], "levelup": []}

# 受击火花：通常挂在敌人身上，boss 可放大
func spawn_hit_spark(pos: Vector2, scale_mult: float = 1.0) -> void:
	_spawn("hit", pos, HIT_TEX, HIT_SCALE * scale_mult, HIT_DUR)

# 死亡烟尘：敌人死亡时爆发，boss 放大
func spawn_death_poof(pos: Vector2, scale_mult: float = 1.0) -> void:
	_spawn("poof", pos, POOF_TEX, POOF_SCALE * scale_mult, POOF_DUR)

# 升级闪光：玩家升级时以玩家为中心向外扩张
func spawn_levelup_flash(pos: Vector2) -> void:
	_spawn("levelup", pos, LEVELUP_TEX, LEVELUP_SCALE, LEVELUP_DUR)

func _spawn(type: String, pos: Vector2, tex: Texture2D, base_scale: float, duration: float) -> void:
	var world := get_tree().current_scene
	if world == null:
		return

	var node: Node2D = null
	if not _pools[type].is_empty():
		node = _pools[type].pop_back()
		# 重置 pooling 时可能残留的 transform
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		node.scale = Vector2(1.0, 1.0)
		node.rotation = 0.0
		node.position = Vector2.ZERO
	else:
		node = Node2D.new()
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.top_level = true
		node.z_index = 16
		node.set_script(FX_SCRIPT)
		var sp := Sprite2D.new()
		sp.name = "Sprite"
		node.add_child(sp)

	world.add_child(node)
	node.global_position = pos
	node.play(type, tex, base_scale, duration)

# 动画结束后回收进池或销毁（超过池上限直接释放）
func recycle(node: Node2D, type: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if _pools[type].size() < POOL_LIMIT:
		_pools[type].append(node)
	else:
		node.queue_free()

# ===================== 受击数字 =====================
func spawn_damage_number(pos: Vector2, amount: float) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var dn: DamageNumber
	if not _dmg_pool.is_empty():
		dn = _dmg_pool.pop_back()
		if dn.get_parent() == null:
			world.add_child(dn)
		dn.reset_state()
	else:
		dn = DMG_SCRIPT.new()
		dn.process_mode = Node.PROCESS_MODE_ALWAYS
		dn.top_level = true
		dn.z_index = 20
		world.add_child(dn)
	dn.popup(amount, pos)

# 数字动画结束后回收进池（超过池上限直接释放）
func recycle_damage_number(dn: DamageNumber) -> void:
	if dn == null or not is_instance_valid(dn):
		return
	var parent := dn.get_parent()
	if parent != null:
		parent.remove_child(dn)
	if _dmg_pool.size() < POOL_LIMIT:
		_dmg_pool.append(dn)
	else:
		dn.queue_free()
