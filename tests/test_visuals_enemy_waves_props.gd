extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_VISUAL: CharacterVisualDefinition = preload("res://resources/content/visuals/player.tres")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	_test_character_visuals()
	_test_sword_models()
	_test_enemy_definitions()
	_test_waves_and_groups()
	await _test_world_props()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("VISUALS ENEMY WAVES AND PROPS PASS")
	quit()

func _test_character_visuals() -> void:
	var ids: Dictionary[StringName, bool] = {}
	var profiles: Array[CharacterVisualDefinition] = [PLAYER_VISUAL]
	for enemy_id in _enemy_ids():
		profiles.append(CONTENT.enemy(enemy_id).visual_definition)
	for profile in profiles:
		_check(profile != null and profile.is_valid_definition(), "Invalid character visual profile")
		if profile == null:
			continue
		_check(not ids.has(profile.id), "Duplicate character visual ID: %s" % profile.id)
		ids[profile.id] = true
	var fallback := CharacterVisualDefinition.new()
	fallback.id = &"fallback_test"
	fallback.body_style = &"unknown"
	fallback.head_style = &"unknown"
	fallback.helmet_style = &"unknown"
	_check(fallback.resolved_body_style() == &"medium", "Unknown body style has no fallback")
	_check(fallback.resolved_head_style() == &"human", "Unknown head style has no fallback")
	_check(fallback.resolved_helmet_style() == &"none", "Unknown helmet style has no fallback")
	var visual := CharacterVisual.new()
	visual.apply_visual_definition(PLAYER_VISUAL)
	root.add_child(visual)
	_check(visual.get_node_or_null("GroundShadow") != null, "Character has no GroundShadow")
	_check(visual.get_node_or_null("MirroredVisualRoot/Body") != null, "Character has no Body")
	_check(visual.get_node_or_null("MirroredVisualRoot/Head") != null, "Character has no Head")
	_check(visual.get_node_or_null("MirroredVisualRoot/Helmet") != null, "Character has no Helmet")
	_check(visual.get_node_or_null("MirroredVisualRoot/WeaponSocket/WeaponVisual") != null, "Character has no WeaponVisual")
	visual.queue_free()

func _test_sword_models() -> void:
	var weapons: Array[WeaponDefinition] = []
	for item in CONTENT.all_items():
		if item is WeaponDefinition:
			weapons.append(item as WeaponDefinition)
	_check(weapons.size() == 15, "Expected 15 existing swords")
	var styles: Dictionary[StringName, bool] = {}
	for weapon in weapons:
		var original_id := weapon.id
		var style := PlayerSwordVisual.resolved_style(weapon)
		_check(PlayerSwordVisual.SUPPORTED_STYLES.has(style), "Unsupported sword style: %s" % style)
		_check(not styles.has(style), "Sword model is not visually distinct: %s" % style)
		styles[style] = true
		var profile := PlayerSwordVisual.sword_profile(style)
		_check(profile.has("length_scale") and profile.has("guard") and profile.has("tip"), "Incomplete sword profile: %s" % style)
		_check(weapon.id == original_id, "Sword profile changed weapon ID")
	_check(PlayerSwordVisual.sword_profile(&"missing") == PlayerSwordVisual.sword_profile(&"gladius"), "Unknown sword style has no fallback")

func _test_enemy_definitions() -> void:
	var first_waves := [1, 2, 3, 4, 5, 6, 8, 10, 12, 14]
	var seen: Dictionary[StringName, bool] = {}
	for index in _enemy_ids().size():
		var enemy_id := _enemy_ids()[index]
		var definition := CONTENT.enemy(enemy_id)
		_check(definition != null and definition.is_valid_definition(), "Invalid enemy definition: %s" % enemy_id)
		if definition == null:
			continue
		_check(not seen.has(definition.id), "Duplicate enemy ID: %s" % definition.id)
		seen[definition.id] = true
		_check(definition.introduced_wave == first_waves[index], "Wrong introduction wave: %s" % enemy_id)
	var minion := CONTENT.enemy(GameIds.ENEMY_SUMMONED_MINION)
	_check(minion != null and not minion.grants_loot and not minion.grants_experience, "Summoned minion grants run rewards")
	var attack := EnemyAttackController.new()
	attack.configure(CONTENT.enemy(GameIds.ENEMY_BRUTE))
	_check(attack.try_start() and not attack.tick(0.1), "Brute attack skipped windup")
	_check(attack.tick(1.0), "Brute attack never reached hit frame")

func _test_waves_and_groups() -> void:
	_check(CONTENT.wave_count() >= 15, "GameContent has fewer than 15 waves")
	var first_wave_roster: Array[StringName] = [GameIds.ENEMY_SWORDSMAN]
	_check(CONTENT.wave(1).enemy_roster == first_wave_roster, "Wave 1 is not swordsman-only")
	for enemy_id in _enemy_ids():
		var definition := CONTENT.enemy(enemy_id)
		for wave_number in range(1, definition.introduced_wave):
			_check(not CONTENT.wave(wave_number).enemy_roster.has(enemy_id), "%s appears before wave %d" % [enemy_id, definition.introduced_wave])
	_check(CONTENT.enemy_spawn_groups.size() == 7, "Expected seven data-driven spawn groups")
	_check(CONTENT.wave(5).guaranteed_group_ids.has(&"shield_and_spear"), "Wave 5 lacks shield-and-spear group")
	_check(CONTENT.wave(15).sequence_group_ids.size() >= 4, "Wave 15 has no sequential groups")
	_check(CONTENT.wave(15).maximum_alive.get(GameIds.ENEMY_COMMANDER, 0) == 1, "Wave 15 commander limit is wrong")

func _test_world_props() -> void:
	var required_styles: Array[StringName] = [&"rock", &"rock_group", &"bush", &"dry_bush", &"tree", &"dead_tree", &"barrel", &"crate", &"broken_crate", &"column", &"ruined_column", &"low_wall", &"wall_rubble", &"bones", &"campfire", &"torch", &"sacks", &"cart", &"altar", &"flag"]
	for style in required_styles:
		var definition := CONTENT.prop(style)
		_check(definition != null and definition.resolved_style() == style, "Missing world prop style: %s" % style)
	var decal_count := 0
	for definition in CONTENT.props:
		if definition.is_decal:
			decal_count += 1
			_check(not definition.has_collision and not definition.blocks_navigation, "Decal blocks movement: %s" % definition.id)
	_check(decal_count == 9, "Expected nine ground decal styles")
	var tree := WorldProp.new()
	tree.setup(CONTENT.prop(&"tree"), Vector2.ZERO)
	root.add_child(tree)
	_check(tree.get_node_or_null("GroundShadow") != null, "WorldProp has no GroundShadow")
	_check(tree.get_node_or_null("BackVisual") != null, "WorldProp has no BackVisual")
	_check(tree.get_node_or_null("MainVisual") != null, "WorldProp has no MainVisual")
	_check(tree.get_node_or_null("FrontVisual") != null, "WorldProp has no FrontVisual")
	_check(tree.get_node_or_null("CollisionBody/CollisionShape2D") != null, "WorldProp has no base CollisionShape2D")
	tree.queue_free()
	await process_frame

func _enemy_ids() -> Array[StringName]:
	return [GameIds.ENEMY_SWORDSMAN, GameIds.ENEMY_RAIDER, GameIds.ENEMY_BRUTE, GameIds.ENEMY_SHIELD_BEARER, GameIds.ENEMY_SPEARMAN, GameIds.ENEMY_ARCHER, GameIds.ENEMY_HEALER, GameIds.ENEMY_COMMANDER, GameIds.ENEMY_SUMMONER, GameIds.ENEMY_BOMBER]
