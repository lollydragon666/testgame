extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var shape := AttackShape.new()
	shape.configure(Vector2.ZERO, Vector2.RIGHT, 20.0, 100.0, 5.0)
	_require(shape.intersects_swept_circle(Vector2(70.0, 0.0), 8.0, -0.15, 0.15), "World-space shape missed a forward target")
	_require(not shape.intersects_swept_circle(Vector2(0.0, 70.0), 8.0, -0.15, 0.15), "World-space shape used screen-space direction")
	shape.configure(Vector2.ZERO, Vector2.UP, 20.0, 100.0, 5.0)
	_require(shape.intersects_swept_circle(Vector2(0.0, -70.0), 8.0, -0.15, 0.15), "Rotated world-space shape missed its target")

	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.world_position = Vector2.ZERO
	player.attack.swing_aim_direction = Vector2.RIGHT
	player.attack.attack_reach = 91.0
	player.attack.visual_sword_length = 500.0
	_require(player.attack.point_in_blade_sweep(Vector2(75.0, 0.0), 5.0, -0.1, 0.1), "PlayerAttack did not use world-space AttackShape")
	_require(not player.attack.point_in_blade_sweep(Vector2(120.0, 0.0), 5.0, -0.1, 0.1), "Visual sword length affected combat reach")
	player.visual_radius = 200.0
	_require(not player.attack.point_in_blade_sweep(Vector2(120.0, 0.0), 5.0, -0.1, 0.1), "Visual body size affected combat geometry")

	print("WORLD-SPACE COMBAT PASS")
	quit()
