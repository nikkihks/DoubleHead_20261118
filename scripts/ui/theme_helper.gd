class_name ThemeHelper
extends RefCounted

## Zentrales "Uriges Wirtshaus" Design-System (Eichenholz, Schiefertafel, Messing, Bierdeckel).

const COL_BG_SLATE := Color(0.11, 0.13, 0.12, 0.94)
const COL_BG_DARK_WOOD := Color(0.17, 0.10, 0.06, 0.96)
const COL_BG_FELT := Color(0.09, 0.24, 0.16, 0.94)
const COL_BRASS := Color(0.82, 0.66, 0.34, 1.0)
const COL_BRASS_DIM := Color(0.55, 0.43, 0.22, 0.75)
const COL_CREAM := Color(0.96, 0.92, 0.84, 1.0)
const COL_MUTED := Color(0.76, 0.72, 0.64, 0.90)
const COL_DANGER := Color(0.75, 0.22, 0.20, 1.0)
const COL_SUCCESS := Color(0.24, 0.62, 0.36, 1.0)

static var _font_bold: Font
static var _font_serif: Font
static var _tex_wood_btn: Texture2D
static var _tex_slate_panel: Texture2D


static func font_bold() -> Font:
	if _font_bold == null and ResourceLoader.exists("res://assets/fonts/Cinzel-Bold.ttf"):
		_font_bold = ResourceLoader.load("res://assets/fonts/Cinzel-Bold.ttf")
	return _font_bold


static func font_serif() -> Font:
	if _font_serif == null and ResourceLoader.exists("res://assets/fonts/CrimsonPro-SemiBold.ttf"):
		_font_serif = ResourceLoader.load("res://assets/fonts/CrimsonPro-SemiBold.ttf")
	return _font_serif


static func make_slate_box(border_col: Color = COL_BRASS_DIM, radius: int = 14) -> StyleBox:
	if _tex_slate_panel == null and ResourceLoader.exists("res://assets/ui/slate_panel_9slice.png"):
		_tex_slate_panel = ResourceLoader.load("res://assets/ui/slate_panel_9slice.png")
	if _tex_slate_panel != null and border_col == COL_BRASS_DIM:
		var sbt := StyleBoxTexture.new()
		sbt.texture = _tex_slate_panel
		sbt.texture_margin_left = 16
		sbt.texture_margin_right = 16
		sbt.texture_margin_top = 16
		sbt.texture_margin_bottom = 16
		sbt.content_margin_left = 14
		sbt.content_margin_right = 14
		sbt.content_margin_top = 10
		sbt.content_margin_bottom = 10
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG_SLATE
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make_wood_box(radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG_DARK_WOOD
	sb.border_color = COL_BRASS
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func style_button(btn: Button, accent: Color = COL_BRASS, bg: Color = Color(0.20, 0.12, 0.07, 0.95)) -> void:
	if _tex_wood_btn == null and ResourceLoader.exists("res://assets/ui/wood_btn_9slice.png"):
		_tex_wood_btn = ResourceLoader.load("res://assets/ui/wood_btn_9slice.png")

	var normal: StyleBox
	if _tex_wood_btn != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = _tex_wood_btn
		sbt.texture_margin_left = 12
		sbt.texture_margin_right = 12
		sbt.texture_margin_top = 10
		sbt.texture_margin_bottom = 10
		sbt.content_margin_left = 14
		sbt.content_margin_right = 14
		sbt.content_margin_top = 8
		sbt.content_margin_bottom = 8
		sbt.modulate_color = Color(1.0, 1.0, 1.0) if accent == COL_BRASS else accent.lightened(0.35)
		normal = sbt
	else:
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = bg
		sbf.border_color = accent
		sbf.set_border_width_all(2)
		sbf.set_corner_radius_all(10)
		sbf.content_margin_left = 14
		sbf.content_margin_right = 14
		sbf.content_margin_top = 8
		sbf.content_margin_bottom = 8
		normal = sbf

	var hover := normal.duplicate()
	if hover is StyleBoxTexture:
		(hover as StyleBoxTexture).modulate_color = (hover as StyleBoxTexture).modulate_color.lightened(0.16)
	elif hover is StyleBoxFlat:
		(hover as StyleBoxFlat).bg_color = bg.lightened(0.14)

	var pressed := normal.duplicate()
	if pressed is StyleBoxTexture:
		(pressed as StyleBoxTexture).modulate_color = (pressed as StyleBoxTexture).modulate_color.darkened(0.18)
	elif pressed is StyleBoxFlat:
		(pressed as StyleBoxFlat).bg_color = bg.darkened(0.18)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.14, 0.14, 0.14, 0.6)
	disabled.border_color = Color(0.4, 0.4, 0.4, 0.4)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_CREAM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 0.6))
	if font_serif() != null:
		btn.add_theme_font_override("font", font_serif())


static func style_line_edit(le: LineEdit) -> void:
	var sb := make_wood_box(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_color_override("font_color", COL_CREAM)
	if font_serif() != null:
		le.add_theme_font_override("font", font_serif())


static func style_option_button(ob: OptionButton) -> void:
	style_button(ob, COL_BRASS_DIM)


static func style_scrollbar(sb: ScrollBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.07, 0.05, 0.7)
	bg.set_corner_radius_all(4)
	var grab := StyleBoxFlat.new()
	grab.bg_color = COL_BRASS_DIM
	grab.set_corner_radius_all(4)
	sb.add_theme_stylebox_override("scroll", bg)
	sb.add_theme_stylebox_override("grabber", grab)
	sb.add_theme_stylebox_override("grabber_highlight", grab)
	sb.add_theme_stylebox_override("grabber_pressed", grab)


static func style_title(lbl: Label, size: int = 28, col: Color = COL_BRASS) -> void:
	if font_bold() != null:
		lbl.add_theme_font_override("font", font_bold())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)


static func style_body(lbl: Label, size: int = 17, col: Color = COL_CREAM) -> void:
	if font_serif() != null:
		lbl.add_theme_font_override("font", font_serif())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
