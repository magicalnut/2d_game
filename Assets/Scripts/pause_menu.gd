extends CanvasLayer

## 暂停菜单（CanvasLayer，挂于 Main 下，process_mode=ALWAYS 以便暂停时仍可响应 ESC）。
## ESC 开关：与升级卡（UpgradeUI）互斥，与死亡结算屏（GameOverUI）互斥。

const MENU_SCENE := "res://Scenes/menu.tscn"

var _overlay: Control
var _open: bool = false
var _slot_overlay: Control = null
var _slot_mode: String = ""  # "save" or "load"

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
	vbox.add_theme_constant_override("separation", 22)

	var title := Label.new()
	vbox.add_child(title)
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 5)

	vbox.add_child(_spacer(14.0))
	vbox.add_child(_make_button("继续游戏", _on_resume, Color(0.18, 0.30, 0.22)))
	vbox.add_child(_make_button("保存游戏", _on_save_click, Color(0.18, 0.28, 0.35)))
	vbox.add_child(_make_button("读取存档", _on_load_click, Color(0.25, 0.20, 0.30)))
	vbox.add_child(_make_button("重新开始", _on_restart, Color(0.20, 0.18, 0.30)))
	vbox.add_child(_make_button("返回主菜单", _on_menu, Color(0.20, 0.18, 0.30)))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _upgrade_open() or _gameover_open():
		return
	if _slot_overlay != null and _slot_overlay.visible:
		_close_slot_ui()
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

func _on_menu() -> void:
	_open = false
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file.call_deferred(MENU_SCENE)

func _on_save_click() -> void:
	_slot_mode = "save"
	_open_slot_ui()

func _on_load_click() -> void:
	_slot_mode = "load"
	_open_slot_ui()

func _open_slot_ui() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
	_slot_overlay = Control.new()
	_slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_slot_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_overlay.add_child(dim)

	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.14, 0.18, 0.95)
	panel.custom_minimum_size = Vector2(420, 360)
	panel.size = Vector2(420, 360)
	_slot_overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.add_theme_constant_override("margin_left", 25)
	vbox.add_theme_constant_override("margin_right", 25)
	vbox.add_theme_constant_override("margin_top", 20)

	var title := Label.new()
	title.text = "存档" if _slot_mode == "save" else "读档"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	vbox.add_child(_spacer(6))

	for i in range(3):
		var meta: Dictionary = SaveManager.get_slot_meta(i) if SaveManager != null else {}
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_FILL
		if meta.is_empty():
			btn.text = "存档 %d  （空）" % (i + 1)
		else:
			var ts: String = meta.get("timestamp", "???")
			var wi: String = meta.get("wave_info", "")
			var ch: String = meta.get("character", "???")
			var ti: String = _format_time(meta.get("time_survived", 0.0))
			btn.text = "存档 %d  %s %s  %s  %s" % [i + 1, ch, wi, ti, ts]
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.20, 0.28)
		sb.border_color = Color(0.35, 0.40, 0.50)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate()
		sbh.bg_color = Color(0.25, 0.28, 0.38)
		btn.add_theme_stylebox_override("hover", sbh)
		btn.pressed.connect(_on_slot_selected.bind(i))
		vbox.add_child(btn)

	vbox.add_child(_spacer(6))

	var cancel := Button.new()
	cancel.text = "返回"
	cancel.custom_minimum_size = Vector2(160, 44)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.add_theme_font_size_override("font_size", 22)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.22, 0.25, 0.32)
	sb2.border_color = Color(0.5, 0.55, 0.65)
	sb2.set_border_width_all(2)
	sb2.set_corner_radius_all(12)
	cancel.add_theme_stylebox_override("normal", sb2)
	cancel.pressed.connect(_close_slot_ui)
	vbox.add_child(cancel)

func _close_slot_ui() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
		_slot_overlay = null

func _on_slot_selected(index: int) -> void:
	if _slot_mode == "save":
		_do_save(index)
	else:
		_do_load(index)
	_close_slot_ui()

func _do_save(index: int) -> void:
	var state := _gather_save_state()
	SaveManager.save_in_game_slot(index, state)

func _do_load(index: int) -> void:
	SaveManager.load_in_game_slot(index)
	_on_resume()
	if RunStats != null:
		RunStats.skip_reset = true
	if SkillManager != null:
		SkillManager.skip_reset = true
	if WaveManager != null:
		WaveManager.skip_reset = true
	var tree := get_tree()
	if tree != null:
		tree.reload_current_scene()

func _gather_save_state() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_state: Dictionary = {}
	if player != null and player.has_method("export_state"):
		player_state = player.export_state()
	var wave_state: Dictionary = {}
	if WaveManager != null and WaveManager.has_method("export_state"):
		wave_state = WaveManager.export_state()
	var run_stats_data: Dictionary = {}
	if RunStats != null:
		run_stats_data = {
			"time_survived": RunStats.time_survived,
			"kills": RunStats.kills,
			"last_wave_reached": RunStats.last_wave_reached,
			"chosen_character": RunStats.chosen_character,
			"deploy_difficulty": RunStats.deploy_difficulty,
			"game_mode": RunStats.game_mode,
			"selected_level_id": RunStats.selected_level_id,
			"equipped_gear": RunStats.equipped_gear.duplicate(true),
		}
	var skills_data: Dictionary = {}
	if SkillManager != null:
		skills_data = SkillManager.owned.duplicate(true)
	return {
		"player_state": player_state,
		"wave_state": wave_state,
		"run_stats": run_stats_data,
		"skills": skills_data,
	}

func _format_time(t: float) -> String:
	var total: int = int(t)
	var m: int = total / 60
	var s: int = total % 60
	return "%02d:%02d" % [m, s]

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

func _make_button(text: String, cb: Callable, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240.0, 56.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.border_color = Color(0.9, 0.9, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = accent * 1.3
	b.add_theme_stylebox_override("hover", sbh)
	b.pressed.connect(cb)
	return b
