extends Node2D
var world: WorldData
var inventory := Inventory.new()
var store := SaveStore.new()
var player := FrontierPlayer.new()
var camera := Camera2D.new()
var views: Dictionary = {}
var hud := CanvasLayer.new()
var status := Label.new()
var notice := Label.new()
var hotbar: Array[Button] = []
var touch_actions: Dictionary = {}
var zones: Dictionary = {}
var target := Vector2i.ZERO
var mining := 0.0
var last_target := Vector2i.ZERO
var save_timer := 0.0
var stream_timer := 0.0
var mine_held := false
var place_held := false
var action_timer := 0.0
var aim_touch := -1
var aim_position := Vector2.ZERO
var use_touch_aim := false
var low_power := false
var joystick := FrontierJoystick.new()

func _ready():
	RenderingServer.set_default_clear_color(Color("192d49"))
	var data := store.read()
	var initial_seed := 71342
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed=") and arg.trim_prefix("--seed=").is_valid_int(): initial_seed = int(arg.trim_prefix("--seed="))
	world = WorldData.new(int(data.get("seed", initial_seed)))
	world.edits = data.get("edits", {})
	inventory.restore(data.get("inventory", [0,30,0,0,0]))
	player.world = world
	player.position = Vector2(8 * 16, world.surface(8) * 16 - 2)
	if data.has("position"): player.position = Vector2(data.position[0], data.position[1])
	if player.collides(player.position): player.position = Vector2(128, world.surface(8) * 16 - 2)
	add_child(player)
	add_child(camera)
	camera.zoom = Vector2(2,2)
	camera.position = player.position - Vector2(0,50)
	add_child(hud)
	build_ui()
	stream_chunks()
	inventory.changed.connect(update_hotbar)
	update_hotbar()
	get_tree().auto_accept_quit = false

func button(text_value: String, action: String) -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(0.8, 1, 1, 0.85)
	hud.add_child(b)
	zones[action] = b
	return b

func build_ui():
	status.position = Vector2(20,12)
	hud.add_child(status)
	notice.position = Vector2(20,40)
	notice.text = "ASTRAL FRONTIER • Crash site | Mine, build, explore"
	hud.add_child(notice)
	for id in range(1,5):
		var b := button("", "slot%d" % id)
		b.pressed.connect(func(): inventory.selected = id; update_hotbar())
		hotbar.append(b)
	button("SAVE", "save").pressed.connect(save_game)
	button("60 / 30", "fps").pressed.connect(func(): low_power = not low_power; Engine.max_fps = 30 if low_power else 60)
	button("− / +", "zoom").pressed.connect(func(): camera.zoom = Vector2.ONE * (1.5 if camera.zoom.x == 2 else 2))
	hud.add_child(joystick)
	joystick.size = Vector2(144,144)
	button("JUMP", "jump")
	button("MINE", "mine")
	button("BUILD", "place")
	get_viewport().size_changed.connect(layout_ui)
	layout_ui()

func layout_ui():
	var size := get_viewport_rect().size
	var inset := Vector2(20,20)
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		if screen.x > 0 and screen.y > 0:
			inset.x = maxf(20, maxf(safe.position.x, screen.x - safe.end.x) * size.x / screen.x)
			inset.y = maxf(20, maxf(safe.position.y, screen.y - safe.end.y) * size.y / screen.y)
	status.position = inset
	notice.position = inset + Vector2(0,26)
	for i in 4:
		hotbar[i].position = Vector2(inset.x + i * 114, inset.y + 55)
		hotbar[i].size = Vector2(108,48)
	joystick.position = Vector2(inset.x,size.y-inset.y-144)
	for pair in [["jump",Vector2(size.x-inset.x-90,size.y-inset.y-180)], ["mine",Vector2(size.x-inset.x-190,size.y-inset.y-80)], ["place",Vector2(size.x-inset.x-90,size.y-inset.y-80)]]:
		zones[pair[0]].position = pair[1]
		zones[pair[0]].size = Vector2(80,72)
	for i in 3:
		var b: Button = zones[["save","fps","zoom"][i]]
		b.position = Vector2(size.x-inset.x-100, inset.y+i*45)
		b.size = Vector2(100,40)

func update_hotbar():
	for i in 4:
		hotbar[i].text = "%s%s\n%d" % ["• " if inventory.selected == i+1 else "", Blocks.NAMES[i+1], inventory.amounts[i+1]]

func touch_action(pos: Vector2) -> String:
	if joystick.get_global_rect().has_point(pos): return "joystick"
	for key in zones:
		if zones[key].get_global_rect().has_point(pos): return key
	return "aim"

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			var action := touch_action(event.position)
			touch_actions[event.index] = action
			if action == "jump": player.jump_requested = true
			if action == "aim":
				aim_touch = event.index
				aim_position = event.position
				use_touch_aim = true
		else:
			touch_actions.erase(event.index)
			if event.index == aim_touch: aim_touch = -1
	if event is InputEventScreenDrag and event.index == aim_touch: aim_position = event.position
	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): use_touch_aim = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: player.jump_requested = true
		if event.keycode == KEY_F5: save_game()
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			inventory.selected = event.keycode - KEY_1 + 1
			update_hotbar()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A: player.jump_requested = true

func active(action: String) -> bool:
	return touch_actions.values().has(action) or (zones.has(action) and zones[action].is_pressed())

func _physics_process(delta):
	player.move_axis = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) ) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) )
	if joystick.finger != -1: player.move_axis = joystick.axis.x
	if Input.get_connected_joypads().size() > 0:
		var axis := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		if absf(axis) > 0.2: player.move_axis = axis
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.25:
			aim_position = get_viewport().get_canvas_transform() * (player.position + stick.normalized() * 56 - Vector2(0,12))
			use_touch_aim = true
	camera.position = camera.position.lerp(player.position - Vector2(0,50), 1-exp(-delta*10))
	var point := get_global_mouse_position()
	if active("mine") or active("place"):
		if not use_touch_aim: point = player.position + Vector2(player.facing * 40, -12)
	if use_touch_aim: point = get_viewport().get_canvas_transform().affine_inverse() * aim_position
	target = Vector2i((point / 16).floor())
	if target != last_target: mining = 0
	last_target = target
	var mouse_over_ui := touch_action(get_viewport().get_mouse_position()) != "aim"
	mine_held = active("mine") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not mouse_over_ui) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	place_held = active("place") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not mouse_over_ui) or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	action_timer -= delta
	if in_reach():
		var id := world.block(target)
		if mine_held and id != 0:
			mining += delta
			if mining >= Blocks.HARDNESS[id] and inventory.add(id):
				change_block(target,0)
				mining = 0
		else: mining = 0
		if place_held and action_timer <= 0 and id == 0:
			var rect := Rect2(Vector2(target)*16, Vector2(16,16))
			var adjacent := false
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if world.block(target+offset) != 0: adjacent = true
			if adjacent and not rect.intersects(player.bounds(player.position)) and inventory.take(inventory.selected):
				change_block(target,inventory.selected)
				action_timer = 0.2
	else: mining = 0
	stream_timer += delta
	if stream_timer > 0.1:
		stream_chunks()
		stream_timer = 0
	save_timer += delta
	if save_timer > 20: save_game()
	status.text = "Seed %d   |   %d FPS   |   Chunks %d   |   RAM %.1f MB" % [world.world_seed,Engine.get_frames_per_second(),views.size(),OS.get_static_memory_usage()/1048576.0]
	queue_redraw()

func in_reach() -> bool:
	return (Vector2(target)*16+Vector2(8,8)).distance_to(player.position-Vector2(0,14)) < 80

func change_block(cell: Vector2i, id: int):
	world.set_block(cell,id)
	for offset in [Vector2i.ZERO,Vector2i.DOWN]:
		var coord := world.chunk_of(cell+offset)
		if views.has(coord): views[coord].queue_redraw()

func stream_chunks():
	var center := world.chunk_of(Vector2i((player.position/16).floor()))
	var radius := Vector2i(ceili(get_viewport_rect().size.x/camera.zoom.x/768)+1, ceili(get_viewport_rect().size.y/camera.zoom.y/768)+1)
	var required: Dictionary = {}
	# At most two new chunks per update to bound generation work.
	var budget := 2
	if not views.has(center):
		world.load_chunk(center)
		var initial := ChunkView.new()
		initial.setup(world,center)
		initial.z_index = -1
		add_child(initial)
		views[center] = initial
		budget -= 1
	for y in range(center.y-radius.y,center.y+radius.y+1):
		for x in range(center.x-radius.x,center.x+radius.x+1):
			var coord := Vector2i(x,y)
			required[coord] = true
			if not views.has(coord) and budget > 0:
				world.load_chunk(coord)
				var view := ChunkView.new()
				view.setup(world,coord)
				view.z_index = -1
				add_child(view)
				views[coord] = view
				budget -= 1
	for coord in views.keys():
		if not required.has(coord):
			views[coord].queue_free()
			views.erase(coord)
			world.chunks.erase(coord)

func _draw():
	if in_reach():
		var rect := Rect2(Vector2(target)*16,Vector2(16,16))
		draw_rect(rect,Color("83f3d0"),false,1)
		if mining > 0:
			draw_rect(Rect2(rect.position-Vector2(0,4),Vector2(16*minf(1,mining/maxf(0.01,Blocks.HARDNESS[world.block(target)])),2)),Color.WHITE)

func save_game():
	var error := store.write({"seed":world.world_seed,"edits":world.edits,"inventory":inventory.amounts,"position":[player.position.x,player.position.y]})
	notice.text = "Saved • local world and explorer" if error == OK else "SAVE FAILED: %s" % error_string(error)
	save_timer = 0

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED: save_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
