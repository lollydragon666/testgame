class_name PlayerStatCalculator
extends RefCounted

static func calculate(inventory: InventoryService) -> PlayerStats:
	var stats := PlayerStats.new()
	if inventory == null:
		stats.finalize()
		return stats
	for slot in [
		ItemEnums.EquipmentSlot.WEAPON,
		ItemEnums.EquipmentSlot.ARMOR,
		ItemEnums.EquipmentSlot.AMULET,
		ItemEnums.EquipmentSlot.RING_1,
		ItemEnums.EquipmentSlot.RING_2,
	]:
		var item := inventory.equipped_item(slot)
		var definition := inventory.equipped_definition(slot)
		if item == null or definition == null:
			continue
		if definition is WeaponDefinition:
			stats.weapon_definition = definition as WeaponDefinition
			stats.weapon_instance = item
		elif definition is ArmorDefinition:
			var armor := definition as ArmorDefinition
			stats.defense += armor.defense
			stats.max_health_bonus += armor.max_health_bonus
			stats.movement_speed_bonus += armor.movement_speed_modifier
		elif definition is JewelryDefinition:
			_apply_jewelry(stats, definition as JewelryDefinition)
		for affix in item.affixes:
			_apply_affix(stats, affix, inventory.game_content)
	stats.finalize()
	return stats

static func _apply_jewelry(stats: PlayerStats, jewelry: JewelryDefinition) -> void:
	stats.damage_percent_bonus += jewelry.damage_bonus
	stats.defense += jewelry.defense_bonus
	stats.max_health_bonus += jewelry.max_health_bonus
	stats.movement_speed_bonus += jewelry.movement_speed_bonus
	stats.attack_speed_bonus += jewelry.attack_speed_bonus
	stats.critical_chance += jewelry.critical_chance_bonus
	stats.critical_damage += jewelry.critical_damage_bonus
	stats.loot_chance += jewelry.loot_chance_bonus

static func _apply_affix(stats: PlayerStats, affix: ItemAffixRoll, content: GameContent) -> void:
	if affix == null or content == null:
		return
	var definition := content.item_affix(affix.affix_id)
	if definition == null:
		return
	match definition.stat_type:
		ItemEnums.ItemStatType.DAMAGE_FLAT: stats.flat_damage_bonus += affix.value
		ItemEnums.ItemStatType.DAMAGE_PERCENT: stats.damage_percent_bonus += affix.value
		ItemEnums.ItemStatType.DEFENSE_FLAT: stats.defense += affix.value
		ItemEnums.ItemStatType.MAX_HEALTH_FLAT: stats.max_health_bonus += affix.value
		ItemEnums.ItemStatType.MOVEMENT_SPEED_PERCENT: stats.movement_speed_bonus += affix.value
		ItemEnums.ItemStatType.ATTACK_SPEED_PERCENT: stats.attack_speed_bonus += affix.value
		ItemEnums.ItemStatType.ATTACK_REACH_PERCENT: stats.attack_reach_bonus += affix.value
		ItemEnums.ItemStatType.ATTACK_WIDTH_PERCENT: stats.attack_width_bonus += affix.value
		ItemEnums.ItemStatType.CRITICAL_CHANCE: stats.critical_chance += affix.value
		ItemEnums.ItemStatType.CRITICAL_DAMAGE: stats.critical_damage += affix.value
		ItemEnums.ItemStatType.LOOT_CHANCE: stats.loot_chance += affix.value
