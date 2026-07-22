extends SceneTree

const GAME_ROOT_SCENE := preload("res://scenes/app/game_root.tscn")
const COMBAT_SCENE := preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/app/game_root.tscn":
		_fail("GameRoot is not configured as the main scene")
		return
	var app := GAME_ROOT_SCENE.instantiate() as GameRoot
	root.add_child(app)
	await process_frame
	if app == null or not app.active_scene is MainMenu or app.current_scene_container.get_child_count() != 1:
		_fail("Application shell did not start in MainMenu")
		return
	root.remove_child(app)
	app.queue_free()

	var game := COMBAT_SCENE.instantiate() as GameMain
	if game == null:
		_fail("Main scene did not instantiate as GameMain")
		return
	root.add_child(game)
	for _frame in 5:
		await physics_frame
	if game.player == null or game.location == null or game.wave_manager == null or game.ui == null:
		_fail("Main scene did not initialize its runtime systems")
		return
	if game.world_state == null or game.location.generated_props.is_empty():
		_fail("World runtime failed to initialize")
		return
	print("SMOKE TEST PASS")
	quit()
