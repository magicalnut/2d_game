extends Node2D

## 关卡模式：5关顺序挑战
## 暗影守卫→深渊领主→虚空霸主→老赛→德牧蓝

const BOSS_DEFS := [
	{"name":"暗影守卫","hp":467.0,"speed":120.0,"touch":2.5,"exp":30.0,
	 "pool":["aimed"],"path":"res://Assets/Sprites/Bosses/Boss3/Body/frame_01.png",
	 "tint":Color(0.20,0.50,0.30),"animated":true,
	 "frames_dir":"res://Assets/Sprites/Bosses/Boss3/Body/"},
	{"name":"深渊领主","hp":600.0,"speed":140.0,"touch":3.5,"exp":38.0,
	 "pool1":["aimed","ring"],"pool2":["aimed","ring","charge"],
	 "path":"res://Assets/Sprites/Bosses/Boss4/Body/frame_01.png",
	 "tint":Color(0.70,0.30,0.20),"animated":true,
	 "frames_dir":"res://Assets/Sprites/Bosses/Boss4/Body/"},
	{"name":"虚空霸主","hp":733.0,"speed":110.0,"touch":4.0,"exp":45.0,
	 "pool":["ring","spiral","nova","laser"],"path":"res://Assets/Sprites/Bosses/Boss5/Body/frame_01.png",
	 "tint":Color(0.50,0.20,0.60),"animated":true,
	 "frames_dir":"res://Assets/Sprites/Bosses/Boss5/Body/"},
	{"name":"老赛","hp":1000.0,"speed":136.0,"touch":4.0,"exp":45.0,
	 "pool1":["melee"],"pool2":["melee","charge"],
	 "path":"res://Assets/Sprites/Bosses/Boss1/Body/body.png",
	 "tint":Color(0.90,0.22,0.20)},
	{"name":"德牧蓝","hp":1200.0,"speed":116.0,"touch":4.0,"exp":45.0,
	 "pool1":["aimed"],"pool2":["burst","aimed"],
	 "path":"res://Assets/Sprites/Bosses/Boss2/Body/body.png",
	 "tint":Color(0.30,0.55,0.95)},
]

# 每关小怪波次配置：全部刷完 + 清空场上敌人 → 出 BOSS
const LEVEL_WAVES := {
	0: [  # 暗影守卫：狼+少量射手
		{"kind":"fox", "count":8, "interval":0.8},
		{"kind":"agent", "count":3, "interval":2.0},
	],
	1: [  # 深渊领主：狼+射手+壮汉
		{"kind":"fox", "count":10, "interval":0.7},
		{"kind":"agent", "count":5, "interval":1.5},
		{"kind":"mario", "count":2, "interval":2.5},
	],
	2: [  # 虚空霸主：大量混合
		{"kind":"fox", "count":12, "interval":0.6},
		{"kind":"agent", "count":6, "interval":1.2},
		{"kind":"mario", "count":3, "interval":2.0},
		{"kind":"armored", "count":2, "interval":3.0},
	],
	3: [  # 老赛：重甲+狼
		{"kind":"armored", "count":4, "interval":2.0},
		{"kind":"fox", "count":10, "interval":0.6},
		{"kind":"agent", "count":4, "interval":1.8},
	],
	4: [  # 猎杀行动：无尽模式第一层的fox海
		{"kind":"fox", "count":42, "interval":0.26, "burst":12},
	],
}

var _level: int = -1
var _active_boss: Node2D = null
var _boss_spawned: bool = false
var _banner: Label = null
var _banner_timer: float = 0.0
var _inter_timer: float = 0.0
var _state: String = "idle"
var _game_over_ui: Node = null
var _hud: Node = null
var _pause_overlay: CanvasLayer = null
var _wave_groups: Array = []       # 当前关的小怪生成组
var _wave_done: bool = false       # 所有组刷完
var _boss_timer: float = 0.0       # 猎杀行动BOSS计时器

func _ready() -> void:
	# 重置局内状态
	if RunStats != null:
		RunStats.kills = 0
		RunStats.time_survived = 0.0
		RunStats.last_wave_reached = 0
		RunStats.boss_ref = null
	if WaveManager != null:
		WaveManager.level_mode_active = true

	# 背景
	var bg := Sprite2D.new()
	bg.position = Vector2(2560, 1440)
	bg.z_index = -100
	if ResourceLoader.exists("res://Assets/Sprites/Backgrounds/battle_bg.png"):
		bg.texture = load("res://Assets/Sprites/Backgrounds/battle_bg.png")
	add_child(bg)

	# 玩家
	var ps = load("res://Scenes/player.tscn")
	if ps:
		var p = ps.instantiate()
		p.position = Vector2(2560, 1440)
		if ResourceLoader.exists("res://Assets/Sprites/Weapons/Bullet/bullet.tscn"):
			p.set("bullet_scene", load("res://Assets/Sprites/Weapons/Bullet/bullet.tscn"))
		p.set("aim_radius", 500.0)
		add_child(p)
		# 连接死亡信号
		if p.has_signal("died"):
			p.died.connect(_on_player_died)

	# 初始武器
	if RunStats != null and SkillManager != null:
		SkillManager.grant(RunStats.get_character_def().get("start_weapon", ""))

	# HUD
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = 5
	_hud.set_script(preload("res://Assets/Scripts/hud.gd"))
	add_child(_hud)

	# 特殊技能选择 UI
	var ss := CanvasLayer.new()
	ss.name = "SpecialSelectUI"
	ss.layer = 21
	ss.process_mode = Node.PROCESS_MODE_ALWAYS
	ss.set_script(preload("res://Assets/Scripts/special_select_ui.gd"))
	add_child(ss)

	# 升级选择 UI（需在 player 就绪后连接 leveled_up 信号）
	var upgrade := CanvasLayer.new()
	upgrade.name = "UpgradeUI"
	upgrade.layer = 20
	upgrade.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade.set_script(preload("res://Assets/Scripts/upgrade_ui.gd"))
	add_child(upgrade)

	# 死亡结算屏
	_game_over_ui = CanvasLayer.new()
	_game_over_ui.name = "GameOverUI"
	_game_over_ui.layer = 30
	_game_over_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_ui.set_script(preload("res://Assets/Scripts/game_over.gd"))
	add_child(_game_over_ui)

	_create_banner()
	_next_level()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_toggle_pause()

func _toggle_pause() -> void:
	var t := get_tree()
	if t != null:
		t.paused = not t.paused
	if _pause_overlay == null:
		_create_pause_overlay()
	var _t := get_tree()
	_pause_overlay.visible = _t != null and _t.paused

func _create_pause_overlay() -> void:
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.layer = 40
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_pause_overlay.add_child(vbox)
	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	vbox.add_child(title)
	var resume_btn := Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.custom_minimum_size = Vector2(240.0, 64.0)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_btn.add_theme_font_size_override("font_size", 26)
	resume_btn.pressed.connect(_toggle_pause)
	vbox.add_child(resume_btn)
	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(240.0, 64.0)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_size_override("font_size", 26)
	menu_btn.pressed.connect(_on_level_menu)
	vbox.add_child(menu_btn)

func _on_level_menu() -> void:
	var t := get_tree()
	if t != null:
		t.paused = false
		t.change_scene_to_file("res://Scenes/menu.tscn")

func _process(delta: float) -> void:
	if _banner_timer > 0.0: _banner_timer -= delta
	if _banner_timer <= 0.0 and _banner != null: _banner.visible = false
	# 猎杀行动：5分钟BOSS计时器（始终运行）
	if _level == 4 and not _boss_spawned and _state == "fighting":
		_boss_timer += delta
		if _boss_timer >= 300.0:
			_spawn_boss(); _state = "boss"
	match _state:
		"fighting":
			# 猎杀行动BOSS已生成后停止刷小兵
			if _level == 4 and _boss_spawned:
				pass
			else:
				_drip_spawn(delta)
			if _wave_done and get_tree().get_nodes_in_group("enemy").size() == 0 and not _boss_spawned:
				_spawn_boss(); _state = "boss"
		"boss":
			if not is_instance_valid(_active_boss):
				if RunStats != null:
					RunStats.boss_ref = null
				if _level == 4:
					_calc_level_stars()
					if _game_over_ui != null and _game_over_ui.has_method("set_level_complete"):
						_game_over_ui.set_level_complete(true)
					_show_victory()
					return
				_boss_spawned = false; _state = "intermission"; _inter_timer = 3.0
		"intermission":
			_inter_timer -= delta
			if _inter_timer <= 0.0: _next_level()

func _drip_spawn(delta: float) -> void:
	if _wave_done:
		return
	var alive := get_tree().get_nodes_in_group("enemy").size()
	var max_alive: int = 60 if _level != 4 else 55
	var all_done := true
	for grp in _wave_groups:
		if grp["remaining"] <= 0:
			continue
		all_done = false
		grp["timer"] -= delta
		if grp["timer"] <= 0.0 and alive < max_alive:
			_spawn_level_enemy(grp["kind"])
			grp["remaining"] -= 1
			grp["timer"] = grp["interval"]
			alive += 1
	if all_done:
		_wave_done = true

func _spawn_level_enemy(kind: String) -> void:
	if WaveManager == null:
		return
	var scene: PackedScene = WaveManager.ENEMY_SCENES.get(kind)
	if scene == null:
		return
	var e = scene.instantiate()
	e.set_script(WaveManager.ENEMY_SCRIPT)
	var role: Dictionary = WaveManager.ENEMY_ROLES.get(kind, {})
	if role.has("hp"):           e.hp = role["hp"]
	if role.has("speed"):        e.speed = role["speed"]
	if role.has("touch_damage"): e.touch_damage = role["touch_damage"]
	if role.has("ranged"):          e.ranged = role["ranged"]
	if role.has("stationary"):      e.stationary = role["stationary"]
	if role.has("fire_range"):      e.fire_range = role["fire_range"]
	if role.has("preferred_range"): e.preferred_range = role["preferred_range"]
	if role.has("fire_rate"):       e.fire_rate = role["fire_rate"]
	if role.has("bullet_damage"):   e.bullet_damage = role["bullet_damage"]
	if role.has("bullet_speed"):    e.bullet_speed = role["bullet_speed"]
	if role.has("ranged") and role["ranged"]:
		e.bullet_scene = WaveManager.ENEMY_BULLET_SCENE
	# fox / mario 精灵图只有右向行走素材，向左走时需水平镜像
	if kind == "fox" or kind == "mario":
		e.flip_left_walk = true
	e.global_position = _pick_spawn_pos()
	add_child(e)

func _next_level() -> void:
	_level += 1
	if RunStats != null:
		RunStats.last_wave_reached = _level
	if _level >= BOSS_DEFS.size(): _show_victory(); return
	_boss_spawned = false
	_boss_timer = 0.0
	# 初始化小怪波次
	_wave_groups = []
	_wave_done = false
	var wave_cfg: Array = LEVEL_WAVES.get(_level, [])
	for cfg in wave_cfg:
		_wave_groups.append({
			"kind": cfg["kind"],
			"remaining": cfg["count"],
			"interval": cfg["interval"],
			"timer": 0.5,
			"burst": cfg.get("burst", 0),
		})
	# 开局先砸一批(burst)，制造即时压迫感
	for grp in _wave_groups:
		var b: int = grp["burst"]
		for _i in b:
			if grp["remaining"] <= 0:
				break
			_spawn_level_enemy(grp["kind"])
			grp["remaining"] -= 1
	_show_banner("第 %d 关 - %s" % [_level+1, _get_level_name()], 2.5)
	_state = "fighting"

func _get_level_name() -> String:
	if _level == 4:
		return "猎杀行动"
	return BOSS_DEFS[_level]["name"]

func _pick_spawn_pos() -> Vector2:
	var view := get_viewport_rect()
	var margin: float = 120.0
	var side: int = randi() % 4
	match side:
		0: return Vector2(randf_range(margin, view.size.x - margin), -margin)
		1: return Vector2(view.size.x + margin, randf_range(margin, view.size.y - margin))
		2: return Vector2(randf_range(margin, view.size.x - margin), view.size.y + margin)
		_: return Vector2(-margin, randf_range(margin, view.size.y - margin))

func _spawn_boss() -> void:
	if _boss_spawned: return
	_boss_spawned = true
	var d: Dictionary
	if _level == 4:
		# 猎杀行动：随机BOSS，血量700
		var idx: int = randi() % BOSS_DEFS.size()
		d = BOSS_DEFS[idx].duplicate()
		d["hp"] = 700.0
	else:
		d = BOSS_DEFS[_level]
	var bs = load("res://Assets/Sprites/Bosses/boss.tscn")
	if bs == null: return
	var b = bs.instantiate()
	b.hp = d["hp"] * 2.0 / 3.0; b.touch_damage = d["touch"]; b.exp_value = d["exp"]; b.def = d
	b.global_position = Vector2(2560, 1440)
	add_child(b); _active_boss = b
	if RunStats != null:
		RunStats.boss_ref = b
	# boss 名字改由 HUD 顶部 _boss_label 显示，不再单独弹横幅（避免与顶部重复）

func _show_victory() -> void:
	_state = "victory"; _show_banner("全部通关！", 5.0)
	# 延迟后弹出胜利结算（复用死亡结算UI）
	await get_tree().create_timer(2.0).timeout
	if _game_over_ui != null and _game_over_ui.has_method("show_game_over"):
		_game_over_ui.show_game_over()

func _on_player_died() -> void:
	if _level == 4:
		# 猎杀行动：阵亡也结算星级
		_calc_level_stars()
	if _game_over_ui != null and _game_over_ui.has_method("show_game_over"):
		_game_over_ui.show_game_over()

func _calc_level_stars() -> void:
	if RunStats == null:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("get_hp") and p.has_method("get_max_hp"):
		var hp: float = p.get_hp()
		var max_hp: float = p.get_max_hp()
		var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0
		if ratio > 0.8:
			RunStats.crystal_hp_ratio = 1.0   # 3星
		elif ratio > 0.6:
			RunStats.crystal_hp_ratio = 0.6   # 2星
		elif ratio > 0.4:
			RunStats.crystal_hp_ratio = 0.4   # 1星
		else:
			RunStats.crystal_hp_ratio = 0.0   # 0星

func _create_banner() -> void:
	var l = CanvasLayer.new(); l.layer = 20; l.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(l)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.modulate = Color(1.0, 0.85, 0.5); _banner.visible = false
	l.add_child(_banner)

func _show_banner(text: String, duration: float) -> void:
	if _banner == null: return
	_banner.text = text; _banner.visible = true; _banner_timer = duration
