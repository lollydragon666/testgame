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
			_apply_affix(stats, affix)
	stats.finalize()
	return stats

static func _apply_jewelry(stats: PlayerStats, jewelry: JewelryDefinition) -> void:
	stats.damage_bonus += jewelry.damage_bonus
	stats.defense += jewelry.defense_bonus
	stats.max_health_bonus += jewelry.max_health_bonus
	stats.movement_speed_bonus += jewelry.movement_speed_bonus
	stats.attack_speed_bonus += jewelry.attack_speed_bonus
	stats.critical_chance += jewelry.critical_chance_bonus
	stats.critical_damage += jewelry.critical_damage_bonus
	stats.loot_chance += jewelry.loot_chance_bonus

static func _apply_affix(stats: PlayerStats, affix: ItemAffixRoll) -> void:
	if affix == null:
		return
	match affix.stat:
		ItemEnums.StatType.DAMAGE: stats.damage_bonus += affix.value
		ItemEnums.StatType.DEFENSE: stats.defense += affix.value
		ItemEnums.StatType.MAX_HEALTH: stats.max_health_bonus += affix.value
		ItemEnums.StatType.MOVEMENT_SPEED: stats.movement_speed_bonus += affix.value
		ItemEnums.StatType.ATTACK_SPEED: stats.attack_speed_bonus += affix.value
		ItemEnums.StatType.CRITICAL_CHANCE: stats.critical_chance += affix.value
		ItemEnums.StatType.CRITICAL_DAMAGE: stats.critical_damage += affix.value
		ItemEnums.StatType.LOOT_CHANCE: stats.loot_chance += affix.value
