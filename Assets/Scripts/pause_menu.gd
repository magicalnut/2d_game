extends CanvasLayer

## 暂停菜单（CanvasLayer，挂于 Main 下，process_mode=ALWAYS 以便暂停时仍可响应 ESC）。
## ESC 开关：与升级卡（UpgradeUI）互斥，与死亡结算屏（GameOverUI）互斥。

const SETUP_SCENE := "res://Scenes/character_setup.tscn"   # 战备（选择装备）页
const CARD_BACK_TEX := "res://Assets/Sprites/UI/info_panel.png"   # 角色卡面背景（暂停页按钮复用）

var _overlay: Control
var _open: bool = false

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_overlay.visible = false

func _build() -> void:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false

	# 背景图（pause_bg.png，384x216 等比铺满）
	var bg := TextureRect.new()
	_overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = preload("res://Assets/Sprites/UI/pause_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

	# 暗化叠层，保证文字清晰
	var dim := ColorRect.new()
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	_overlay.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	# 整体把面板往上平移（负间隔会被 Godot 夹成 0、居中又会吸收一半位移，所以用整体平移才看得出来）
	vbox.offset_top = -14.0
	vbox.offset_bottom = -14.0

	var _title_h := 60.0
	var _title_tex_path := "res://Assets/Sprites/UI/TextBits/pause_title.png"
	var title: Control = null
	if ResourceLoader.exists(_title_tex_path):
		var _ttx := load(_title_tex_path) as Texture2D
		_title_h = _ttx.get_size().y
		var ttr := TextureRect.new()
		ttr.texture = _ttx
		ttr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ttr.custom_minimum_size = _ttx.get_size()
		ttr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ttr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(ttr)
		title = ttr
	else:
		var tl := Label.new()
		vbox.add_child(tl)
		title = tl
		tl.text = "已暂停"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 52)
		title.add_theme_color_override("font_color", UIColors.GOLD)
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		title.add_theme_constant_override("outline_size", 5)

	var _btn_max_h: float = clamp(_title_h * 0.6, 40.0, 76.0)
	var _btn_max_w := 300.0
	vbox.add_child(_spacer(0.0))
	vbox.add_child(_make_button("继续游戏", _on_resume, UIColors.WHITE, "", _btn_max_w, _btn_max_h))
	vbox.add_child(_make_button("重新开始", _on_restart, UIColors.WHITE, "", _btn_max_w, _btn_max_h))
	vbox.add_child(_make_button("返回", _on_return, UIColors.WHITE, "", _btn_max_w, _btn_max_h))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _upgrade_open() or _gameover_open():
		return
	toggle()

func toggle() -> void:
	if _open:
		_on_resume()
	else:
		_open = true
		_overlay.visible = true
		var tree := get_tree()
		if tree != null:
			tree.paused = true

func _on_resume() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false

func _on_restart() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
		tree.reload_current_scene()

func _on_return() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	# 放弃本局，回到战备（选择装备）页：置 back_to_loadout 跳过角色转盘、直达整备视图。
	# active_slot 在进局时已绑定为有效槽位；skip_reset=false 让下次进 Main 自动重置本局状态。
	if SaveManager != null and SaveManager.active_slot >= 0:
		SaveManager.back_to_loadout = true
	if RunStats != null:
		RunStats.skip_reset = false
	if SkillManager != null:
		SkillManager.skip_reset = false
	if WaveManager != null:
		WaveManager.skip_reset = false
		tree.change_scene_to_file.call_deferred(SETUP_SCENE)

# 注：局内「保存游戏」已移除——所有存档改为自动保存（阵亡/关卡结束由 game_over 固化 meta，
# 养成数据由 EquipmentManager._save 实时写入当前槽）。不再有中途快照档，读档统一进战备页。

func is_open() -> bool:
	return _open

func _upgrade_open() -> bool:
	var ui = get_tree().current_scene.get_node_or_null("UpgradeUI")
	if ui != null and ui.has_method("is_open"):
		return ui.is_open()
	return false

func _gameover_open() -> bool:
	var go = get_tree().current_scene.get_node_or_null("GameOverUI")
	if go != null and go.has_method("is_open"):
		return go.is_open()
	return false

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

func _make_button(text: String, cb: Callable, accent: Color, tex_path := "", max_w := 300.0, max_h := 64.0) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if tex_path != "" and ResourceLoader.exists(tex_path):
		# 素材已是完整按钮外观：去掉原色块框，缩放到上限内显示（保持比「已暂停」小）
		var tex := load(tex_path) as Texture2D
		var tsz := tex.get_size()
		var _scale: float = min(max_w / tsz.x, max_h / tsz.y, 1.0)
		b.icon = tex
		b.text = ""
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = tsz * _scale
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.mouse_entered.connect(func(): b.modulate = Color(1.25, 1.25, 1.25))
		b.mouse_exited.connect(func(): b.modulate = Color(1, 1, 1))
	else:
		b.text = text
		b.custom_minimum_size = Vector2(240.0, 56.0)
		b.add_theme_font_size_override("font_size", 26)
		var sb := StyleBoxTexture.new()
		sb.texture = load(CARD_BACK_TEX)
		sb.texture_margin_left = 28.0
		sb.texture_margin_top = 28.0
		sb.texture_margin_right = 28.0
		sb.texture_margin_bottom = 28.0
		b.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate()
		sbh.modulate_color = Color(1.2, 1.2, 1.25)
		b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 3)
	b.mouse_entered.connect(func(): b.modulate = Color(1.2, 1.2, 1.2))
	b.mouse_exited.connect(func(): b.modulate = Color(1, 1, 1))
	b.pressed.connect(cb)
	return b
