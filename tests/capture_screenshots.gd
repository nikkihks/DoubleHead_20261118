extends SceneTree

## Automatisierter Screenshot-Capture fuer Phase 6 (`subagent-critic` Loop).
## Rendert alle 5 Hauptansichten und speichert PNGs nach `.scratch/screenshots/`.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/Main.tscn") as PackedScene
	if scene == null:
		push_error("Main.tscn konnte nicht geladen werden")
		quit(1)
		return

	var main_node := scene.instantiate()
	root.add_child(main_node)
	await _settle(6)

	var modes := ["menu", "table", "rules", "lobby", "schreibblock"]
	for m in modes:
		main_node.show_preview(m)
		await _settle(8)
		var img := root.get_texture().get_image()
		var out_path := ".scratch/screenshots/%s.png" % m
		img.save_png(out_path)
		print("CAPTURED: ", out_path)

	quit(0)


func _settle(frames: int) -> void:
	for _i in range(frames):
		await process_frame
