class_name ChunkView
extends Node2D
var world: WorldData
var coord: Vector2i
func setup(data: WorldData, location: Vector2i):
	world = data
	coord = location
	position = Vector2(coord * WorldData.CHUNK * WorldData.TILE)
func _draw():
	for y in WorldData.CHUNK:
		for x in WorldData.CHUNK:
			var cell := coord * WorldData.CHUNK + Vector2i(x,y)
			var id := world.block(cell)
			if id == 0: continue
			var rect := Rect2(x * 16, y * 16, 16, 16)
			var shade := 0.92 + float(posmod(cell.x * 37 + cell.y * 17, 9)) * 0.014
			draw_rect(rect, Blocks.COLORS[id] * shade)
			draw_rect(Rect2(rect.position + Vector2(3, 5), Vector2(3, 2)), Blocks.COLORS[id].lightened(0.13))
			if id == 1 and world.block(cell + Vector2i.UP) == 0:
				draw_rect(Rect2(rect.position, Vector2(16, 3)), Color("67ad83"))
