extends Node

## AudioManager（AutoLoad 单例）：管理全局 BGM、Boss 音乐、音效。

var _bgm_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _boss_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 提高主总线音量（+10dB）
	AudioServer.set_bus_volume_db(0, 10.0)
	# 全局 BGM
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGM"
	_bgm_player.bus = "Master"
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)
	# Boss 音乐
	_boss_player = AudioStreamPlayer.new()
	_boss_player.name = "BossBGM"
	_boss_player.bus = "Master"
	_boss_player.finished.connect(_on_boss_finished)
	add_child(_boss_player)
	# 音效
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFX"
	_sfx_player.bus = "Master"
	add_child(_sfx_player)
	# 启动全局 BGM
	_play_global()


func _load_mp3(path: String) -> AudioStreamMP3:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var stream := AudioStreamMP3.new()
	stream.data = f.get_buffer(f.get_length())
	return stream


func _play_global() -> void:
	var s := _load_mp3("res://Assets/Audio/bgm_global.mp3")
	if s != null:
		_bgm_player.stream = s
		_bgm_player.play()


func _on_bgm_finished() -> void:
	if not _boss_active:
		_play_global()


func _on_boss_finished() -> void:
	if _boss_active:
		_boss_player.play()


func play_boss_music() -> void:
	_boss_active = true
	_bgm_player.stop()
	var s := _load_mp3("res://Assets/Audio/bgm_boss.mp3")
	if s != null:
		_boss_player.stream = s
		_boss_player.play()


func stop_boss_music() -> void:
	_boss_active = false
	_boss_player.stop()
	_play_global()


func play_select_sfx() -> void:
	var s := _load_mp3("res://Assets/Audio/sfx_select.mp3")
	if s != null:
		_sfx_player.stream = s
		_sfx_player.play()
