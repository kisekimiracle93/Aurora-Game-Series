extends Node
## Autoload: skins every Control in the game with the Kenney RPG UI pack
## (public domain) when it's present in the toolbox; silently keeps the
## default theme otherwise. Applied to the root window so all scenes inherit.

const UI_DIR: String = "res://assets/all files/UIpack_RPG/PNG/"

const TEXT_DARK: Color = Color(0.25, 0.18, 0.12)
const TEXT_LIGHT: Color = Color(0.95, 0.93, 0.88)


func _ready() -> void:
	var theme: Theme = build_theme()
	if theme != null:
		get_window().theme = theme


const STONE_PANEL: String = "res://assets/sprites/ui/stone_panel.png"


static func build_theme() -> Theme:
	if not ResourceLoader.exists(UI_DIR + "panel_brown.png"):
		return null
	var theme: Theme = Theme.new()

	# Ancient-stone panels everywhere (opaque, tiled cobble), Kenney buttons on top.
	theme.set_stylebox("panel", "PanelContainer", _stone_panel())

	theme.set_stylebox("normal", "Button", _nine_patch("buttonLong_beige.png", 10, 6))
	theme.set_stylebox("hover", "Button", _nine_patch("buttonLong_blue.png", 10, 6))
	theme.set_stylebox("pressed", "Button", _nine_patch("buttonLong_beige_pressed.png", 10, 6))
	theme.set_stylebox("focus", "Button", _nine_patch("buttonLong_blue.png", 10, 6))
	theme.set_stylebox("disabled", "Button", _nine_patch("buttonLong_grey_pressed.png", 10, 6))
	theme.set_color("font_color", "Button", TEXT_DARK)
	theme.set_color("font_pressed_color", "Button", TEXT_DARK)
	theme.set_color("font_hover_color", "Button", TEXT_LIGHT)
	theme.set_color("font_focus_color", "Button", TEXT_DARK)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.36, 0.3))

	theme.set_stylebox("background", "ProgressBar", _nine_patch("barBack_horizontalMid.png", 5, 3))
	return theme


## Old cobblestone slab: tiled texture, dark edge inset, fully opaque.
static func _stone_panel() -> StyleBox:
	if not ResourceLoader.exists(STONE_PANEL):
		return _nine_patch("panel_brown.png", 12, 8)
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(STONE_PANEL)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.modulate_color = Color(0.85, 0.85, 0.9)
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, 8.0)
		box.set_content_margin(side, 10.0)
	return box


static func _nine_patch(file_name: String, margin: int, content_margin: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	var path: String = UI_DIR + file_name
	if ResourceLoader.exists(path):
		box.texture = load(path)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = float(content_margin + 6)
	box.content_margin_right = float(content_margin + 6)
	box.content_margin_top = float(content_margin)
	box.content_margin_bottom = float(content_margin)
	return box
