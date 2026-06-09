extends Node
# music_player.gd
# Autoload singleton — add to Project > Autoloads as "MusicPlayer"
#
# Owns the single AudioStreamPlayer that persists across scene changes.
# Scenes never create their own player — they call MusicPlayer instead.
#
# API
#   MusicPlayer.play(stream)        — start a new track (ignored if already playing same stream)
#   MusicPlayer.stop()              — stop immediately
#   MusicPlayer.stop_and_free()     — stop + release stream reference
#   MusicPlayer.fade_out(duration)  — tween volume to -80 dB then stop
#   MusicPlayer.is_playing() -> bool

var _player: AudioStreamPlayer

func _ready() -> void:
	_player               = AudioStreamPlayer.new()
	_player.bus           = "Master"   # change to "Master" 
	_player.volume_db     = 0.0
	add_child(_player)
	print("[MusicPlayer] Ready.")


# ─── Public API ──────────────────────────────────────────────────

func play(stream: AudioStream) -> void:
	if _player.stream == stream and _player.playing:
		return   # already playing this exact track — do nothing
	_player.stream = stream
	_player.volume_db = 0.0
	_player.play()
	print("[MusicPlayer] Playing: %s" % stream.resource_path)


func stop() -> void:
	_player.stop()
	print("[MusicPlayer] Stopped.")


func stop_and_free() -> void:
	_player.stop()
	_player.stream = null


func is_playing() -> bool:
	return _player.playing


func fade_out(duration: float = 0.5) -> void:
	var t := create_tween()
	t.tween_property(_player, "volume_db", -80.0, duration)
	t.tween_callback(_player.stop)
	t.tween_callback(func(): _player.volume_db = 0.0)
