extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameMain
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

