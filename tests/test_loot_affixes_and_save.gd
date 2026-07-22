extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	_validate_loot_tables()
	_validate_affixes()
	_validate_save_round_trip()
	await _validate_world_drops()
	print("LOOT AFFIXES AND SAVE PASS")
	quit()

func _enemy(definition_id: StringName, elite := false) -> EnemyBase:
	var enemy := EnemyBase.new()
	enemy.definition = CONTENT.enemy(definition_id)
	enemy.is_elite = elite
	return enemy

func _validate_loot_tables() -> void:
	var normal := CONTENT.loot_table(&"normal")
	var elite := CONTENT.loot_table(&"elite")
	var boss := CONTENT.loot_table(&"boss")
	_require(normal != null and elite != null and boss != null, "One or more loot tables are missing")
	_require(is_equal_approx(normal.base_drop_chance, 0.08), "Normal drop chance is not 8%")
	_require(is_equal_approx(elite.base_drop_chance, 0.25), "Elite drop chance is not 25%")
	_require(is_equal_approx(boss.base_drop_chance, 1.0), "Boss drop chance is not 100%")
	_require(_weights(normal) == [55, 20, 15, 10], "Normal category weights are incorrect")
	_require(_weights(elite) == [30, 25, 20, 25], "Elite category weights are incorrect")
	_require(_weights(boss) == [15, 30, 25, 30], "Boss category weights are incorrect")

	var service := LootService.new()
	service.configure(CONTENT)
	var rng := RandomNumberGenerator.new()
	var boss_enemy := _enemy(&"boss")
	for seed_value in 100:
		rng.seed = seed_value + 1
		var drops := service.roll_for_enemy(boss_enemy, 7, 0.0, rng)
		_require(drops.size() == 1, "Boss did not guarantee one item")
		_require(CONTENT.item(drops[0].definition_id).minimum_wave <= 7, "Boss rolled an item above current wave")

	var normal_enemy := _enemy(&"brawler")
	var elite_enemy := _enemy(&"brawler", true)
	var normal_drops := 0
	var elite_drops := 0
	for seed_value in 600:
		rng.seed = seed_value + 700
		normal_drops += service.roll_for_enemy(normal_enemy, 7, 0.0, rng).size()
		rng.seed = seed_value + 700
		elite_drops += service.roll_for_enemy(elite_enemy, 7, 0.0, rng).size()
	_require(elite_drops > normal_drops, "Elite enemies did not use their increased drop chance")
	for seed_value in 40:
		rng.seed = seed_value + 9000
		_require(service.roll_for_enemy(normal_enemy, 7, 1000.0, rng).size() == 1, "Loot chance bonus did not clamp to a guaranteed valid roll")

func _weights(table: LootTable) -> Array[int]:
	var result: Array[int] = []
	for entry in table.entries:
		result.append(roundi(entry.weight))
	return result

func _validate_affixes() -> void:
	_require(CONTENT.item_affixes != null and CONTENT.item_affixes.definitions.size() == 8, "Expected eight affix definitions")
	var generator := ItemAffixGenerator.new()
	generator.configure(CONTENT.item_affixes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var weapon_definition := CONTENT.item(&"iron_sabre")
	for rarity_value in range(ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY + 1):
		var item := ItemInstance.create(weapon_definition.id, 1, rarity_value as ItemEnums.ItemRarity)
		generator.apply_affixes(item, weapon_definition, rng)
		_require(item.affixes.size() == rarity_value, "Affix count does not match rarity %d" % rarity_value)
		var seen: Dictionary[StringName, bool] = {}
		for affix in item.affixes:
			_require(not seen.has(affix.affix_id), "Generated duplicate affix")
			seen[affix.affix_id] = true
			var affix_definition := CONTENT.item_affix(affix.affix_id)
			_require(affix_definition.supports(weapon_definition.item_type), "Generated incompatible affix")
			_require(affix.value >= minf(affix_definition.min_value, affix_definition.max_value), "Affix value is below range")
			_require(affix.value <= maxf(affix_definition.min_value, affix_definition.max_value), "Affix value is above range")

	_require(generator.maximum_rarity_for_wave(1) == ItemEnums.ItemRarity.UNCOMMON, "Wave 1 rarity cap is incorrect")
	_require(generator.maximum_rarity_for_wave(4) == ItemEnums.ItemRarity.RARE, "Wave 4 rarity cap is incorrect")
	_require(generator.maximum_rarity_for_wave(8) == ItemEnums.ItemRarity.EPIC, "Wave 8 rarity cap is incorrect")
	_require(generator.maximum_rarity_for_wave(13) == ItemEnums.ItemRarity.LEGENDARY, "Wave 13 rarity cap is incorrect")

	var legendary := ItemInstance.create(&"iron_sabre", 1, ItemEnums.ItemRarity.LEGENDARY)
	generator.apply_affixes(legendary, weapon_definition, rng)
	var saved := legendary.to_dict()
	var loaded := ItemInstance.from_dict(saved)
	_require(loaded != null and loaded.instance_id == legendary.instance_id, "Item unique ID was not preserved")
	_require(loaded.rarity == legendary.rarity and loaded.affixes.size() == legendary.affixes.size(), "Rarity or affix count was not saved")
	for index in loaded.affixes.size():
		_require(loaded.affixes[index].affix_id == legendary.affixes[index].affix_id, "Affix ID rerolled during load")
		_require(is_equal_approx(loaded.affixes[index].value, legendary.affixes[index].value), "Affix value rerolled during load")
	_require(weapon_definition.resolved_sell_price(legendary.affixes.size()) > weapon_definition.resolved_sell_price(), "Affixes did not increase sell price")

	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.load_serialized([], {})
	var first_ring := ItemInstance.create(&"accuracy_ring")
	var second_ring := ItemInstance.create(&"strength_ring")
	for ring in [first_ring, second_ring]:
		var critical_affix := ItemAffixRoll.new()
		critical_affix.affix_id = &"precise"
		critical_affix.stat = ItemEnums.StatType.CRITICAL_CHANCE
		critical_affix.value = 1.0
		ring.affixes.append(critical_affix)
		_require(inventory.add_item(ring), "Critical cap test item could not be added")
	_require(inventory.equip_item(first_ring.instance_id, ItemEnums.EquipmentSlot.RING_1), "Critical ring one equip failed")
	_require(inventory.equip_item(second_ring.instance_id, ItemEnums.EquipmentSlot.RING_2), "Critical ring two equip failed")
	_require(is_equal_approx(PlayerStatCalculator.calculate(inventory).critical_chance, PlayerStats.MAX_CRITICAL_CHANCE), "Critical chance did not clamp to 75%")

func _validate_save_round_trip() -> void:
	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.load_serialized([], {})
	_require(inventory.add_item_by_definition(&"small_healing_potion", 3), "Save potion setup failed")
	var potion: ItemInstance
	for item in inventory.get_items():
		if item.definition_id == &"small_healing_potion": potion = item
	_require(inventory.equip_item(potion.instance_id, ItemEnums.EquipmentSlot.CONSUMABLE_2), "Quick slot save setup failed")
	var profile := PlayerProfile.new()
	profile.gold = 321
	profile.inventory_items = inventory.serialized_items()
	profile.equipped_items = inventory.serialized_equipment()
	profile.selected_weapon_definition_id = &"player_sword"
	var loaded_profile := PlayerProfile.new()
	loaded_profile.load_dict(profile.to_dict())
	var loaded_inventory := InventoryService.new()
	loaded_inventory.configure(CONTENT)
	loaded_inventory.load_serialized(loaded_profile.inventory_items, loaded_profile.equipped_items, loaded_profile.selected_weapon_definition_id)
	_require(loaded_profile.gold == 321, "Currency was not saved")
	_require(loaded_inventory.inventory_size() == inventory.inventory_size(), "Inventory was not saved")
	_require(loaded_inventory.equipped_instance_id(ItemEnums.EquipmentSlot.CONSUMABLE_2) == potion.instance_id, "Quick slot was not saved")
	_require(loaded_inventory.consumable_cooldown_remaining(ItemEnums.EquipmentSlot.CONSUMABLE_2) == 0.0, "Potion cooldown was persisted")
	_require(not loaded_profile.to_dict().has("temporary_effects"), "Temporary effects were persisted")
	_require(not loaded_profile.to_dict().has("world_item_drops"), "Ground items were persisted")

	var legacy := PlayerProfile.new()
	legacy.load_dict({"gold": 77, "selected_weapon_id": "iron_sabre"})
	var legacy_inventory := InventoryService.new()
	legacy_inventory.configure(CONTENT)
	legacy_inventory.load_serialized(legacy.inventory_items, legacy.equipped_items, legacy.selected_weapon_definition_id)
	_require(legacy.gold == 77, "Legacy profile lost unrelated data")
	_require(legacy_inventory.equipped_definition(ItemEnums.EquipmentSlot.WEAPON).id == &"iron_sabre", "Legacy selected weapon was not migrated")
	legacy_inventory.load_serialized(legacy_inventory.serialized_items(), legacy_inventory.serialized_equipment(), legacy.selected_weapon_definition_id)
	_require(legacy_inventory.inventory_size() == 1, "Legacy weapon duplicated on repeated load")

func _validate_world_drops() -> void:
	var full_inventory := InventoryService.new()
	full_inventory.configure(CONTENT)
	for _index in InventoryService.CAPACITY:
		full_inventory.add_item_by_definition(&"old_gladius")
	var failed_drop := WorldItemDrop.new()
	failed_drop.setup(ItemInstance.create(&"iron_sabre"), CONTENT.item(&"iron_sabre"), null, full_inventory, Vector2.ZERO)
	root.add_child(failed_drop)
	_require(not failed_drop.try_pick_up(), "Full inventory picked up a ground item")
	_require(is_instance_valid(failed_drop) and not failed_drop.is_queued_for_deletion(), "Failed pickup removed ground item")
	failed_drop.queue_free()

	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	var item := ItemInstance.create(&"iron_sabre")
	var successful_drop := WorldItemDrop.new()
	successful_drop.setup(item, CONTENT.item(item.definition_id), null, inventory, Vector2.ZERO)
	root.add_child(successful_drop)
	_require(successful_drop.try_pick_up(), "Ground item could not be picked up")
	_require(inventory.find_item(item.instance_id) != null, "Picked item was not added to inventory")
	_require(successful_drop.is_queued_for_deletion(), "Successful pickup did not remove ground item")
	await process_frame
