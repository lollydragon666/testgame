extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)

func _run() -> void:
	_validate_rarity_and_affixes()
	_validate_persistence()
	_validate_stats()
	_validate_debug_command()
	await _validate_ui()
	if failures > 0:
		quit(1)
		return
	print("RANDOMIZED ITEMS PASS")
	quit()

func _validate_rarity_and_affixes() -> void:
	var factory := ItemFactory.new()
	factory.configure(CONTENT)
	var weapon := CONTENT.item(&"iron_sabre")
	for rarity_value in range(ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1500 + rarity_value
		var item := factory.create_random_item(weapon.id, 20, rarity_value as ItemEnums.ItemRarity, rng)
		_require(item != null, "Factory returned null for rarity %d" % rarity_value)
		if item == null:
			continue
		_require(item.affixes.size() == rarity_value, "Rarity %d generated an incorrect affix count" % rarity_value)
		var ids: Dictionary[StringName, bool] = {}
		var groups: Dictionary[StringName, bool] = {}
		for roll in item.affixes:
			var definition := CONTENT.item_affix(roll.affix_id)
			_require(definition != null and definition.supports(weapon, item.item_level), "Generated affix is incompatible")
			_require(not ids.has(roll.affix_id), "Generated duplicate affix ID")
			ids[roll.affix_id] = true
			if definition == null:
				continue
			if not definition.exclusive_group.is_empty():
				_require(not groups.has(definition.exclusive_group), "Generated duplicate exclusive group")
				groups[definition.exclusive_group] = true
			var limits := definition.value_range(item.item_level)
			_require(roll.value >= limits.x and roll.value <= limits.y, "Generated affix value is outside its range")

	var rarity_roller := ItemRarityRoller.new()
	_require(rarity_roller.maximum_for_wave(1) == ItemEnums.ItemRarity.UNCOMMON, "Wave 1 rarity cap failed")
	_require(rarity_roller.maximum_for_wave(7) == ItemEnums.ItemRarity.RARE, "Wave 7 rarity cap failed")
	_require(rarity_roller.maximum_for_wave(12) == ItemEnums.ItemRarity.EPIC, "Wave 12 rarity cap failed")
	var rarity_results: Dictionary[int, bool] = {}
	for seed_value in 100:
		var normal_rng := RandomNumberGenerator.new()
		var elite_rng := RandomNumberGenerator.new()
		normal_rng.seed = seed_value
		elite_rng.seed = seed_value
		var normal_rarity := rarity_roller.roll(30, normal_rng)
		var elite_rarity := rarity_roller.roll(30, elite_rng, true)
		_require(elite_rarity >= normal_rarity, "Elite rarity roll discarded the better result")
		rarity_results[int(normal_rarity)] = true
	_require(rarity_results.size() > 1, "Different seeds never changed rarity")
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 99173
	second_rng.seed = 99173
	_require(rarity_roller.roll(30, first_rng) == rarity_roller.roll(30, second_rng), "Same seed changed rarity")
	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = 42
	_require(rarity_roller.roll(30, boss_rng, false, true) <= ItemEnums.ItemRarity.LEGENDARY, "Boss exceeded legendary rarity")

	var sharp := CONTENT.item_affix(&"sharp")
	_require(sharp.value_range(20).x > sharp.value_range(1).x, "Item level did not increase affix range")
	var negative := ItemAffixDefinition.new()
	negative.id = &"negative_test"
	negative.display_name = "Negative"
	negative.allowed_item_types.append(ItemEnums.ItemType.WEAPON)
	negative.allowed_slots.append(ItemEnums.EquipmentSlot.WEAPON)
	negative.weight = -5.0
	var test_catalog := ItemAffixCatalog.new()
	test_catalog.definitions.append(negative)
	test_catalog.definitions.append(sharp)
	var generator := ItemAffixGenerator.new()
	generator.configure(test_catalog)
	var affix_rng := RandomNumberGenerator.new()
	affix_rng.seed = 7
	var rolls := generator.generate_affixes(weapon, ItemEnums.ItemRarity.UNCOMMON, 20, affix_rng)
	_require(rolls.size() == 1 and rolls[0].affix_id != negative.id, "Negative affix weight participated in selection")
	var potion := CONTENT.item(&"small_healing_potion")
	_require(generator.generate_affixes(potion, ItemEnums.ItemRarity.LEGENDARY, 20, affix_rng).is_empty(), "Consumable received affixes")

func _validate_persistence() -> void:
	var factory := ItemFactory.new()
	factory.configure(CONTENT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18273612
	var original := factory.create_random_item(&"iron_sabre", 12, ItemEnums.ItemRarity.EPIC, rng)
	var saved := original.to_dict()
	_require(saved.has("item_level") and saved.has("generated_seed"), "Random item metadata was not serialized")
	for saved_affix in saved.affixes:
		_require(saved_affix.size() == 2 and saved_affix.has("affix_id") and saved_affix.has("value"), "Affix save contains unstable presentation data")

	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	var equipment := {String.num_int64(ItemEnums.EquipmentSlot.WEAPON): original.instance_id}
	inventory.load_serialized([saved], equipment)
	var loaded := inventory.find_item(original.instance_id)
	_require(loaded != null, "Saved randomized item did not load")
	if loaded != null:
		_require(loaded.item_level == original.item_level and loaded.rarity == original.rarity, "Loaded item metadata changed")
		_require(loaded.generated_seed == original.generated_seed, "Loaded generated seed changed")
		_require(JSON.stringify(loaded.to_dict().affixes) == JSON.stringify(saved.affixes), "Affix values rerolled during load")
		_require(inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON) == original.instance_id, "Equipment reference changed during load")

	var corrupted := saved.duplicate(true)
	var corrupted_affixes: Array = corrupted.affixes
	var first_affix: Dictionary = corrupted_affixes[0]
	first_affix["affix_id"] = "missing_affix"
	corrupted["affixes"] = corrupted_affixes
	var corrupted_inventory := InventoryService.new()
	corrupted_inventory.configure(CONTENT)
	corrupted_inventory.load_serialized([corrupted], {})
	var recovered := corrupted_inventory.find_item(original.instance_id)
	_require(recovered != null, "One damaged affix deleted the entire item")
	if recovered != null:
		_require(recovered.affixes.size() == original.affixes.size() - 1, "Damaged affix was not skipped independently")

	var duplicate_inventory := InventoryService.new()
	duplicate_inventory.configure(CONTENT)
	duplicate_inventory.load_serialized([saved, saved.duplicate(true)], {})
	var matching_items: Array[ItemInstance] = []
	var unique_ids: Dictionary[String, bool] = {}
	for item in duplicate_inventory.get_items():
		if item.definition_id == original.definition_id:
			matching_items.append(item)
			unique_ids[item.instance_id] = true
	_require(matching_items.size() == 2 and unique_ids.size() == 2, "Duplicate IDs caused an item to be lost")

	var legacy_inventory := InventoryService.new()
	legacy_inventory.configure(CONTENT)
	legacy_inventory.load_serialized([{
		"instance_id": "legacy-fixed-item",
		"definition_id": "iron_sabre",
		"quantity": 1,
		"affixes": [{"affix_id": "sharp", "value": 999.0}],
	}], {})
	var legacy := legacy_inventory.find_item("legacy-fixed-item")
	_require(legacy != null and legacy.item_level == 1 and legacy.affixes.is_empty(), "Legacy fixed item migration added random properties")
	if legacy != null:
		_require(legacy.rarity == CONTENT.item(&"iron_sabre").rarity, "Legacy fixed item did not use definition rarity")
	var invalid_inventory := InventoryService.new()
	invalid_inventory.configure(CONTENT)
	invalid_inventory.load_serialized([{"instance_id": "bad", "definition_id": "missing", "quantity": 1}], {})
	_require(invalid_inventory.find_item("bad") == null, "Missing definition was loaded unsafely")

func _validate_stats() -> void:
	var weapon_definition := CONTENT.item(&"iron_sabre")
	var weapon := ItemInstance.create(weapon_definition.id, 1, ItemEnums.ItemRarity.LEGENDARY)
	weapon.item_level = 20
	weapon.affixes = [_roll(&"sharp", 10.0), _roll(&"mighty", 0.20), _roll(&"swift", 0.50), _roll(&"long", 0.10)]
	var summary := ItemInstanceStatCalculator.calculate(weapon, weapon_definition, CONTENT)
	_require(is_equal_approx(summary.damage, (weapon_definition.base_damage + 10.0) * 1.20), "Flat and percent damage order is incorrect")
	_require(summary.cooldown < weapon_definition.cooldown and summary.cooldown >= ItemInstanceStatCalculator.MINIMUM_ATTACK_COOLDOWN, "Attack speed cooldown calculation is incorrect")
	_require(is_equal_approx(summary.attack_reach, weapon_definition.base_attack_reach * 1.10), "Attack reach affix was not applied")
	var wide_weapon := ItemInstance.create(weapon_definition.id)
	wide_weapon.affixes.append(_roll(&"sweeping", 0.25))
	var wide_summary := ItemInstanceStatCalculator.calculate(wide_weapon, weapon_definition, CONTENT)
	_require(is_equal_approx(wide_summary.attack_width, weapon_definition.attack_half_width * 2.0 * 1.25), "Attack width affix was not applied")

	var capped := PlayerStats.new()
	capped.critical_chance = 5.0
	capped.critical_damage = 8.0
	capped.movement_speed_bonus = 8.0
	capped.finalize()
	_require(capped.critical_chance == PlayerStats.MAX_CRITICAL_CHANCE, "Critical chance cap failed")
	_require(capped.critical_damage == PlayerStats.MAXIMUM_CRITICAL_DAMAGE, "Critical damage cap failed")
	_require(capped.movement_multiplier() == PlayerStats.MAXIMUM_MOVEMENT_MULTIPLIER, "Movement speed cap failed")

	var hero := PlayerHero.new()
	hero.combat_random.seed = 11
	hero.critical_chance = 0.0
	_require(is_equal_approx(hero.roll_attack_damage(100.0), 100.0), "Zero critical chance produced a critical hit")
	hero.critical_chance = 1.0
	hero.critical_damage = 2.0
	_require(is_equal_approx(hero.roll_attack_damage(100.0), 200.0), "Critical multiplier was not applied exactly once")
	hero.free()

	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.clear_for_tests()
	var first_ring := ItemInstance.create(&"accuracy_ring", 1, ItemEnums.ItemRarity.UNCOMMON)
	first_ring.item_level = 10
	first_ring.affixes.append(_roll(&"precise", 0.10))
	var second_ring := ItemInstance.create(&"destruction_ring", 1, ItemEnums.ItemRarity.UNCOMMON)
	second_ring.item_level = 10
	second_ring.affixes.append(_roll(&"destructive", 0.30))
	_require(inventory.add_item(first_ring) and inventory.add_item(second_ring), "Ring stat test setup failed")
	_require(inventory.equip_item(first_ring.instance_id, ItemEnums.EquipmentSlot.RING_1), "First stat ring did not equip")
	_require(inventory.equip_item(second_ring.instance_id, ItemEnums.EquipmentSlot.RING_2), "Second stat ring did not equip")
	var combined := PlayerStatCalculator.calculate(inventory)
	var repeated := PlayerStatCalculator.calculate(inventory)
	_require(combined.critical_chance > 0.10 and combined.critical_damage > 1.80, "Two ring bonuses did not combine")
	_require(is_equal_approx(combined.critical_chance, repeated.critical_chance), "Repeated recalculation doubled bonuses")
	inventory.unequip_slot(ItemEnums.EquipmentSlot.RING_1)
	_require(PlayerStatCalculator.calculate(inventory).critical_chance < combined.critical_chance, "Unequipping did not remove affix bonuses")

func _validate_debug_command() -> void:
	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.clear_for_tests()
	var first := RandomItemDebugCommand.execute("spawn_random_item iron_sabre 10 epic 12345", inventory, CONTENT)
	var second := RandomItemDebugCommand.execute("spawn_random_item iron_sabre 10 epic 12345", inventory, CONTENT)
	_require(first != null and second != null, "Debug random item command failed")
	if first != null and second != null:
		_require(first.instance_id != second.instance_id, "Debug command reused an instance ID")
		_require(JSON.stringify(first.to_dict().affixes) == JSON.stringify(second.to_dict().affixes), "Debug command seed was not reproducible")
	_require(RandomItemDebugCommand.execute("spawn_random_item missing 10 rare 1", inventory, CONTENT) == null, "Debug command accepted a missing definition")

func _validate_ui() -> void:
	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.load_serialized([], {})
	var factory := ItemFactory.new()
	factory.configure(CONTENT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309
	var selected := factory.create_random_item(&"iron_sabre", 20, ItemEnums.ItemRarity.LEGENDARY, rng)
	var second := factory.create_random_item(&"iron_sabre", 20, ItemEnums.ItemRarity.LEGENDARY, rng)
	_require(inventory.add_item(selected) and inventory.add_item(second), "UI random item setup failed")
	var ui := InventoryUI.new()
	ui.configure(CONTENT, inventory)
	root.add_child(ui)
	await process_frame
	ui.open()
	ui.selected_instance_id = selected.instance_id
	ui._refresh()
	_require(ui.details_label.text.contains(ItemRarityPresentation.rarity_name(selected.rarity)), "UI does not show rarity")
	_require(ui.details_label.text.contains("Уровень предмета: 20"), "UI does not show item level")
	for roll in selected.affixes:
		var affix_definition := CONTENT.item_affix(roll.affix_id)
		_require(ui.details_label.text.contains(affix_definition.display_name), "UI omitted an affix")
	var comparison := ui._comparison_text(selected, CONTENT.item(selected.definition_id))
	_require(comparison.contains("Cooldown") and comparison.contains("→"), "UI comparison does not use final values")
	_require(selected.instance_id != second.instance_id, "Identical definitions are not distinct UI items")
	ui._equip_selected()
	_require(inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON) == selected.instance_id, "UI did not refresh equipment to the selected instance")
	ui.queue_free()
	await process_frame

func _roll(affix_id: StringName, value: float) -> ItemAffixRoll:
	var result := ItemAffixRoll.new()
	result.affix_id = affix_id
	result.value = value
	return result
