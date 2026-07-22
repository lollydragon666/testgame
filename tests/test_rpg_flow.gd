extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const EXPEDITION_SCENE := preload("res://scenes/expeditions/expedition.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_require(session != null, "GameSession autoload is missing")
	session.reset_profile_for_tests()
	_require(session.profile.gold == 0, "New profile did not start with zero gold")
	_require(session.profile.is_location_unlocked(&"test_location"), "test_location is not unlocked by default")

	var victory := ExpeditionResult.create(true, &"test_location", 7, 20, 90.0)
	_require(session.claim_expedition_result(victory), "Victory reward was not claimed")
	_require(session.profile.gold == 100, "Victory did not grant 100 gold")
	_require(not session.claim_expedition_result(victory), "Expedition reward was claimed twice")
	_require(session.profile.gold == 100, "Repeated result changed gold")

	session.reset_profile_for_tests()
	var defeat := ExpeditionResult.create(false, &"test_location", 2, 3, 20.0)
	_require(session.claim_expedition_result(defeat), "Defeat reward was not claimed")
	_require(session.profile.gold == 20, "Defeat did not grant 20 gold")
	_require(not session.purchase_health_upgrade(), "Health upgrade succeeded without enough gold")

	session.profile.gold = 50
	_require(session.purchase_health_upgrade(), "Health upgrade purchase failed")
	_require(session.profile.gold == 0, "Health purchase produced incorrect gold")
	_require(is_equal_approx(session.profile.permanent_max_health_bonus, 10.0), "Health purchase produced incorrect bonus")

	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.reset_run()
	player.apply_profile_bonuses(session.profile.permanent_max_health_bonus, 0.25)
	_require(is_equal_approx(player.max_health, 110.0), "Permanent health bonus was not applied to combat player")
	_require(is_equal_approx(player.profile_damage_multiplier, 1.25), "Profile damage multiplier was not separated from POWER")
	player.upgrade_power()
	_require(is_equal_approx(session.profile.permanent_damage_bonus, 0.0), "Run POWER leaked into PlayerProfile")

	session.profile.permanent_damage_bonus = 0.25
	var expedition := EXPEDITION_SCENE.instantiate() as ExpeditionController
	root.add_child(expedition)
	for _frame in 3:
		await physics_frame
	_require(is_equal_approx(expedition.combat.player.max_health, 110.0), "Expedition did not apply permanent health")
	_require(is_equal_approx(expedition.combat.player.profile_damage_multiplier, 1.25), "Expedition did not apply permanent damage separately")
	expedition.before_scene_exit()

	print("RPG FLOW PASS")
	quit()
