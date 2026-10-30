extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	var samples: Array[float] = []
	for frame in 900:
		var start := Time.get_ticks_usec()
		game.player.position.x += 8
		game.player.position.y = game.world.surface(int(game.player.position.x/16))*16-2
		game._physics_process(1.0/60)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
		if frame % 60 == 0: await process_frame
	samples.sort()
	print("BENCHMARK headless scripted traversal frames=900 mean_ms=%.3f p95_ms=%.3f max_ms=%.3f chunks=%d RAM_MB=%.2f" % [samples.reduce(func(a,b):return a+b,0.0)/samples.size(),samples[855],samples[-1],game.views.size(),OS.get_static_memory_usage()/1048576.0])
	for size in [Vector2i(960,540),Vector2i(1170,540),Vector2i(1200,540)]:
		root.size = size
		game.layout_ui()
		for key in game.zones:
			var rect: Rect2 = game.zones[key].get_global_rect()
			assert(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= size.x and rect.end.y <= size.y,"Control outside viewport")
	print("LAYOUT: 16:9, 19.5:9, 20:9 bounds passed")
	game.queue_free()
	await process_frame
	quit()
