extends Node

## Audio-FX Pool & Haptik-Feedback fuer "Uriges Doppelkopf".
## Nutzt einen Pool von AudioStreamPlayern, damit schnelle Kartenfolgen nie abhacken,
## und loest auf Mobilgeraeten natives Haptik-Feedback via Input.vibrate_handheld() aus.

const POOL_SIZE := 8
var _players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _streams: Dictionary = {}
var muted: bool = false
var haptics_enabled: bool = true


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_load_sfx("card_play", "res://assets/sfx/card_play.wav")
	_load_sfx("card_deal", "res://assets/sfx/card_deal.wav")
	_load_sfx("card_scrub", "res://assets/sfx/card_scrub.wav")
	_load_sfx("trick_win", "res://assets/sfx/trick_win.wav")
	_load_sfx("bid_confirm", "res://assets/sfx/bid_confirm.wav")
	_load_sfx("error_buzz", "res://assets/sfx/error_buzz.wav")
	_load_sfx("knock", "res://assets/sfx/wizard_cast.wav")


func _load_sfx(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var s := ResourceLoader.load(path)
		if s is AudioStream:
			_streams[key] = s


func _play(key: String, volume_db: float = -4.0, pitch_jitter: float = 0.04) -> void:
	if muted or not _streams.has(key):
		return
	var p := _players[_next_idx]
	_next_idx = (_next_idx + 1) % POOL_SIZE
	p.stream = _streams[key]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _vibrate(duration_ms: int) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func play_card() -> void:
	_play("card_play", -2.0, 0.06)
	_vibrate(18)


func play_deal() -> void:
	_play("card_deal", -6.0, 0.08)


func play_scrub() -> void:
	_play("card_scrub", -14.0, 0.05)
	_vibrate(8)


func play_trick_win() -> void:
	_play("trick_win", -3.0, 0.02)
	_vibrate(32)


func play_bid() -> void:
	_play("bid_confirm", -4.0, 0.03)
	_vibrate(20)


func play_knock() -> void:
	_play("knock", -2.0, 0.03)
	_vibrate(45)


func play_error() -> void:
	_play("error_buzz", -5.0, 0.0)
	_vibrate(40)
