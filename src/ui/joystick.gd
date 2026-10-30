class_name FrontierJoystick
extends Control
var finger := -1
var axis := Vector2.ZERO
var knob := Vector2.ZERO
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index
			update_axis(event.position)
		elif not event.pressed and event.index == finger:
			finger = -1
			axis = Vector2.ZERO
			knob = Vector2.ZERO
			queue_redraw()
	if event is InputEventScreenDrag and event.index == finger: update_axis(event.position)
func update_axis(point: Vector2):
	knob = (point - global_position - size / 2).limit_length(48)
	axis = knob / 48
	if axis.length() < 0.15: axis = Vector2.ZERO
	queue_redraw()
func _draw():
	draw_circle(size/2, 64, Color(0.2,0.6,0.7,0.2))
	draw_arc(size/2,64,0,TAU,48,Color(0.5,0.9,1,0.5),2)
	draw_circle(size/2+knob,25,Color(0.5,0.9,1,0.6))
