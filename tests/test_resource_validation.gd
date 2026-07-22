extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const SCAN_EXTENSIONS := ["gd", "tscn", "tres", "godot", "cfg"]
const LOAD_EXTENSIONS := ["gd", "tscn", "tres"]
const SKIPPED_DIRECTORIES := [".git", ".godot", ".idea", ".vscode", "builds", "exports", "warrioir-"]

var failures: Array[String] = []
var scanned_files: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	_collect_files("res://")
	_validate_loadable_resources()
	_validate_text_references()
	_validate_content_catalog()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("RESOURCE VALIDATION PASS (%d files checked)" % scanned_files.size())
	quit()

func _collect_files(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	_check(directory != null, "Cannot open directory: %s" % directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()
		if SCAN_EXTENSIONS.has(extension):
			scanned_files.append(directory_path.path_join(file_name))
	for child_name in directory.get_directories():
		if SKIPPED_DIRECTORIES.has(child_name) or child_name.begins_with("."):
			continue
		_collect_files(directory_path.path_join(child_name))

func _validate_loadable_resources() -> void:
	for path in scanned_files:
		if not LOAD_EXTENSIONS.has(path.get_extension().to_lower()):
			continue
		_check(ResourceLoader.exists(path), "ResourceLoader cannot find: %s" % path)
		if ResourceLoader.exists(path):
			_check(ResourceLoader.load(path) != null, "Resource cannot be loaded: %s" % path)

func _validate_text_references() -> void:
	var reference_pattern := RegEx.new()
	var compile_error := reference_pattern.compile("res://[A-Za-z0-9_./-]+")
	_check(compile_error == OK, "Cannot compile resource reference validator")
	if compile_error != OK:
		return
	var checked_references: Dictionary[String, bool] = {}
	for source_path in scanned_files:
		var file := FileAccess.open(source_path, FileAccess.READ)
		_check(file != null, "Cannot read source file: %s" % source_path)
		if file == null:
			continue
		for match_result in reference_pattern.search_all(file.get_as_text()):
			var reference := match_result.get_string()
			if checked_references.has(reference):
				continue
			checked_references[reference] = true
			_check(FileAccess.file_exists(reference) or ResourceLoader.exists(reference), "Missing referenced file: %s" % reference)

func _validate_content_catalog() -> void:
	_check(CONTENT != null, "GameContent resource is missing")
	if CONTENT == null:
		return
	_check(not CONTENT.enemies.is_empty(), "GameContent has no enemies")
	_check(not CONTENT.spells.is_empty(), "GameContent has no spells")
	_check(not CONTENT.weapons.is_empty(), "GameContent has no weapons")
	_check(not CONTENT.upgrades.is_empty(), "GameContent has no upgrades")
	_check(not CONTENT.waves.is_empty(), "GameContent has no waves")
	_check(not CONTENT.props.is_empty(), "GameContent has no props")
	_check(not CONTENT.locations.is_empty(), "GameContent has no locations")
	_check(CONTENT.item_catalog != null and not CONTENT.all_items().is_empty(), "GameContent has no item catalog")
	_check(CONTENT.shops.size() == 3, "GameContent must contain three shops")
	_check(CONTENT.loot_tables.size() >= 3, "GameContent must contain base loot tables")
	_check(CONTENT.item_affixes != null and not CONTENT.item_affixes.definitions.is_empty(), "GameContent has no item affixes")
	for location_error in CONTENT.validate_locations():
		_check(false, location_error)
	var item_ids: Dictionary[StringName, bool] = {}
	for definition in CONTENT.all_items():
		_check(definition != null and not definition.id.is_empty(), "Invalid item definition")
		if definition == null:
			continue
		_check(not item_ids.has(definition.id), "Duplicate item ID: %s" % definition.id)
		item_ids[definition.id] = true
		_check(definition.base_price >= 0 and definition.max_stack > 0, "Invalid item values: %s" % definition.id)
	for shop in CONTENT.shops:
		_check(shop != null and not shop.id.is_empty(), "Invalid shop definition")
		if shop == null:
			continue
		for item_id in shop.stock_definition_ids:
			_check(item_ids.has(item_id), "Shop references unknown item: %s" % item_id)
	for table in CONTENT.loot_tables:
		_check(table != null and not table.id.is_empty() and not table.entries.is_empty(), "Invalid loot table")
	var affix_ids: Dictionary[StringName, bool] = {}
	for affix in CONTENT.item_affixes.definitions:
		_check(affix != null and not affix.id.is_empty(), "Invalid item affix")
		if affix != null:
			_check(not affix_ids.has(affix.id), "Duplicate item affix: %s" % affix.id)
			affix_ids[affix.id] = true

	var enemy_ids: Dictionary[StringName, bool] = {}
	for definition in CONTENT.enemies:
		_check(definition != null, "EnemyDefinition entry is null")
		if definition == null:
			continue
		_check(not definition.id.is_empty(), "EnemyDefinition has an empty ID")
		_check(not enemy_ids.has(definition.id), "Duplicate enemy ID: %s" % definition.id)
		enemy_ids[definition.id] = true
		_check(definition.scene != null, "Enemy has no scene: %s" % definition.id)
		if definition.scene != null:
			_check(FileAccess.file_exists(definition.scene.resource_path), "Enemy scene file is missing: %s" % definition.scene.resource_path)

	var spell_ids: Dictionary[StringName, bool] = {}
	for definition in CONTENT.spells:
		_check(definition != null, "SpellDefinition entry is null")
		if definition == null:
			continue
		_check(not definition.id.is_empty(), "SpellDefinition has an empty ID")
		_check(not spell_ids.has(definition.id), "Duplicate spell ID: %s" % definition.id)
		spell_ids[definition.id] = true
		_check(definition.max_level > 0, "Spell max_level must be positive: %s" % definition.id)

	var weapon_ids: Dictionary[StringName, bool] = {}
	for definition in CONTENT.weapons:
		_check(definition != null, "WeaponDefinition entry is null")
		if definition == null:
			continue
		_check(not definition.id.is_empty(), "WeaponDefinition has an empty ID")
		_check(not weapon_ids.has(definition.id), "Duplicate weapon ID: %s" % definition.id)
		weapon_ids[definition.id] = true

	var upgrade_ids: Dictionary[StringName, bool] = {}
	for definition in CONTENT.upgrades:
		_check(definition != null, "UpgradeDefinition entry is null")
		if definition == null:
			continue
		_check(not definition.id.is_empty(), "UpgradeDefinition has an empty ID")
		_check(not upgrade_ids.has(definition.id), "Duplicate upgrade ID: %s" % definition.id)
		upgrade_ids[definition.id] = true
		if not definition.spell_id.is_empty():
			_check(spell_ids.has(definition.spell_id), "Upgrade references an unknown spell: %s" % definition.spell_id)

	var wave_numbers: Dictionary[int, bool] = {}
	for definition in CONTENT.waves:
		_check(definition != null, "WaveDefinition entry is null")
		if definition == null:
			continue
		_check(definition.number > 0, "Wave number must be positive")
		_check(not wave_numbers.has(definition.number), "Duplicate wave number: %d" % definition.number)
		wave_numbers[definition.number] = true
		_check(not definition.enemy_roster.is_empty(), "Wave has an empty roster: %d" % definition.number)
		for enemy_id in definition.enemy_roster:
			_check(enemy_ids.has(enemy_id), "Wave %d references an unknown enemy: %s" % [definition.number, enemy_id])
		if not definition.boss_enemy_id.is_empty():
			_check(enemy_ids.has(definition.boss_enemy_id), "Wave %d references an unknown boss: %s" % [definition.number, definition.boss_enemy_id])

	var prop_ids: Dictionary[StringName, bool] = {}
	for definition in CONTENT.props:
		_check(definition != null, "PropDefinition entry is null")
		if definition == null:
			continue
		_check(not definition.id.is_empty(), "PropDefinition has an empty ID")
		_check(not prop_ids.has(definition.id), "Duplicate prop ID: %s" % definition.id)
		prop_ids[definition.id] = true
		_check(definition.spawn_count >= 0, "Prop spawn_count cannot be negative: %s" % definition.id)
