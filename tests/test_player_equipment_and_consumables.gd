extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	_require(InputMap.has_action("quick_slot_2") and InputMap.has_action("quick_slot_3"), "Quick-slot input actions are missing")
	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.load_serialized([], {})
	for item_id in [&"iron_sabre", &"cloth_armor", &"defense_amulet", &"strength_ring", &"small_healing_potion", &"power_potion", &"iron_skin_potion", &"haste_potion", &"wind_potion"]:
		_require(inventory.add_item_by_definition(item_id, 2 if item_id == &"small_healing_potion" else 1), "Test item could not be added: %s" % item_id)
	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	player.configure_inventory(inventory)
	root.add_child(player)
	await process_frame
	player.set_gameplay_active(false)

	var armor := _find(inventory, &"cloth_armor")
	var amulet := _find(inventory, &"defense_amulet")
	var ring := _find(inventory, &"strength_ring")
	_require(inventory.equip_item(armor.instance_id, ItemEnums.EquipmentSlot.ARMOR), "Armor equip failed")
	_require(inventory.equip_item(amulet.instance_id, ItemEnums.EquipmentSlot.AMULET), "Amulet equip failed")
	_require(inventory.equip_item(ring.instance_id, ItemEnums.EquipmentSlot.RING_1), "Ring equip failed")
	var stats := PlayerStatCalculator.calculate(inventory)
	_require(is_equal_approx(stats.defense, 25.0), "Armor and jewelry defense did not add together")
	_require(is_equal_approx(stats.damage_bonus, 0.08), "Jewelry damage bonus is incorrect")
	player.apply_equipment_stats(stats)
	player.health = player.max_health
	player.invulnerability = 0.0
	player.take_damage(100.0)
	_require(is_equal_approx(player.max_health - player.health, 80.0), "Defense formula did not reduce incoming damage")
	_require(player.health >= 0.0, "Defense created negative health through negative damage")
	_require(is_equal_approx(player.roll_attack_damage(100.0), 108.0), "Equipment damage bonus was not applied")

	var defense_before_unequip := PlayerStatCalculator.calculate(inventory).defense
	_require(inventory.unequip_slot(ItemEnums.EquipmentSlot.AMULET), "Amulet unequip failed")
	_require(PlayerStatCalculator.calculate(inventory).defense < defense_before_unequip, "Unequipping did not remove stats")

	var sabre := _find(inventory, &"iron_sabre")
	_require(inventory.equip_item(sabre.instance_id, ItemEnums.EquipmentSlot.WEAPON), "Sword equip failed")
	var sabre_definition := CONTENT.item(&"iron_sabre") as WeaponDefinition
	_require(player.attack.definition == sabre_definition, "Equipped sword did not reach PlayerAttack")
	_require(player.attack.damage == sabre_definition.base_damage, "Equipped sword damage was not refreshed")
	_require(player.attack.definition.visual_style == &"sabre", "Sword visual style was not refreshed")
	var base_attack_half_width := player.attack.attack_half_width
	player.attack.upgrade_sword()
	_require(player.attack.sword_tier == 2, "Run sword tier did not increase")
	_require(is_equal_approx(player.attack.attack_half_width, base_attack_half_width * sabre_definition.width_multiplier_per_tier), "Sword growth did not expand the attack zone by 12%")
	player.reset_run()
	player.apply_equipped_weapon()
	_require(player.attack.sword_tier == 1 and player.attack.definition == sabre_definition, "Run reset changed base weapon or retained sword tier")

	var healing_stack := _find(inventory, &"small_healing_potion")
	_require(inventory.equip_item(healing_stack.instance_id, ItemEnums.EquipmentSlot.CONSUMABLE_2), "Healing potion quick-slot assignment failed")
	var initial_quantity := healing_stack.quantity
	_require(not inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Healing potion was consumed at full health")
	_require(healing_stack.quantity == initial_quantity, "Failed healing consumed quantity")
	player.health = player.max_health - 50.0
	_require(inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Healing potion use failed")
	_require(is_equal_approx(player.health, player.max_health - 20.0), "Healing potion restored an incorrect amount")
	_require(healing_stack.quantity == initial_quantity - 1, "Potion quantity did not decrease")
	_require(not inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Potion cooldown allowed immediate reuse")
	inventory.tick_consumable_cooldowns(10.0)
	player.health = player.max_health - 10.0
	_require(inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Second healing potion use failed after cooldown")
	_require(player.health == player.max_health, "Healing exceeded or missed maximum health")
	_require(inventory.equipped_item(ItemEnums.EquipmentSlot.CONSUMABLE_2) == null, "Empty potion stack did not clear quick slot")

	var power := CONTENT.item(&"power_potion") as ConsumableDefinition
	_require(player.apply_consumable(power), "Power potion effect failed")
	_require(is_equal_approx(player.temporary_damage_bonus, 0.25), "Power potion bonus is incorrect")
	player._tick_temporary_effects(10.0)
	_require(player.apply_consumable(power), "Repeated power potion failed")
	_require(player.temporary_effect_remaining(ItemEnums.ConsumableEffectType.DAMAGE_BOOST) > 19.9, "Repeated potion did not refresh duration")
	_require(is_equal_approx(player.temporary_damage_bonus, 0.25), "Repeated potion stacked its value")

	var iron_skin := CONTENT.item(&"iron_skin_potion") as ConsumableDefinition
	player.apply_consumable(iron_skin)
	_require(is_equal_approx(player.temporary_defense_bonus, 35.0), "Defense potion did not add defense")
	player._tick_temporary_effects(iron_skin.duration + 0.1)
	_require(is_equal_approx(player.temporary_defense_bonus, 0.0), "Defense potion did not expire")

	var haste := CONTENT.item(&"haste_potion") as ConsumableDefinition
	player.apply_consumable(haste)
	_require(player.attack.effective_cooldown_duration() >= 0.14, "Potion made sword cooldown lower than minimum")
	player.magic.unlock_or_upgrade(&"lightning")
	_require(player.magic.effective_spell_cooldown(&"lightning") >= CONTENT.spell(&"lightning").minimum_cooldown, "Potion made spell cooldown lower than minimum")
	var wind := CONTENT.item(&"wind_potion") as ConsumableDefinition
	var movement_before := player.movement.speed
	player.apply_consumable(wind)
	_require(player.movement.speed > movement_before, "Movement potion did not increase speed")
	player._tick_temporary_effects(wind.duration + 0.1)
	_require(is_equal_approx(player.movement.speed, movement_before), "Movement speed did not return after potion")

	player.apply_consumable(power)
	var power_item := _find(inventory, &"power_potion")
	_require(inventory.equip_item(power_item.instance_id, ItemEnums.EquipmentSlot.CONSUMABLE_3), "Power potion quick-slot setup failed")
	_require(inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_3), "Power potion quick-slot use failed")
	player.reset_run()
	_require(player.temporary_effect_remaining(ItemEnums.ConsumableEffectType.DAMAGE_BOOST) == 0.0, "reset_run retained temporary potion effects")
	_require(inventory.consumable_cooldown_remaining(ItemEnums.EquipmentSlot.CONSUMABLE_3) == 0.0, "reset_run retained potion cooldown")
	player.queue_free()
	print("PLAYER EQUIPMENT AND CONSUMABLES PASS")
	quit()

func _find(inventory: InventoryService, definition_id: StringName) -> ItemInstance:
	for item in inventory.get_items():
		if item.definition_id == definition_id:
			return item
	return null
