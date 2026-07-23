extends CanvasLayer

## 死亡结算屏（CanvasLayer，挂于 Main 下）。
## 玩家死亡时由 main.gd 调用 show_game_over()：暂停游戏并展示本局统计，
## 提供「重新开始（重载当前场景）」与「返回主菜单」。

const MENU_SCENE := "res://Scenes/menu.tscn"

var _overlay: Control
var _stats_label: Label
var _title: Label

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_overlay.visible = false

func _build() -> void:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false

	# 背景图（gameover_bg.png，384x216 等比铺满）
	var bg := TextureRect.new()
	_overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = preload("res://Assets/Sprites/UI/gameover_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	_overlay.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)

	_title = Label.new()
	vbox.add_child(_title)
	_title.text = "你 倒 下 了"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.42))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 5)

	_stats_label = Label.new()
	vbox.add_child(_stats_label)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 24)
	_stats_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_stats_label.add_theme_constant_override("outline_size", 3)

	vbox.add_child(_spacer(16.0))

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)

	hbox.add_child(_make_button("重新开始", _on_restart, Color(0.20, 0.45, 0.30)))
	hbox.add_child(_make_button("返回主菜单", _on_menu, Color(0.20, 0.18, 0.30)))

func show_game_over() -> void:
	var p = get_tree().get_first_node_in_group("player")
	var lvl: int = 1
	if p != null and p.has_method("get_level"):
		lvl = p.get_level()
	var tstr: String = "00:00"
	var kills: int = 0
	var wave: int = 0
	if RunStats != null:
		tstr = RunStats.get_time_string()
		kills = RunStats.kills
		wave = RunStats.last_wave_reached

	# 计算并发放钻石
	var diamonds_earned: int = 0
	if EquipmentManager != null:
		diamonds_earned = EquipmentManager.calculate_run_diamonds(wave, kills)
		EquipmentManager.add_diamonds(diamonds_earned)

	# 局终装备掉落：≥3波掉一件白色装备到仓库
	if EquipmentManager != null and wave >= 3:
		var drop_slot: String = EquipmentManager.SLOT_ORDER[randi() % EquipmentManager.SLOT_ORDER.size()]
		var drop: Dictionary = EquipmentManager.random_gear_for_slot(drop_slot, 1)
		if not drop.is_empty():
			EquipmentManager.add_to_inventory(drop)

	# 保存本局装备到角色专属配置
	if RunStats != null:
		RunStats.character_gear[RunStats.chosen_character] = RunStats.equipped_gear.duplicate(true)

	_stats_label.text = "存活时间  %s\n到达等级  Lv.%d\n击杀敌人  %d\n到达波次  %d\n获得钻石  +%d" % [tstr, lvl, kills, wave, diamonds_earned]
	_overlay.visible = true
	get_tree().paused = true

func show_level_complete(level_data: LevelData) -> void:
	_title.text = "关卡完成"
	_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))

	var completed_before: bool = false
	if RunStats != null:
		completed_before = RunStats.is_level_completed(level_data.level_id)

	var reward_text: String = ""
	var diamonds: int = level_data.get_diamond_reward()

	if EquipmentManager != null and diamonds > 0:
		EquipmentManager.add_diamonds(diamonds)
		reward_text += "获得钻石  +%d\n" % diamonds

	var gear_id: String = level_data.get_first_clear_gear_id()
	if not completed_before and not gear_id.is_empty() and EquipmentManager != null:
		var gear_inst: Dictionary = EquipmentManager.create_instance(gear_id, 1, 1)
		if not gear_inst.is_empty():
			var slot: String = EquipmentManager.get_gear_slot(gear_id)
			if RunStats != null:
				RunStats.equipped_gear[slot] = gear_inst
				RunStats.character_gear[RunStats.chosen_character] = RunStats.equipped_gear.duplicate(true)
			reward_text += "首通奖励  %s\n" % EquipmentManager.get_gear_name(gear_id)

	if RunStats != null:
		RunStats.complete_level(level_data.level_id)

	var tstr: String = "00:00"
	var kills: int = 0
	if RunStats != null:
		tstr = RunStats.get_time_string()
		kills = RunStats.kills

	_stats_label.text = "关卡  %s\n存活时间  %s\n击杀敌人  %d\n%s" % [level_data.display_name, tstr, kills, reward_text]
	_overlay.visible = true
	get_tree().paused = true


func show_level_failed(reason: String) -> void:
	_title.text = "关卡失败"
	_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.42))

	var reason_text: String = ""
	match reason:
		"time_limit": reason_text = "超时"
		"player_died": reason_text = "阵亡"
		_: reason_text = "目标未完成"

	var tstr: String = "00:00"
	var kills: int = 0
	if RunStats != null:
		tstr = RunStats.get_time_string()
		kills = RunStats.kills

	_stats_label.text = "关卡失败  %s\n存活时间  %s\n击杀敌人  %d" % [reason_text, tstr, kills]
	_overlay.visible = true
	get_tree().paused = true


func _on_restart() -> void:
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
		tree.reload_current_scene()

func _on_menu() -> void:
	_overlay.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file.call_deferred(MENU_SCENE)

func is_open() -> bool:
	return _overlay.visible

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c

func _make_button(text: String, cb: Callable, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240.0, 64.0)
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
