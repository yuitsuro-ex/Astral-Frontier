class_name WorldData
extends RefCounted
const CHUNK = 24
const TILE = 16
const MIN_Y = -64
const MAX_Y = 191
var world_seed: int
var terrain := FastNoiseLite.new()
var caves := FastNoiseLite.new()
var chunks: Dictionary = {}
var edits: Dictionary = {}
func _init(value: int = 71342):
	world_seed = value
	terrain.seed = value
	terrain.frequency = 0.018
	caves.seed = value + 271
	caves.frequency = 0.065
func surface(x: int) -> int:
	return 22 + int(terrain.get_noise_1d(x) * 17)
func generated(cell: Vector2i) -> int:
	if cell.y < surface(cell.x): return 0
	if cell.y >= MAX_Y: return 2
	if cell.y > surface(cell.x) + 5 and caves.get_noise_2d(cell.x, cell.y) > 0.24: return 0
	if cell.y < surface(cell.x) + 4: return 1
	if caves.get_noise_2d(cell.x + 4200, cell.y) > 0.5: return 4
	return 2
func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))
func load_chunk(coord: Vector2i) -> void:
	if chunks.has(coord): return
	var data := PackedByteArray()
	data.resize(CHUNK * CHUNK)
	for y in CHUNK:
		for x in CHUNK:
			var cell := coord * CHUNK + Vector2i(x, y)
			data[y * CHUNK + x] = edits.get(key(cell), generated(cell))
	chunks[coord] = data
func block(cell: Vector2i) -> int:
	if cell.y < MIN_Y: return 0
	if cell.y >= MAX_Y: return 2
	var coord := chunk_of(cell)
	if not chunks.has(coord): return edits.get(key(cell), generated(cell))
	var local := cell - coord * CHUNK
	return chunks[coord][local.y * CHUNK + local.x]
func set_block(cell: Vector2i, id: int) -> bool:
	if cell.y < MIN_Y or cell.y >= MAX_Y or id < 0 or id > 4: return false
	if id == generated(cell): edits.erase(key(cell))
	else: edits[key(cell)] = id
	var coord := chunk_of(cell)
	if chunks.has(coord):
		var local := cell - coord * CHUNK
		chunks[coord][local.y * CHUNK + local.x] = id
	return true
