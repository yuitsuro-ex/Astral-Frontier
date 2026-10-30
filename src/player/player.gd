class_name FrontierPlayer
extends Node2D
var world: WorldData
var velocity := Vector2.ZERO
var move_axis := 0.0
var jump_requested := false
var grounded := false
var facing := 1.0
var walk_time := 0.0
const SIZE = Vector2(11, 27)
func bounds(at: Vector2) -> Rect2:
	return Rect2(at - Vector2(SIZE.x / 2, SIZE.y), SIZE)
func collides(at: Vector2) -> bool:
	var box := bounds(at)
	var first := Vector2i((box.position / 16).floor())
	var last := Vector2i(((box.end - Vector2(0.01, 0.01)) / 16).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if world.block(Vector2i(x, y)) != 0: return true
	return false
func _physics_process(delta: float):
	velocity.x = move_toward(velocity.x, move_axis * 115, 850 * delta)
	if move_axis != 0: facing = sign(move_axis)
	if jump_requested and grounded: velocity.y = -280
	jump_requested = false
	velocity.y = minf(velocity.y + 760 * delta, 460)
	grounded = false
	# Substeps prevent tunnelling through a tile during a slow frame.
	var motion := velocity * delta
	var steps := maxi(1, ceili(motion.length() / 4))
	for i in steps:
		var next := position + Vector2(motion.x / steps, 0)
		if not collides(next): position = next
		else: velocity.x = 0
		next = position + Vector2(0, motion.y / steps)
		if not collides(next): position = next
		else:
			if motion.y > 0: grounded = true
			velocity.y = 0
	walk_time += delta * absf(velocity.x) * 0.1
	queue_redraw()
func _draw():
	var stride := sin(walk_time) * 3 if grounded else 2.0
	draw_rect(Rect2(-6, -18, 12, 12), Color("427f9b"))
	draw_rect(Rect2(-5, -27, 10, 10), Color("e5bba0"))
	draw_rect(Rect2(-6, -28, 12, 5), Color("22334e"))
	draw_rect(Rect2(-4 + facing * 3, -23, 5, 3), Color("7aeee4"))
	draw_rect(Rect2(-5, -7, 4, 7 + stride), Color("263c56"))
	draw_rect(Rect2(1, -7, 4, 7 - stride), Color("263c56"))
	draw_rect(Rect2(-9, -17, 4, 10), Color("dcb59b"))
