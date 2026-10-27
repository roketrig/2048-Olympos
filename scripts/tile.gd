class_name Tile
extends Panel

# Colors carried over from the Unity TileState assets (2 ... 2048).
const BACKGROUNDS: Array[Color] = [
	Color(0.933, 0.894, 0.855), # 2
	Color(0.933, 0.882, 0.788), # 4
	Color(0.953, 0.698, 0.478), # 8
	Color(0.965, 0.588, 0.396), # 16
	Color(0.969, 0.486, 0.373), # 32
	Color(0.969, 0.373, 0.231), # 64
	Color(0.929, 0.816, 0.451), # 128
	Color(0.929, 0.800, 0.384), # 256
	Color(0.929, 0.788, 0.314), # 512
	Color(0.929, 0.773, 0.247), # 1024
	Color(0.929, 0.761, 0.180), # 2048
]
const BEYOND_BACKGROUND := Color(0.235, 0.227, 0.196)
const DARK_TEXT := Color(0.467, 0.431, 0.396)
const LIGHT_TEXT := Color(0.976, 0.965, 0.949)
const FONT_SIZES: Array[int] = [64, 64, 58, 48, 40, 34, 30]

var level := 0
var grid_pos := Vector2i.ZERO
var locked := false

var _label: Label
var _style: StyleBoxFlat
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", _style)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


static func value_of(tile_level: int) -> int:
	return 1 << (tile_level + 1)


func value() -> int:
	return value_of(level)


func set_level(value_level: int) -> void:
	level = value_level

	if level < BACKGROUNDS.size():
		_style.bg_color = BACKGROUNDS[level]
	else:
		_style.bg_color = BEYOND_BACKGROUND

	_label.text = str(value())
	_label.add_theme_color_override("font_color", DARK_TEXT if level < 2 else LIGHT_TEXT)
	_label.add_theme_font_size_override("font_size", FONT_SIZES[mini(_label.text.length(), FONT_SIZES.size() - 1)])


func resize(cell_size: float) -> void:
	size = Vector2(cell_size, cell_size)
	pivot_offset = size / 2.0


func appear() -> void:
	_restart_tween()
	scale = Vector2.ZERO
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pop(amount := 1.15, duration := 0.16) -> void:
	_restart_tween()
	scale = Vector2.ONE
	_tween.tween_property(self, "scale", Vector2.ONE * amount, duration * 0.5).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.5).set_ease(Tween.EASE_IN)


func _restart_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
