class_name Board
extends Panel

signal score_gained(points: int)

const SIZE := 4
const GAP := 16.0
const MOVE_TIME := 0.1
const MAX_LEVEL := 16 # 131072
const BOARD_COLOR := Color(0.733, 0.678, 0.627)
const CELL_COLOR := Color(0.804, 0.757, 0.706)

var cell_size := 0.0
var cells: Array = [] # cells[y][x] -> Tile or null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _rounded(BOARD_COLOR, 14))


func setup(board_size: float) -> void:
	custom_minimum_size = Vector2(board_size, board_size)
	size = custom_minimum_size
	cell_size = (board_size - GAP * (SIZE + 1)) / SIZE

	for y in SIZE:
		for x in SIZE:
			var cell := Panel.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_stylebox_override("panel", _rounded(CELL_COLOR, 10))
			cell.position = cell_position(Vector2i(x, y))
			cell.size = Vector2(cell_size, cell_size)
			add_child(cell)

	clear()


func clear() -> void:
	for tile in tiles():
		tile.queue_free()

	cells.clear()
	for y in SIZE:
		var row := []
		row.resize(SIZE)
		cells.append(row)


func cell_position(p: Vector2i) -> Vector2:
	return Vector2(GAP + p.x * (cell_size + GAP), GAP + p.y * (cell_size + GAP))


func is_inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < SIZE and p.y >= 0 and p.y < SIZE


func tile_at(p: Vector2i) -> Tile:
	return cells[p.y][p.x] if is_inside(p) else null


func tiles() -> Array[Tile]:
	var result: Array[Tile] = []
	for row in cells:
		for tile in row:
			if tile != null:
				result.append(tile)
	return result


func neighbors(p: Vector2i) -> Array[Tile]:
	var result: Array[Tile] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var tile := tile_at(p + dir)
		if tile != null:
			result.append(tile)
	return result


func spawn_tile() -> Tile:
	var empty: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if cells[y][x] == null:
				empty.append(Vector2i(x, y))

	if empty.is_empty():
		return null

	var p: Vector2i = empty.pick_random()
	var tile := Tile.new()
	tile.resize(cell_size)
	tile.set_level(0)
	tile.grid_pos = p
	tile.position = cell_position(p)
	add_child(tile)
	cells[p.y][p.x] = tile
	tile.appear()
	return tile


# Slides every tile toward `dir`. Returns true if anything moved.
func move(dir: Vector2i) -> bool:
	var xs := range(SIZE)
	var ys := range(SIZE)
	if dir.x > 0:
		xs.reverse()
	if dir.y > 0:
		ys.reverse()

	var changed := false

	for y in ys:
		for x in xs:
			var tile: Tile = cells[y][x]
			if tile == null:
				continue

			var target := Vector2i(x, y)
			var next := target + dir
			while is_inside(next) and tile_at(next) == null:
				target = next
				next += dir

			var other := tile_at(next)
			if other != null and other.level == tile.level and not other.locked and other.level < MAX_LEVEL:
				_merge(tile, other)
				changed = true
			elif target != tile.grid_pos:
				_slide(tile, target)
				changed = true

	for tile in tiles():
		tile.locked = false

	return changed


func can_move() -> bool:
	for y in SIZE:
		for x in SIZE:
			var tile: Tile = cells[y][x]
			if tile == null:
				return true
			for neighbor in neighbors(tile.grid_pos):
				if neighbor.level == tile.level and tile.level < MAX_LEVEL:
					return true
	return false


# Raises a tile by `steps` levels (each step doubles it). Used by Zeus.
func upgrade(tile: Tile, steps: int) -> void:
	var old_value := tile.value()
	tile.set_level(mini(tile.level + steps, MAX_LEVEL))
	tile.pop(1.3, 0.3)
	score_gained.emit(tile.value() - old_value)


func _slide(tile: Tile, target: Vector2i) -> void:
	cells[tile.grid_pos.y][tile.grid_pos.x] = null
	cells[target.y][target.x] = tile
	tile.grid_pos = target
	tile.create_tween().tween_property(tile, "position", cell_position(target), MOVE_TIME)


func _merge(tile: Tile, into: Tile) -> void:
	cells[tile.grid_pos.y][tile.grid_pos.x] = null
	into.locked = true

	var new_level := into.level + 1
	into.level = new_level
	score_gained.emit(Tile.value_of(new_level))

	move_child(tile, into.get_index()) # slide underneath the tile it merges into
	var tween := tile.create_tween()
	tween.tween_property(tile, "position", cell_position(into.grid_pos), MOVE_TIME)
	tween.finished.connect(func() -> void:
		tile.queue_free()
		if is_instance_valid(into):
			into.set_level(into.level)
			into.pop()
	)


static func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
