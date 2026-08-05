extends Node

## AudioManager（AutoLoad 单例）：管理全局 BGM 播放列表、Boss 音乐、音效。

var _bgm_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _boss_active: bool = false

# 全局 BGM 播放列表：all1 → all2 → all1 → ...（已移除 bgm_global）
const _BGM_PATHS := [
	"res://Assets/Audio/bgm_global1.mp3",
	"res://Assets/Audio/bgm_global2.mp3",
]
var _bgm_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_volume_db(0, -6.0)
	# 全局 BGM
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGM"
	_bgm_player.bus = "Master"
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)
	# Boss 音乐
	_boss_player = AudioStreamPlayer.new()
	_boss_player.name = "BossBGM"
	_boss_player.finished.connect(_on_boss_finished)
	add_child(_boss_player)
	_ensure_boss_bus()   # 为 Boss 音乐创建专用的「柔和」总线（低通滤波 + 降音量）
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
	var s := _load_mp3(_BGM_PATHS[_bgm_index])
	if s != null:
		_bgm_player.stream = s
		_bgm_player.play()


func _on_bgm_finished() -> void:
	if _boss_active:
		return
	_bgm_index = (_bgm_index + 1) % _BGM_PATHS.size()
	_play_global()


func _on_boss_finished() -> void:
	if _boss_active:
		_boss_player.play()


# 为 Boss 音乐创建专用总线：低通滤波（切掉刺耳高频）+ 适度降音量，
# 让原本偏紧张的 Boss 曲风听起来更柔和。原文件 bgm_boss.mp3 不动，随时可还原。
func _ensure_boss_bus() -> void:
	var idx := AudioServer.get_bus_index("BossBGM")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "BossBGM")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2200.0     # 只保留中低频，去掉尖刺高频 → 温暖柔和
		lp.resonance = 0.4
		AudioServer.add_bus_effect(idx, lp)
		AudioServer.set_bus_volume_db(idx, -4.0)   # 比全局 BGM 轻 4dB
	_boss_player.bus = "BossBGM"


# === 公开接口 ===

func play_boss_music() -> void:
	_boss_active = true
	_bgm_player.stream_paused = true   # 暂停全局 BGM，保留播放位置
	var s := _load_mp3("res://Assets/Audio/bgm_boss.mp3")
	if s != null:
		_boss_player.stream = s
		_boss_player.play()


func stop_boss_music() -> void:
	_boss_active = false
	_boss_player.stop()
	_bgm_player.stream_paused = false  # 从暂停位置继续播放全局 BGM


func play_select_sfx() -> void:
	var s := _load_mp3("res://Assets/Audio/sfx_select.mp3")
	if s != null:
		_sfx_player.stream = s
		_sfx_player.play()
