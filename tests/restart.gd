extends SceneTree
func _initialize():
	var store := SaveStore.new("user://restart.save")
	if OS.get_cmdline_user_args().has("--write"):
		var world := WorldData.new(98765)
		world.set_block(Vector2i(-25,40),3)
		assert(store.write({"seed":98765,"edits":world.edits,"inventory":[0,17,9,2,1],"position":[124.5,212.75]}) == OK)
		print("RESTART: write complete")
	else:
		var data := store.read()
		assert(not data.is_empty())
		var world := WorldData.new(int(data.seed))
		world.edits = data.edits
		assert(world.block(Vector2i(-25,40)) == 3)
		assert(int(data.inventory[1]) == 17 and float(data.position[0]) == 124.5)
		print("RESTART: separate process restored world, inventory and position")
	quit()
