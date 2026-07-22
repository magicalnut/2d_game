extends CanvasLayer

## 特殊技能选择界面：仅通过此界面获得 / 升级特殊技能（不进普通升级卡池）。
## 监听 WaveManager.special_choice_ready（无尽模式每累计清 5 波触发一次），
## 暂停游戏，弹出特殊技能卡（新获得 / 升级）。点击或按 1/2/3 选择。

const SPECIALS := ["special_shield", "special_hourglass", "special_thunder"]
const CARD_W: float = 374.0
const CARD_H: float = 448.0
const ICON_SIZE: float = 128.0
const GEAR_CHANCE: float = 0.30   # 30% 概率出现一个装备选项替代技能

var _overlay: ColorRect
var _title: Label
var _hint: Label
var _cards: Array[Button] = []
var _sb_normal: StyleBox
var _sb_hover: StyleBox
var _sb_pressed: StyleBox

# 当前弹窗中的选项数据（每次弹出时重新生成）
var _current_choices: Array[Dictionary] = []

func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	_build_ui()
	_overlay.visible = false
	if WaveManager != null and WaveManager.has_signal("special_choice_ready"):
		WaveManager.special_choice_ready.connect(_on_special_choice)

func _build_styles() -> void:
	_sb_normal = StyleBoxTexture.new()
	_sb_normal.texture = preload("res://Assets/Sprites/UI/card_bg.png")
	_sb_normal.texture_margin_left = 24
	_sb_normal.texture_margin_top = 24
	_sb_normal.texture_margin_right = 24
	_sb_normal.texture_margin_bottom = 24
	_sb_hover = _sb_normal
	_sb_pressed = _sb_normal

func _build_ui() -> void:
	_overlay = ColorRect.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.03, 0.05, 0.80)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	_overlay.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)

	_title = Label.new()
	vbox.add_child(_title)
	_title.text = "特殊技能！选择一项"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 4)

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for i in range(3):
		var card := Button.new()
		hbox.add_child(card)
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.add_theme_stylebox_override("normal", _sb_normal)
		card.add_theme_stylebox_override("hover", _sb_hover)
		card.add_theme_stylebox_override("pressed", _sb_pressed)
		card.add_theme_font_size_override("font_size", 22)
		card.text = ""
		card.visible = false
		card.pressed.connect(_on_card_pressed.bind(i))
		var content := MarginContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("margin_left", 28)
		content.add_theme_constant_override("margin_right", 28)
		content.add_theme_constant_override("margin_top", 28)
		content.add_theme_constant_override("margin_bottom", 28)
		card.add_child(content)
		card.set_meta("content", content)
		_cards.append(card)

	_hint = Label.new()
	vbox.add_child(_hint)
	_hint.text = "点击卡片，或按 1 / 2 / 3 键选择"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))

func _on_special_choice() -> void:
	if _overlay.visible:
		return
	_show_cards()

func is_open() -> bool:
	return _overlay.visible

# 可选项：未拥有=新获得；已拥有但未满星=升级；满星=不提供
# 混入装备选项（30%概率替换一个技能位）
func _available_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 先收集技能选项
	for id in SPECIALS:
		if not SkillManager.owned.has(id):
			out.append({"type": "skill", "id": id, "is_new": true, "stars": 0})
		else:
			var cur: int = int(SkillManager.owned[id])
			var mx: int = int(SkillManager.SKILLS[id]["max_stars"])
			if cur < mx:
				out.append({"type": "skill", "id": id, "is_new": false, "stars": cur})
	
	# 混入装备选项（30%概率，至少保留1个技能选项）
	if out.size() > 0 and randf() < GEAR_CHANCE and EquipmentManager != null:
		# 随机一个槽位类型
		var slot_pool: Array[String] = EquipmentManager.get_unlocked_slots()
		if slot_pool.is_empty():
			# 1级默认符文+护符已解锁，但保险起见
			slot_pool = ["rune", "amulet"]
		var slot_id: String = slot_pool[randi() % slot_pool.size()]
		# 根据波次决定稀有度
		var rarity: int = _determine_gear_rarity()
		var gear_inst: Dictionary = EquipmentManager.random_gear_for_slot(slot_id, rarity)
		if not gear_inst.is_empty():
			# 替换一个随机技能选项
			var replace_idx: int = randi() % out.size()
			out[replace_idx] = {
				"type": "gear",
				"gear_inst": gear_inst,
				"slot_id": slot_id
			}
	
	# 打乱顺序
	out.shuffle()
	return out

func _determine_gear_rarity() -> int:
	## 根据当前波次决定装备稀有度
	var wave: int = 1
	if RunStats != null:
		wave = RunStats.last_wave_reached
	if wave <= 10:
		return 1 if randf() < 0.8 else 2   # 80%白, 20%绿
	elif wave <= 20:
		return 2 if randf() < 0.7 else 1   # 70%绿, 30%白
	elif wave <= 30:
		var r: float = randf()
		if r < 0.6: return 2
		elif r < 0.9: return 3
		else: return 1
	else:
		var r: float = randf()
		if r < 0.5: return 3
		elif r < 0.8: return 2
		elif r < 0.95: return 4
		else: return 5

func _show_cards() -> void:
	_current_choices = _available_choices()
	if _current_choices.is_empty():
		return   # 全部满级 / 无可选：直接继续，不暂停
	for i in range(_cards.size()):
		var card: Button = _cards[i]
		var content = card.get_meta("content")
		for c in content.get_children():
			c.queue_free()
		if i >= _current_choices.size():
			card.visible = false
			continue
		var ch: Dictionary = _current_choices[i]
		if ch["type"] == "skill":
			_setup_skill_card(card, content, ch)
		else:
			_setup_gear_card(card, content, ch)
	_overlay.visible = true
	get_tree().paused = true

func _setup_skill_card(card: Button, content: MarginContainer, ch: Dictionary) -> void:
	var id: String = ch["id"]
	var def: Dictionary = SkillManager.SKILLS[id]

	var col := VBoxContainer.new()
	content.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)

	var top_sp := Control.new()
	top_sp.custom_minimum_size = Vector2(0.0, 48.0)
	col.add_child(top_sp)

	var tex_rect := TextureRect.new()
	col.add_child(tex_rect)
	tex_rect.texture = def["icon"]
	tex_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var mid_sp := Control.new()
	mid_sp.custom_minimum_size = Vector2(0.0, 28.0)
	col.add_child(mid_sp)

	var name_lbl := Label.new()
	col.add_child(name_lbl)
	name_lbl.text = def["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 2)

	if not ch["is_new"]:
		var star_lbl := Label.new()
		col.add_child(star_lbl)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		star_lbl.add_theme_font_size_override("font_size", 24)
		var cur: int = int(ch["stars"])
		var mx: int = int(def["max_stars"])
		star_lbl.text = "★".repeat(cur) + "☆".repeat(mx - cur)
		star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

	var bot_sp := Control.new()
	bot_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(bot_sp)

	card.set_meta("skill_id", id)
	card.visible = true

func _setup_gear_card(card: Button, content: MarginContainer, ch: Dictionary) -> void:
	var gear_inst: Dictionary = ch["gear_inst"]
	var def_id: String = gear_inst.get("def_id", "")
	var def: Dictionary = EquipmentManager.get_gear_def(def_id)
	var rarity: int = gear_inst.get("rarity", 1)
	var col: Color = EquipmentManager.get_rarity_color(rarity)
	var slot_id: String = ch["slot_id"]

	var col_vbox := VBoxContainer.new()
	content.add_child(col_vbox)
	col_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_theme_constant_override("separation", 14)

	# 顶部间距
	var top_sp := Control.new()
	top_sp.custom_minimum_size = Vector2(0.0, 40.0)
	col_vbox.add_child(top_sp)

	# 槽位标签
	var slot_lbl := Label.new()
	col_vbox.add_child(slot_lbl)
	slot_lbl.text = EquipmentManager.SLOT_NAMES.get(slot_id, slot_id)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_size_override("font_size", 18)
	slot_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))

	# 装备名称（带稀有度色）
	var name_lbl := Label.new()
	col_vbox.add_child(name_lbl)
	name_lbl.text = def.get("name", def_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", col)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 2)

	# 星级
	var star_lbl := Label.new()
	col_vbox.add_child(star_lbl)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 20)
	var rstr: String = ""
	for _i in range(rarity):
		rstr += "★"
	star_lbl.text = rstr
	star_lbl.add_theme_color_override("font_color", col)

	# 属性摘要
	var stats: Dictionary = EquipmentManager.get_gear_stats(gear_inst)
	var stats_str: String = ""
	for key in stats.keys():
		var val: float = float(stats[key])
		var label_name: String = _stat_label(key)
		if key == "projectile_speed" or key == "def_bonus" or key == "exp_bonus":
			stats_str += "%s +%.0f%%\n" % [label_name, val * 100]
		elif key == "pickup_radius":
			stats_str += "%s +%.0f\n" % [label_name, val]
		else:
			stats_str += "%s +%.0f\n" % [label_name, val]
	if stats_str != "":
		var stats_lbl := Label.new()
		col_vbox.add_child(stats_lbl)
		stats_lbl.text = stats_str.strip_edges()
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.add_theme_font_size_override("font_size", 16)
		stats_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))

	# 风味文本
	var flavor: String = def.get("flavor", "")
	if flavor != "":
		var flavor_lbl := Label.new()
		col_vbox.add_child(flavor_lbl)
		flavor_lbl.text = "\"%s\"" % flavor
		flavor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor_lbl.add_theme_font_size_override("font_size", 13)
		flavor_lbl.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))

	# 底部弹性占位
	var bot_sp := Control.new()
	bot_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_child(bot_sp)

	card.set_meta("gear_inst", gear_inst)
	card.visible = true

func _stat_label(key: String) -> String:
	match key:
		"atk_bonus": return "攻击力"
		"max_hp_bonus": return "生命值"
		"projectile_speed": return "弹速"
		"def_bonus": return "减伤"
		"pickup_radius": return "拾取"
		"exp_bonus": return "经验"
		_: return key

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _cards.size():
		return
	if not _cards[idx].visible:
		return
	if idx >= _current_choices.size():
		return
	var ch: Dictionary = _current_choices[idx]
	if ch["type"] == "skill":
		var id: String = ch["id"]
		SkillManager.grant(id)
	else:
		# 装备：检查是否能装备，能则直接装备，否则拆解为钻石
		var gear_inst: Dictionary = ch["gear_inst"]
		var check: Dictionary = EquipmentManager.can_equip(gear_inst, RunStats.equipped_gear)
		if check["ok"]:
			var slot_id: String = EquipmentManager.get_gear_slot(gear_inst.get("def_id", ""))
			RunStats.equipped_gear[slot_id] = gear_inst
			# 通知玩家刷新属性（如果玩家已存在）
			var p = get_tree().get_first_node_in_group("player")
			if p != null and p.has_method("_apply_equipment_stats"):
				p._apply_equipment_stats()
		else:
			# 无法装备：拆解为钻石（安慰奖）
			var scrap: int = max(5, gear_inst.get("rarity", 1) * 3)
			EquipmentManager.add_diamonds(scrap)
	_overlay.visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _on_card_pressed(0)
			KEY_2: _on_card_pressed(1)
			KEY_3: _on_card_pressed(2)