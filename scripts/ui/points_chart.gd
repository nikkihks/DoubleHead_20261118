class_name PointsChart
extends Control

## Interaktives Liniendiagramm fuer den Punkteverlauf im Schreibblock-Tracker.

const PLAYER_COLORS: Array[Color] = [
	Color(0.92, 0.72, 0.28), # Gold
	Color(0.35, 0.78, 0.52), # Tannen-Gruen
	Color(0.86, 0.36, 0.32), # Wirtshaus-Rot
	Color(0.42, 0.68, 0.92), # Blau
	Color(0.82, 0.52, 0.88), # Violett
	Color(0.95, 0.58, 0.26), # Kupfer
	Color(0.65, 0.85, 0.82), # Eis
	Color(0.88, 0.82, 0.55), # Stroh
]

var _series: Dictionary = {} # player_name -> Array[int]


func set_series(p_series: Dictionary) -> void:
	_series = p_series
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 60 or h < 60:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.09, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), ThemeHelper.COL_BRASS_DIM, false, 2.0)

	var pad := Vector2(46, 26)
	var plot := Rect2(pad, size - pad * 2.0)
	if plot.size.x <= 10 or plot.size.y <= 10:
		return

	var min_val := -10.0
	var max_val := 10.0
	var max_len := 1
	for p in _series.keys():
		var arr: Array = _series[p]
		max_len = maxi(max_len, arr.size())
		for v in arr:
			min_val = minf(min_val, float(v))
			max_val = maxf(max_val, float(v))

	var span := maxf(10.0, max_val - min_val)
	# Nulllinie
	var zero_y := plot.position.y + plot.size.y * (1.0 - (0.0 - min_val) / span)
	draw_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), Color(1, 1, 1, 0.25), 1.5)

	var font := ThemeHelper.font_serif()
	var idx := 0
	for p in _series.keys():
		var arr: Array = _series[p]
		var col := PLAYER_COLORS[idx % PLAYER_COLORS.size()]
		var pts := PackedVector2Array()
		for i in range(arr.size()):
			var x := plot.position.x + (float(i) / maxf(1.0, float(max_len - 1))) * plot.size.x
			var y := plot.position.y + plot.size.y * (1.0 - (float(arr[i]) - min_val) / span)
			pts.append(Vector2(x, y))
		if pts.size() >= 2:
			draw_polyline(pts, col, 3.0, true)
		for pt in pts:
			draw_circle(pt, 4.5, col)
		if font != null:
			draw_string(font, Vector2(plot.position.x + 8 + idx * 110, 20), str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		idx += 1
