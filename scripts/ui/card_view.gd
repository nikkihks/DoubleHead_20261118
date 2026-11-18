class_name CardView
extends Control

## Visuelle Spielkarte mit Eichenholz-/Elfenbein-Asset, Trumpf-Glanz,
## Schlagschatten beim Anheben und 3D-Neigungs-Feedback.

const BASE_SIZE := Vector2(110, 160)

var card_data: CardData
var is_face_up: bool = true
var is_legal: bool = true
var is_trump: bool = false
var is_selected: bool = false
var is_lifted: bool = false

var _shadow: Panel
var _tex_rect: TextureRect
var _trump_border: ReferenceRect
var _glow_phase: float = 0.0


func _init() -> void:
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	pivot_offset = BASE_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shadow = Panel.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0, 0, 0, 0.42)
	sbox.set_corner_radius_all(12)
	_shadow.add_theme_stylebox_override("panel", sbox)
	_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow.position = Vector2(3, 6)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	_tex_rect = TextureRect.new()
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex_rect)

	_trump_border = ReferenceRect.new()
	_trump_border.border_color = Color(0.92, 0.75, 0.28, 0.75)
	_trump_border.border_width = 2.0
	_trump_border.editor_only = false
	_trump_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trump_border.offset_left = 4
	_trump_border.offset_right = -4
	_trump_border.offset_top = 4
	_trump_border.offset_bottom = -4
	_trump_border.visible = false
	_trump_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trump_border)


func setup(p_card: CardData, p_face_up: bool = true, p_trump: bool = false, p_legal: bool = true) -> void:
	card_data = p_card
	is_face_up = p_face_up
	is_trump = p_trump
	is_legal = p_legal
	_refresh_visual()


func _refresh_visual() -> void:
	if not is_face_up or card_data == null:
		var back_path := "res://assets/cards/card_back.png"
		if ResourceLoader.exists(back_path):
			_tex_rect.texture = ResourceLoader.load(back_path)
		_trump_border.visible = false
		modulate = Color.WHITE
		return

	var suit_str := _suit_name(card_data.suit)
	var rank_str := _rank_name(card_data.rank)
	var path := "res://assets/cards/%s_%s.png" % [suit_str, rank_str]
	if ResourceLoader.exists(path):
		_tex_rect.texture = ResourceLoader.load(path)

	_trump_border.visible = is_trump
	modulate = Color.WHITE if is_legal else Color(0.62, 0.58, 0.54, 0.92)


func set_lifted(lifted: bool) -> void:
	is_lifted = lifted
	var target_shadow := Vector2(8, 16) if lifted else Vector2(3, 6)
	_shadow.position = target_shadow


func _process(delta: float) -> void:
	if is_trump and is_face_up and is_legal:
		_glow_phase += delta * 2.5
		var a := 0.45 + 0.30 * sin(_glow_phase)
		_trump_border.border_color = Color(0.92, 0.76, 0.28, a)


func _suit_name(s: CardData.Suit) -> String:
	match s:
		CardData.Suit.CLUBS: return "CLUBS"
		CardData.Suit.SPADES: return "SPADES"
		CardData.Suit.HEARTS: return "HEARTS"
		CardData.Suit.DIAMONDS: return "DIAMONDS"
	return "CLUBS"


func _rank_name(r: CardData.Rank) -> String:
	match r:
		CardData.Rank.NINE: return "NINE"
		CardData.Rank.JACK: return "JACK"
		CardData.Rank.QUEEN: return "QUEEN"
		CardData.Rank.KING: return "KING"
		CardData.Rank.TEN: return "TEN"
		CardData.Rank.ACE: return "ACE"
	return "NINE"
