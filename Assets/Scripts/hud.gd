extends CanvasLayer

## HUD：屏幕底部经验条 + 等级；顶部信息栏（血条 / 波次 / 计时 / 击杀 / BOSS 血条）。
## 实时读取玩家与 RunStats / WaveManager。

var _player: Node2D = null

# 左下角状态面板：血量条 / 经验条 横向并排（左下半透明圆角底板），标题在上、数值居中于条上
var _hp_bar
var _hp_name: Label
var _hp_caption: Label
var _hp_tick: ColorRect
var _hp_tick_bg: ColorRect
var _exp_bar
var _exp_name: Label
var _exp_caption: Label
var _exp_tick: ColorRect
var _exp_tick_bg: ColorRect

# 顶部元素
var _wave_label: Label
var _timer_label: Label
var _kill_label: Label          # 右上：击杀数（数字）
var _diamond_label: Label       # 右上：钻石数（数字）
var _boss_bar: ProgressBar
var _boss_label: Label
var _gear_slots: Array[Control] = []   # 底部6装备槽微型图标
var _gear_slot_root: Control = null
var _gear_slot_size: float = 28.0
var _gear_slot_gap: float = 6.0

var _crystal_panel: PanelContainer = null
var _crystal_hp_label: Label = null
var _crystal_star_label: Label = null
const _GEAR_ICON_DIR := "res://Assets/Sprites/UI/Gear/"      # 单件装备图标（按 def_id 命名，如 rune_of_fire.png）
const _SLOT_ICON_DIR := "res://Assets/Sprites/UI/Slots/"     # 槽位图标与 lock.png

func _ready() -> void:
	layer = 5
	_build_ui()
	_refresh_player()

func _refresh_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _build_ui() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 装饰外框（hud_frame.png）：用 NinePatchRect 九宫拉伸，只留边框，中间不绘制，避免遮挡画面
	var frame := NinePatchRect.new()
	frame.texture = preload("res://Assets/Sprites/UI/hud_frame.png")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw_center = false
	frame.patch_margin_left = 102
	frame.patch_margin_top = 38
	frame.patch_margin_right = 200
	frame.patch_margin_bottom = 47
	root.add_child(frame)

	# ——— 顶部信息栏 ———
	# 波次（顶部居中）
	_wave_label = Label.new()
	root.add_child(_wave_label)
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_wave_label.offset_top = 8.0
	_wave_label.offset_bottom = 30.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.text = "准备中"
	_wave_label.add_theme_font_size_override("font_size", 18)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_wave_label.add_theme_constant_override("outline_size", 3)

	# 计时（顶部居中，波次下方）
	_timer_label = Label.new()
	root.add_child(_timer_label)
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_timer_label.offset_top = 32.0
	_timer_label.offset_bottom = 54.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.text = "00:00"
	_timer_label.add_theme_font_size_override("font_size", 15)
	_timer_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_timer_label.add_theme_constant_override("outline_size", 2)

	# ——— 右上角状态：两行（图标 + 右侧数字）———
	# 第 1 行：击杀数（骷髅图标 + 数字）；第 2 行：钻石数（青钻图标 + 数字）
	var stat_box := VBoxContainer.new()
	root.add_child(stat_box)
	stat_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stat_box.offset_right = -12.0
	stat_box.offset_top = 8.0
	stat_box.offset_left = -200.0
	stat_box.offset_bottom = 52.0
	stat_box.alignment = BoxContainer.ALIGNMENT_END   # 行整体靠右
	stat_box.add_theme_constant_override("separation", 6)
	stat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 击杀行
	var kill_row := HBoxContainer.new()
	kill_row.add_theme_constant_override("separation", 6)
	kill_row.alignment = BoxContainer.ALIGNMENT_END
	kill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kill_icon := TextureRect.new()
	kill_icon.texture = preload("res://Assets/Sprites/UI/Icons/icon_kill.png")
	kill_icon.custom_minimum_size = Vector2(20, 20)
	kill_icon.size = Vector2(20, 20)
	kill_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	kill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_label = Label.new()
	_kill_label.text = "0"
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_label.add_theme_font_size_override("font_size", 16)
	_kill_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4))
	_kill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_kill_label.add_theme_constant_override("outline_size", 2)
	_kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_row.add_child(kill_icon)
	kill_row.add_child(_kill_label)
	stat_box.add_child(kill_row)

	# 钻石行
	var dia_row := HBoxContainer.new()
	dia_row.add_theme_constant_override("separation", 6)
	dia_row.alignment = BoxContainer.ALIGNMENT_END
	dia_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dia_icon := TextureRect.new()
	dia_icon.texture = preload("res://Assets/Sprites/UI/Icons/icon_diamond.png")
	dia_icon.custom_minimum_size = Vector2(20, 20)
	dia_icon.size = Vector2(20, 20)
	dia_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	dia_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dia_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diamond_label = Label.new()
	_diamond_label.text = "0"
	_diamond_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_diamond_label.add_theme_font_size_override("font_size", 16)
	_diamond_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.95))
	_diamond_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_diamond_label.add_theme_constant_override("outline_size", 2)
	_diamond_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dia_row.add_child(dia_icon)
	dia_row.add_child(_diamond_label)
	stat_box.add_child(dia_row)

	# BOSS 名字（血条左侧，右对齐贴着血条；boss 出现时显示）
	_boss_label = Label.new()
	root.add_child(_boss_label)
	_boss_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_boss_label.offset_left = 20.0
	_boss_label.offset_right = 190.0   # 紧贴血条左侧（血条 offset_left = 200）
	_boss_label.offset_top = 78.0
	_boss_label.offset_bottom = 94.0
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_label.text = ""   # 构建时 boss 未出现；名字在 _process 从 boss_ref.boss_name 动态填入
	_boss_label.visible = false
	_boss_label.add_theme_font_size_override("font_size", 20)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_boss_label.add_theme_constant_override("outline_size", 3)

	_boss_bar = ProgressBar.new()
	root.add_child(_boss_bar)
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_left = 200.0
	_boss_bar.offset_right = -200.0
	_boss_bar.offset_top = 78.0
	_boss_bar.offset_bottom = 94.0
	_boss_bar.min_value = 0.0
	_boss_bar.max_value = 1.0
	_boss_bar.value = 1.0
	_boss_bar.show_percentage = false
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = Color(0.9, 0.2, 0.25)
	_boss_bar.add_theme_stylebox_override("fill", bfill)
	var bbg := StyleBoxFlat.new()
	bbg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	_boss_bar.add_theme_stylebox_override("background", bbg)

	# ——— 左上角水晶血量+星级面板（默认隐藏，水晶关卡时显示）———
	_crystal_panel = PanelContainer.new()
	root.add_child(_crystal_panel)
	_crystal_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_crystal_panel.offset_left = 12.0
	_crystal_panel.offset_top = 8.0
	_crystal_panel.offset_right = 200.0
	_crystal_panel.offset_bottom = 60.0
	_crystal_panel.visible = false
	_crystal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cp_sb := StyleBoxFlat.new()
	cp_sb.bg_color = Color(0.05, 0.08, 0.14, 0.80)
	cp_sb.border_color = Color(0.4, 0.6, 0.9, 0.6)
	cp_sb.set_border_width_all(1)
	cp_sb.set_corner_radius_all(8)
	_crystal_panel.add_theme_stylebox_override("panel", cp_sb)

	var cp_vbox := VBoxContainer.new()
	cp_vbox.add_theme_constant_override("separation", 2)
	cp_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crystal_panel.add_child(cp_vbox)

	_crystal_hp_label = Label.new()
	_crystal_hp_label.text = "水晶 100%"
	_crystal_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crystal_hp_label.add_theme_font_size_override("font_size", 14)
	_crystal_hp_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	_crystal_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_crystal_hp_label.add_theme_constant_override("outline_size", 2)
	_crystal_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp_vbox.add_child(_crystal_hp_label)

	_crystal_star_label = Label.new()
	_crystal_star_label.text = "★ ★ ★"
	_crystal_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crystal_star_label.add_theme_font_size_override("font_size", 28)
	_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_crystal_star_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_crystal_star_label.add_theme_constant_override("outline_size", 2)
	_crystal_star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp_vbox.add_child(_crystal_star_label)

	# ——— 左下角状态面板：血量条 / 经验条 横向并排 ———
	# 设计（1152x648 基准）：圆角半透明底板，距左 30 / 距底 30；
	# 内部 12px 内边距；两栏各宽 185、栏间距 14 → 面板总宽 408（落在左半屏内）；
	# 每栏：小标题(12px) + 条(185x16)，条上居中显示数值；下方百分比竖线随填充移动。
	var status_panel := Panel.new()
	root.add_child(status_panel)
	status_panel.anchor_left = 0.0
	status_panel.anchor_top = 1.0
	status_panel.anchor_right = 0.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_left = 30.0
	status_panel.offset_right = 438.0      # 面板宽 408，贴左半屏
	status_panel.offset_top = -94.0        # 距底 30 + 高 64
	status_panel.offset_bottom = -30.0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.055, 0.065, 0.10, 0.72)
	panel_sb.border_color = Color(0.30, 0.34, 0.45, 0.9)
	panel_sb.border_width_left = 1
	panel_sb.border_width_top = 1
	panel_sb.border_width_right = 1
	panel_sb.border_width_bottom = 1
	panel_sb.corner_radius_top_left = 14
	panel_sb.corner_radius_top_right = 14
	panel_sb.corner_radius_bottom_left = 14
	panel_sb.corner_radius_bottom_right = 14
	status_panel.add_theme_stylebox_override("panel", panel_sb)

	# 内边距容器（12px）
	var status_pad := MarginContainer.new()
	status_panel.add_child(status_pad)
	status_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_pad.add_theme_constant_override("margin_left", 12)
	status_pad.add_theme_constant_override("margin_top", 12)
	status_pad.add_theme_constant_override("margin_right", 12)
	status_pad.add_theme_constant_override("margin_bottom", 12)
	status_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 两栏横向并列
	var status_hbox := HBoxContainer.new()
	status_pad.add_child(status_hbox)
	status_hbox.add_theme_constant_override("separation", 14)
	status_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# —— 血量栏（左）——
	var hp_col := VBoxContainer.new()
	status_hbox.add_child(hp_col)
	hp_col.custom_minimum_size = Vector2(185.0, 0)
	hp_col.add_theme_constant_override("separation", 6)
	hp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hp_caption = Label.new()
	hp_col.add_child(_hp_caption)
	_hp_caption.text = "血量"
	_hp_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_caption.add_theme_font_size_override("font_size", 12)
	_hp_caption.add_theme_color_override("font_color", Color(0.68, 0.71, 0.80))
	_hp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hp_bar = TextureProgressBar.new()
	hp_col.add_child(_hp_bar)
	_hp_bar.custom_minimum_size = Vector2(185.0, 16.0)
	_hp_bar.min_value = 0.0
	
	
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.step = 0.0                  # 关键：默认 step=1.0 会把 0.73 四舍五入成 1.0，导致条只显满/空、黄线只到两端。设为 0 才保留小数比例
	_hp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_hp_bar.texture_progress = preload("res://Assets/Sprites/UI/hp_fill.png")
	_hp_bar.texture_under = preload("res://Assets/Sprites/UI/hp_frame.png")

	# 数值居中显示在条上（标签比条高，避免被裁剪）
	_hp_name = Label.new()
	_hp_bar.add_child(_hp_name)
	_hp_name.anchor_left = 0.0
	_hp_name.anchor_right = 1.0
	_hp_name.anchor_top = 0.5
	_hp_name.anchor_bottom = 0.5
	_hp_name.offset_top = -11.0
	_hp_name.offset_bottom = 11.0
	_hp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_name.text = "5 / 5"
	_hp_name.add_theme_font_size_override("font_size", 12)
	_hp_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_hp_name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hp_name.add_theme_constant_override("outline_size", 2)
	_hp_name.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 精确百分比竖线（随填充比例移动）：深色底 + 亮黄芯，保证在亮色填充上也清晰可见
	_hp_tick_bg = ColorRect.new()
	_hp_bar.add_child(_hp_tick_bg)
	_hp_tick_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	_hp_tick_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_tick_bg.custom_minimum_size = Vector2(4.0, 16.0)
	_hp_tick = ColorRect.new()
	_hp_tick_bg.add_child(_hp_tick)
	_hp_tick.color = Color(1.0, 0.9, 0.0, 1.0)
	_hp_tick.position = Vector2(1.0, 0.0)
	_hp_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_tick.custom_minimum_size = Vector2(2.0, 16.0)

	# —— 经验栏（右）——
	var exp_col := VBoxContainer.new()
	status_hbox.add_child(exp_col)
	exp_col.custom_minimum_size = Vector2(185.0, 0)
	exp_col.add_theme_constant_override("separation", 6)
	exp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_exp_caption = Label.new()
	exp_col.add_child(_exp_caption)
	_exp_caption.text = "经验"
	_exp_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_caption.add_theme_font_size_override("font_size", 12)
	_exp_caption.add_theme_color_override("font_color", Color(0.68, 0.71, 0.80))
	_exp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_exp_bar = TextureProgressBar.new()
	exp_col.add_child(_exp_bar)
	_exp_bar.custom_minimum_size = Vector2(185.0, 16.0)
	_exp_bar.min_value = 0.0
	_exp_bar.max_value = 1.0
	_exp_bar.value = 0.0
	_exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_bar.step = 0.0                  # 同上，保留经验的小数比例
	_exp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_exp_bar.texture_progress = preload("res://Assets/Sprites/UI/xp_fill.png")
	_exp_bar.texture_under = preload("res://Assets/Sprites/UI/xp_frame.png")

	_exp_name = Label.new()
	_exp_bar.add_child(_exp_name)
	_exp_name.anchor_left = 0.0
	_exp_name.anchor_right = 1.0
	_exp_name.anchor_top = 0.5
	_exp_name.anchor_bottom = 0.5
	_exp_name.offset_top = -11.0
	_exp_name.offset_bottom = 11.0
	_exp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exp_name.text = "Lv. 1"
	_exp_name.add_theme_font_size_override("font_size", 12)
	_exp_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_exp_name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_exp_name.add_theme_constant_override("outline_size", 2)
	_exp_name.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 精确百分比竖线（随填充比例移动）：深色底 + 亮黄芯
	_exp_tick_bg = ColorRect.new()
	_exp_bar.add_child(_exp_tick_bg)
	_exp_tick_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	_exp_tick_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_tick_bg.custom_minimum_size = Vector2(4.0, 16.0)
	_exp_tick = ColorRect.new()
	_exp_tick_bg.add_child(_exp_tick)
	_exp_tick.color = Color(1.0, 0.9, 0.0, 1.0)
	_exp_tick.position = Vector2(1.0, 0.0)
	_exp_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_tick.custom_minimum_size = Vector2(2.0, 16.0)
	
	# 构建底部装备槽微型图标
	_build_gear_slots()

func _process(_delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		_refresh_player()
		return
	if _player.has_method("get_exp_ratio"):
		_exp_bar.value = _player.get_exp_ratio()
	if _player.has_method("get_level"):
		_exp_name.text = "Lv. " + str(_player.get_level())
	if _player.has_method("get_hp_ratio"):
		_hp_bar.value = _player.get_hp_ratio()
	if _player.has_method("get_hp") and _player.has_method("get_max_hp"):
		_hp_name.text = "%d / %d" % [int(round(_player.get_hp())), int(round(_player.get_max_hp()))]
	# 精确百分比竖线：随真实填充比例在条上移动。
	# 居中点 = 比例 × 条宽（即填充边界）；整根 4px 竖线严格 clamb 在 [0, 条宽-4] 内，绝不超出条子左右边界。
	var tick_w: float = 4.0
	var tick_half: float = tick_w * 0.5
	if _hp_bar.size.x > 0.0:
		var r: float = clamp(_hp_bar.value, 0.0, 1.0)
		_hp_tick_bg.position.x = clamp(r * _hp_bar.size.x - tick_half, 0.0, _hp_bar.size.x - tick_w)
	if _exp_bar.size.x > 0.0:
		var r: float = clamp(_exp_bar.value, 0.0, 1.0)
		_exp_tick_bg.position.x = clamp(r * _exp_bar.size.x - tick_half, 0.0, _exp_bar.size.x - tick_w)
	# 计时 / 击杀 / 钻石（RunStats 单例）—— 数值滚动 + 变化弹跳
	if RunStats != null:
		_timer_label.text = RunStats.get_time_string()
		_animate_stat(_kill_label, RunStats.kills, _delta)
		_animate_stat(_diamond_label, RunStats.run_diamonds, _delta)
	if RunStats != null and RunStats.boss_ref != null and is_instance_valid(RunStats.boss_ref):
		_boss_bar.visible = true
		_boss_label.visible = true
		_wave_label.visible = true    # boss 战期间照常显示波次：波次(y8~30)/计时(y32~54)/boss血条(y78~94) 三行互不重叠
		var bn: Variant = RunStats.boss_ref.get("boss_name")
		if bn == null or bn == "":
			_boss_label.text = "BOSS"
		else:
			_boss_label.text = bn
		if RunStats.boss_ref.has_method("get_hp_ratio"):
			_boss_bar.value = RunStats.boss_ref.get_hp_ratio()
	else:
		_boss_bar.visible = false
		_boss_label.visible = false
		_wave_label.visible = true
	# 波次标签（WaveManager 单例）
	if WaveManager != null and WaveManager.has_method("get_wave_label"):
		_wave_label.text = WaveManager.get_wave_label()
	# 刷新装备槽图标
	_refresh_gear_slots()
	# 水晶血量+星级
	_update_crystal_panel()

func _animate_stat(label: Label, target: int, delta: float) -> void:
	## 右上角数值动态感：数值平滑滚动(count-up) + 变化瞬间放大回弹 + 提亮闪。
	## 动画状态存放在 label 的 meta，无需额外成员变量，击杀/钻石两处复用。
	if not label.has_meta("disp"):
		label.set_meta("disp", float(target))
		label.set_meta("bump", 0.0)
		label.set_meta("last_t", target)
	var disp: float = label.get_meta("disp")
	var bump: float = label.get_meta("bump")
	var last_t: int = label.get_meta("last_t")
	if target != last_t:
		bump = 1.0            # 目标改变 -> 触发一次弹跳
		last_t = target
	if disp != float(target):
		# count-up：差值越大步长越快，保证大跳也顺滑
		var step: float = max(1.0, abs(float(target) - disp) * delta * 12.0)
		disp = move_toward(disp, float(target), step)
		label.text = str(int(round(disp)))
	if bump > 0.0:
		bump = max(0.0, bump - delta * 5.0)   # ~0.2s 衰减
		var s: float = 1.0 + sin(bump * PI) * 0.35
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2(s, s)
		var g: float = bump                     # 0..1 提亮闪
		label.modulate = Color(1.0 + g * 0.8, 1.0 + g * 0.8, 1.0 + g * 0.8)
	else:
		label.scale = Vector2(1.0, 1.0)
		label.modulate = Color(1.0, 1.0, 1.0)
	label.set_meta("disp", disp)
	label.set_meta("bump", bump)
	label.set_meta("last_t", last_t)

func _build_gear_slots() -> void:
	## 在左下角状态面板上方构建6个微型装备槽图标
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", int(_gear_slot_gap))
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root: Node = get_child(0)   # _build_ui() 中添加的第一个子节点是 root Control
	if root == null:
		return
	root.add_child(container)
	container.anchor_left = 0.0
	container.anchor_top = 1.0
	container.anchor_right = 0.0
	container.anchor_bottom = 1.0
	container.offset_left = 30.0
	container.offset_top = -118.0   # 在状态面板（-94）上方留一点间距
	container.offset_bottom = -98.0
	container.offset_right = 30.0 + 6 * (_gear_slot_size + _gear_slot_gap)
	_gear_slot_root = container

	for sid in EquipmentManager.SLOT_ORDER:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(_gear_slot_size, _gear_slot_size)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.11, 0.16, 0.55)
		sb.border_color = Color(0.50, 0.60, 0.72, 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		# 图标层（装备图标 / 锁图标），默认隐藏，刷新时按状态显示
		var art := TextureRect.new()
		art.name = "Art"
		art.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(_gear_slot_size - 6.0, _gear_slot_size - 6.0)
		art.size = Vector2(_gear_slot_size - 6.0, _gear_slot_size - 6.0)
		art.position = Vector2(3.0, 3.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.visible = false
		slot.add_child(art)
		# 文字层（图标缺失时回退显示）
		var lb := Label.new()
		lb.name = "Label"
		lb.text = EquipmentManager.SLOT_NAMES.get(sid, sid).substr(0, 1)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 0.9))
		lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lb)
		container.add_child(slot)
		_gear_slots.append(slot)

func _refresh_gear_slots() -> void:
	if EquipmentManager == null or RunStats == null or _gear_slots.is_empty():
		return
	var unlocked: Array[String] = EquipmentManager.get_unlocked_slots()
	for i in range(min(_gear_slots.size(), EquipmentManager.SLOT_ORDER.size())):
		var slot: Panel = _gear_slots[i]
		var sid: String = EquipmentManager.SLOT_ORDER[i]
		var sb: StyleBox = slot.get_theme_stylebox("panel")
		if sb == null or not (sb is StyleBoxFlat):
			sb = StyleBoxFlat.new()
		var art: TextureRect = slot.get_node_or_null("Art")
		var lb: Label = slot.get_node_or_null("Label")
		var is_unlocked: bool = sid in unlocked
		var inst: Dictionary = RunStats.equipped_gear.get(sid, {})
		if not inst.is_empty():
			# 有穿装备：显示装备图标（满不透明），边框色 = 稀有度
			var def_id: String = inst.get("def_id", "")
			var rarity: int = EquipmentManager.get_gear_rarity(def_id)
			var col: Color = EquipmentManager.get_rarity_color(rarity)
			var gear_icon_path: String = _GEAR_ICON_DIR + def_id + ".png"
			if ResourceLoader.exists(gear_icon_path):
				if art != null:
					art.texture = load(gear_icon_path)
					art.modulate = Color(1, 1, 1, 1)
					art.visible = true
				if lb != null:
					lb.visible = false
			else:
				if art != null:
					art.visible = false
				if lb != null:
					lb.text = EquipmentManager.SLOT_NAMES.get(sid, sid).substr(0, 1)
					lb.add_theme_color_override("font_color", col)
					lb.visible = true
			sb.bg_color = Color(0.08, 0.11, 0.16, 0.55)
			sb.border_color = col
		elif not is_unlocked:
			# 真正锁住：锁图标 + 灰底
			sb.bg_color = Color(0.04, 0.05, 0.07, 0.35)
			sb.border_color = Color(0.30, 0.30, 0.32, 0.50)
			var lock_path: String = _SLOT_ICON_DIR + "lock.png"
			if ResourceLoader.exists(lock_path):
				if art != null:
					art.texture = load(lock_path)
					art.modulate = Color(1, 1, 1, 1)
					art.visible = true
				if lb != null:
					lb.visible = false
			else:
				if art != null:
					art.visible = false
				if lb != null:
					lb.text = "🔒"
					lb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
					lb.visible = true
		else:
			# 已解锁但未装备：显示该槽位自己的图标（压暗）作为占位
			sb.bg_color = Color(0.08, 0.11, 0.16, 0.55)
			sb.border_color = Color(0.50, 0.60, 0.72, 0.85)
			var slot_icon_path: String = _SLOT_ICON_DIR + sid + ".png"
			if ResourceLoader.exists(slot_icon_path):
				if art != null:
					art.texture = load(slot_icon_path)
					art.modulate = Color(1, 1, 1, 0.40)
					art.visible = true
				if lb != null:
					lb.visible = false
			else:
				if art != null:
					art.visible = false
				if lb != null:
					lb.text = EquipmentManager.SLOT_NAMES.get(sid, sid).substr(0, 1)
					lb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
					lb.visible = true
		slot.add_theme_stylebox_override("panel", sb)

func _update_crystal_panel() -> void:
	var is_level_05: bool = RunStats != null and RunStats.game_mode == "level" and RunStats.selected_level_id == "level_05"
	var is_level_06: bool = RunStats != null and RunStats.game_mode == "level" and RunStats.selected_level_id == "level_06"
	if is_level_05:
		# 猎杀行动：显示玩家血量百分比+星级
		if _player == null or not is_instance_valid(_player) or not _player.has_method("get_hp") or not _player.has_method("get_max_hp"):
			_crystal_panel.visible = false
			return
		_crystal_panel.visible = true
		var hp: float = _player.get_hp()
		var max_hp: float = _player.get_max_hp()
		var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0
		var pct: int = int(ratio * 100)
		_crystal_hp_label.text = "血量 %d%%" % pct
		if ratio > 0.8:
			_crystal_star_label.text = "★★★"
			_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		elif ratio > 0.6:
			_crystal_star_label.text = "★★☆"
			_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		elif ratio > 0.4:
			_crystal_star_label.text = "★☆☆"
			_crystal_star_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		else:
			_crystal_star_label.text = "☆☆☆"
			_crystal_star_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		return
	if is_level_06:
		# BOSS连战：显示当前阶段+星级
		var wm = get_node_or_null("/root/WaveManager")
		var kills: int = 0
		var in_boss_phase: bool = false
		if wm != null:
			if wm.get("_boss_rush_kills") != null:
				kills = wm.get("_boss_rush_kills")
			if wm.get("_boss_rush_boss_phase") != null:
				in_boss_phase = wm.get("_boss_rush_boss_phase")
		_crystal_panel.visible = true
		if in_boss_phase:
			_crystal_hp_label.text = "击败 %d / 5 BOSS" % kills
		else:
			_crystal_hp_label.text = "小怪阶段 - 准备迎战"
		if kills >= 5:
			_crystal_star_label.text = "★★★"
			_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		elif kills >= 3:
			_crystal_star_label.text = "★★☆"
			_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		elif kills >= 1:
			_crystal_star_label.text = "★☆☆"
			_crystal_star_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		else:
			_crystal_star_label.text = "☆☆☆"
			_crystal_star_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		return
	# 水晶防御模式
	var crystal: Node2D = get_tree().get_first_node_in_group("crystal") as Node2D
	if crystal == null or not is_instance_valid(crystal) or crystal.is_destroyed():
		_crystal_panel.visible = false
		return
	_crystal_panel.visible = true
	var ratio: float = crystal.get_hp_ratio()
	var pct: int = int(ratio * 100)
	_crystal_hp_label.text = "水晶 %d%%" % pct
	if ratio > 0.6:
		_crystal_star_label.text = "★★★"
		_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif ratio > 0.4:
		_crystal_star_label.text = "★★☆"
		_crystal_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif ratio > 0.2:
		_crystal_star_label.text = "★☆☆"
		_crystal_star_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	else:
		_crystal_star_label.text = "☆☆☆"
		_crystal_star_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
