extends SceneTree
var failures := 0
func check(condition: bool, label: String):
	if not condition:
		failures += 1
		push_error(label)
func _initialize():
	call_deferred("run")
func run():
	var start := Time.get_ticks_usec()
	var world := WorldData.new(12345)
	var same := WorldData.new(12345)
	var other := WorldData.new(54321)
	var differences := 0
	for y in range(-20,100):
		for x in range(-70,70):
			check(world.block(Vector2i(x,y)) == same.block(Vector2i(x,y)), "Seed reproducibility")
			if world.block(Vector2i(x,y)) != other.block(Vector2i(x,y)): differences += 1
	check(differences > 100, "Different seeds must differ")
	check(world.chunk_of(Vector2i(-1,-25)) == Vector2i(-1,-2), "Negative chunk coordinates")
	var cell := Vector2i(-1,50)
	world.load_chunk(world.chunk_of(cell))
	world.set_block(cell,3)
	check(world.block(cell) == 3,"Cached edit")
	world.chunks.clear()
	check(world.block(cell) == 3,"Unloaded edit retained")
	world.load_chunk(world.chunk_of(cell))
	check(world.block(cell) == 3,"Reloaded edit retained")
	var inventory := Inventory.new()
	check(not inventory.take(4),"Cannot consume missing item")
	check(not inventory.add(1,1000),"Stack overflow rejected")
	check(not inventory.add(-1),"Bad ID rejected")
	check(inventory.add(2) and inventory.take(2) and inventory.amounts[2] == 0,"Inventory transaction")
	check(not inventory.restore([0,1,-1,0,0]),"Invalid inventory rejected")
	var store := SaveStore.new("user://test.save")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(store.path+suffix): DirAccess.remove_absolute(store.path+suffix)
	var data := {"seed":12345,"edits":world.edits,"inventory":inventory.amounts,"position":[128,200]}
	check(store.write(data) == OK,"Atomic save")
	var restored := store.read()
	check(restored.get("edits",{}).get("-1,50") == 3,"Saved edit restored")
	check(int(restored.position[0]) == 128 and int(restored.position[1]) == 200,"Position restored")
	check(store.write(data) == OK,"Backup save")
	var file := FileAccess.open(store.path,FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	check(not store.read().is_empty(),"Backup recovery")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var player: FrontierPlayer = game.player
	player.set_physics_process(false)
	player.position = Vector2(128, game.world.surface(8)*16-2)
	for i in 120: player._physics_process(1.0/60)
	check(player.grounded,"Ground collision")
	var before := player.position
	player.jump_requested = true
	player._physics_process(1.0/60)
	check(player.position.y < before.y,"Jump")
	player.move_axis = 1
	for i in 12: player._physics_process(1.0/60)
	check(player.position.x > before.x,"Horizontal movement")
	# Exercise the actual command path used by mouse/touch controls.
	player.position = Vector2(128,game.world.surface(8)*16-2)
	var dig := Vector2i(9,game.world.surface(8))
	game.world.set_block(dig,1)
	game.aim_position = game.get_viewport().get_canvas_transform() * (Vector2(dig)*16+Vector2(8,8))
	game.use_touch_aim = true
	game.touch_actions[7] = "mine"
	var old_count: int = game.inventory.amounts[1]
	for i in 30: game._physics_process(1.0/60)
	check(game.world.block(dig) == 0,"Mining via command path")
	check(game.inventory.amounts[1] == old_count+1,"Mining updates inventory")
	game.touch_actions.clear()
	game.inventory.selected = 1
	game.touch_actions[7] = "place"
	game._physics_process(1.0/60)
	check(game.world.block(dig) == 1,"Placement via command path")
	check(game.inventory.amounts[1] == old_count,"Placement consumes inventory")
	game.touch_actions.clear()
	# Touch joystick and jump use real InputEventScreenTouch events.
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = game.joystick.global_position + game.joystick.size/2 + Vector2(40,0)
	game.joystick._input(touch)
	check(game.joystick.axis.x > 0.5,"Touch joystick")
	touch.pressed = false
	game.joystick._input(touch)
	check(game.joystick.axis == Vector2.ZERO,"Joystick release")
	touch.pressed = true
	touch.position = game.zones.jump.position + Vector2(20,20)
	game._input(touch)
	check(player.jump_requested,"Touch jump")
	game.store = SaveStore.new("user://integration.save")
	game.save_game()
	var reloaded: Dictionary = game.store.read()
	check(reloaded.inventory.size() == 5 and int(reloaded.inventory[1]) == game.inventory.amounts[1],"Integrated inventory persistence")
	var regenerated := WorldData.new(int(reloaded.seed))
	regenerated.edits = reloaded.edits
	check(regenerated.block(dig) == 1,"Integrated world persistence")
	var old_coord: Vector2i = game.world.chunk_of(Vector2i((player.position/16).floor()))
	player.position.x += 16000
	game.stream_chunks()
	check(not game.views.has(old_coord),"Far chunk eviction")
	game.queue_free()
	await process_frame
	print("TESTS: failures=%d duration_ms=%.2f" % [failures,(Time.get_ticks_usec()-start)/1000.0])
	quit(1 if failures else 0)
