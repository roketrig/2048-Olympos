class_name Board
extends Control

signal score_gained(points: int)
signal merged(tile: Tile)

const SIZE := 4
const GAP := 4.0
const MOVE_TIME := 0.1
const MAX_LEVEL := 12 # 8192: the last tile, it never merges or grows

var cell_size := 0.0
var cells: Array = [] # cells[y][x] -> Tile or null
var merge_levels: Array[int] = [] # levels created by the last move


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(board_size: float) -> void:
	custom_minimum_size = Vector2(board_size, board_size)
	size = custom_minimum_size
	cell_size = floorf((board_size - GAP * (SIZE + 1)) / SIZE)
	clear()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
	draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Palette.BOARD)
	draw_rect(Rect2(1, 1, size.x - 2, 1), Palette.BOARD.lightened(0.15))

	for y in SIZE:
		for x in SIZE:
			var p := cell_position(Vector2i(x, y))
			draw_rect(Rect2(p, Vector2(cell_size, cell_size)), Palette.CELL)
			draw_rect(Rect2(p, Vector2(cell_size, 1)), Palette.INK) # inset shadow


func clear() -> void:
	for tile in tiles():
		tile.queue_free()

	cells.clear()
	for y in SIZE:
		var row := []
		row.resize(SIZE)
		cells.append(row)


func cell_position(p: Vector2i) -> Vector2:
	var offset := floorf((size.x - (cell_size * SIZE + GAP * (SIZE - 1))) / 2.0)
	return Vector2(offset + p.x * (cell_size + GAP), offset + p.y * (cell_size + GAP))


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

	return place_tile(empty.pick_random(), 0)


func place_tile(p: Vector2i, level: int) -> Tile:
	var tile := Tile.new()
	tile.resize(cell_size)
	tile.set_level(level)
	tile.grid_pos = p
	tile.position = cell_position(p)
	add_child(tile)
	cells[p.y][p.x] = tile
	tile.appear()
	return tile


# Takes a tile off the board with a shrink animation.
func remove_tile(tile: Tile) -> void:
	cells[tile.grid_pos.y][tile.grid_pos.x] = null
	tile.vanish()


# Grid cell under a point in board-local coordinates, or (-1, -1).
func cell_at(local: Vector2) -> Vector2i:
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			if Rect2(cell_position(p), Vector2(cell_size, cell_size)).has_point(local):
				return p
	return Vector2i(-1, -1)


func unlock_all() -> void:
	for tile in tiles():
		tile.locked = false


# Slides every tile toward `dir`. Returns true if anything moved.
func move(dir: Vector2i) -> bool:
	var xs := range(SIZE)
	var ys := range(SIZE)
	if dir.x > 0:
		xs.reverse()
	if dir.y > 0:
		ys.reverse()

	var changed := false
	merge_levels.clear()

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
				merge_into(tile, other)
				changed = true
			elif target != tile.grid_pos:
				_slide(tile, target)
				changed = true

	unlock_all()
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
	tile.pop(1.35, 0.3)
	score_gained.emit(tile.value() - old_value)


# Lowers a tile by `steps` levels (each step halves it). Used by Chaos.
func downgrade(tile: Tile, steps: int) -> void:
	tile.set_level(maxi(tile.level - steps, 0))
	tile.pop(0.7, 0.3)


func empty_cells() -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if cells[y][x] == null:
				empty.append(Vector2i(x, y))
	return empty


func _slide(tile: Tile, target: Vector2i) -> void:
	cells[tile.grid_pos.y][tile.grid_pos.x] = null
	cells[target.y][target.x] = tile
	tile.grid_pos = target
	tile.create_tween().tween_property(tile, "position", cell_position(target), MOVE_TIME)


func merge_into(tile: Tile, into: Tile) -> void:
	cells[tile.grid_pos.y][tile.grid_pos.x] = null
	into.locked = true

	var new_level := into.level + 1
	into.level = new_level
	merge_levels.append(new_level)
	score_gained.emit(Tile.value_of(new_level))

	move_child(tile, into.get_index()) # slide underneath the tile it merges into
	var tween := tile.create_tween()
	tween.tween_property(tile, "position", cell_position(into.grid_pos), MOVE_TIME)
	tween.finished.connect(func() -> void:
		tile.queue_free()
		if is_instance_valid(into):
			into.set_level(into.level)
			into.pop()
			merged.emit(into)
	)
