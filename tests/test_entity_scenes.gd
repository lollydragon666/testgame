extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemies/brawler_enemy.tscn"),
	preload("res://scenes/enemies/melee_enemy.tscn"),
	preload("res://scenes/enemies/shooter_enemy.tscn"),
	preload("res://scenes/enemies/lancer_enemy.tscn"),
	preload("res://scenes/enemies/lightning_mage.tscn"),
	preload("res://scenes/enemies/fire_mage.tscn"),
	preload("res://scenes/enemies/boss_enemy.tscn"),
]

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _hurtbox_radius(hurtbox: EntityHurtbox) -> float:
	var circle := hurtbox.collision_shape.shape as CircleShape2D
	_require(circle != null, "Hurtbox does not contain CircleShape2D")
	return circle.radius

func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	_require(player.movement == (player.get_node("Movement") as PlayerMovement), "Movement is not scene-owned")
	_require(player.attack == (player.get_node("Attack") as PlayerAttack), "Attack is not scene-owned")
	_require(player.magic == (player.get_node("Magic") as PlayerMagic), "Magic is not scene-owned")
	_require(player.get_node("Camera") is Camera2D, "Camera is missing from player scene")
	_require(player.visual_root == (player.get_node("VisualRoot") as PlayerVisual), "Player VisualRoot is missing")
	_require(player.hurtbox == (player.get_node("Hurtbox") as EntityHurtbox), "Player Hurtbox is missing")
	_require(is_equal_approx(_hurtbox_radius(player.hurtbox), player.collision_radius), "Player Hurtbox radius is not synchronized")
	var original_collision_radius := player.collision_radius
	player.visual_radius += 10.0
	_require(is_equal_approx(player.collision_radius, original_collision_radius), "Visual size changed player collision radius")
	_require(is_equal_approx(_hurtbox_radius(player.hurtbox), original_collision_radius), "Visual size changed player Hurtbox")
	player.upgrade_vitality()
	_require(is_equal_approx(_hurtbox_radius(player.hurtbox), player.collision_radius), "Vitality did not resize player Hurtbox")

	for index in ENEMY_SCENES.size():
		var enemy := ENEMY_SCENES[index].instantiate() as EnemyBase
		enemy.setup(player, Vector2(float(index) * 90.0, 0.0), 1.0, CONFIG)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		_require(enemy.visual_root == (enemy.get_node("VisualRoot") as EnemyVisual), "Enemy VisualRoot is missing")
		_require(enemy.hurtbox == (enemy.get_node("Hurtbox") as EntityHurtbox), "Enemy Hurtbox is missing")
		_require(is_equal_approx(_hurtbox_radius(enemy.hurtbox), enemy.collision_radius), "Enemy Hurtbox radius is not synchronized")
		enemy.refresh_visual()

	await process_frame
	print("ENTITY SCENES PASS")
	quit()
