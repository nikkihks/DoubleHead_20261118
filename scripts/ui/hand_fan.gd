class_name HandFan
extends Control

## Haptischer Kartenfaecher mit Feder-Interpolation, Hysterese-Scrubbing,
## Drag-and-Drop mit 3D-Neigung und Snap-Back bei illegalem Zug.

signal card_played(card_id: String)

var _cards: Array[CardView] = []
var _hover_idx: int = -1
var _drag_idx: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _last_scrub_x: float = 0.0
var _my_turn: bool = false
var _play_zone_y: float = -70.0 # Relativ zum oberen Rand des Faechers


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(720, 190)


func set_hand(card_dicts: Array, legal_ids: Array, engine: DokoEngine, my_turn: bool) -> void:
	_my_turn = my_turn
	_hover_idx = -1
	_drag_idx = -1
	_is_dragging = false

	for c in _cards:
		c.queue_free()
	_cards.clear()

	# Sortieren: Truempfe links (absteigend), dann Fehlfarben
	var sorted_cards: Array[CardData] = []
	for d in card_dicts:
		sorted_cards.append(CardData.from_dict(d))
	sorted_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		var ta := engine.trump_order(a)
		var tb := engine.trump_order(b)
		if ta != tb:
			return ta > tb
		if a.suit != b.suit:
			return a.suit < b.suit
		return a.rank > b.rank
	)

	for cd in sorted_cards:
		var cv := CardView.new()
		var legal := (not my_turn) or legal_ids.has(cd.id)
		cv.setup(cd, true, engine.is_trump(cd), legal)
		add_child(cv)
		_cards.append(cv)

	_layout_cards(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cards(false)


func _process(delta: float) -> void:
	if _cards.is_empty():
		return
	var t := clampf(delta * 14.0, 0.0, 1.0)
	for i in range(_cards.size()):
		var cv := _cards[i]
		if _is_dragging and i == _drag_idx:
			var target_pos := get_local_mouse_position() - CardView.BASE_SIZE * 0.5
			cv.position = cv.position.lerp(target_pos, clampf(delta * 24.0, 0.0, 1.0))
			var tilt := clampf((target_pos.x - _drag_start_pos.x) * 0.0025, -0.22, 0.22)
			cv.rotation = lerpf(cv.rotation, tilt, t)
			cv.scale = cv.scale.lerp(Vector2(1.12, 1.12), t)
			cv.z_index = 100
		else:
			var target := _compute_card_target(i)
			cv.position = cv.position.lerp(target.pos, t)
			cv.rotation = lerpf(cv.rotation, target.rot, t)
			var sc := Vector2(1.08, 1.08) if i == _hover_idx else Vector2.ONE
			cv.scale = cv.scale.lerp(sc, t)
			cv.z_index = 50 + i if i == _hover_idx else i


func _layout_cards(instant: bool) -> void:
	for i in range(_cards.size()):
		var target := _compute_card_target(i)
		if instant:
			_cards[i].position = target.pos
			_cards[i].rotation = target.rot
			_cards[i].scale = Vector2.ONE
		_cards[i].set_lifted(i == _hover_idx)


func _compute_card_target(i: int) -> Dictionary:
	var n := _cards.size()
	if n == 0:
		return {"pos": Vector2.ZERO, "rot": 0.0}
	var avail_w := maxf(320.0, size.x - 40.0)
	var step := minf(76.0, (avail_w - CardView.BASE_SIZE.x) / maxf(1, n - 1))
	var total_w := step * (n - 1) + CardView.BASE_SIZE.x
	var start_x := (size.x - total_w) * 0.5
	var center_idx := (n - 1) * 0.5
	var norm := (i - center_idx) / maxf(1.0, center_idx)

	var x := start_x + i * step
	var y := 24.0 + norm * norm * 18.0
	if i == _hover_idx:
		y -= 26.0
	var jitter := float((i * 37) % 5 - 2) * 0.009
	var rot := norm * 0.16 + jitter
	return {"pos": Vector2(x, y), "rot": rot}


func _pick_card_at(local_pos: Vector2) -> int:
	for i in range(_cards.size() - 1, -1, -1):
		var cv := _cards[i]
		var rect := Rect2(cv.position, CardView.BASE_SIZE)
		if rect.has_point(local_pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if _cards.is_empty():
		return

	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if not _is_dragging:
			var idx := _pick_card_at(m.position)
			if idx != _hover_idx and absf(m.position.x - _last_scrub_x) > 8.0:
				_last_scrub_x = m.position.x
				_set_hover(idx)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var idx := _pick_card_at(mb.position)
				if idx >= 0:
					_drag_idx = idx
					_drag_start_pos = _cards[idx].position
					_is_dragging = true
					_cards[idx].set_lifted(true)
					_set_hover(idx)
			else:
				if _is_dragging and _drag_idx >= 0 and _drag_idx < _cards.size():
					var cv := _cards[_drag_idx]
					var dragged_dist := cv.position.distance_to(_drag_start_pos)
					var played := (cv.position.y < _play_zone_y) or (dragged_dist < 14.0)
					_is_dragging = false
					cv.set_lifted(false)
					if played and _my_turn:
						if cv.is_legal:
							card_played.emit(cv.card_data.id)
						else:
							AudioFX.play_error()
							_shake_card(cv)
					_drag_idx = -1


func _set_hover(idx: int) -> void:
	if _hover_idx >= 0 and _hover_idx < _cards.size():
		_cards[_hover_idx].set_lifted(false)
	_hover_idx = idx
	if _hover_idx >= 0 and _hover_idx < _cards.size():
		_cards[_hover_idx].set_lifted(true)
		AudioFX.play_scrub()


func _shake_card(cv: CardView) -> void:
	var orig := cv.position
	var tw := create_tween()
	tw.tween_property(cv, "position:x", orig.x - 10.0, 0.05)
	tw.tween_property(cv, "position:x", orig.x + 10.0, 0.06)
	tw.tween_property(cv, "position:x", orig.x, 0.05)
