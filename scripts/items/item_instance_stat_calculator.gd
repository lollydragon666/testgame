class_name ItemInstanceStatCalculator
extends RefCounted

const MINIMUM_ATTACK_COOLDOWN := 0.14

static func calculate(
	item: ItemInstance,
	definition: ItemDefinition,
	content: GameContent
) -> ItemInstanceStats:
	var stats := ItemInstanceStats.new()
	if item == null or definition == null:
		return stats
	if definition is WeaponDefinition:
		var weapon := definition as WeaponDefinition
		stats.damage = weapon.base_damage
		stats.cooldown = weapon.cooldown
		stats.attack_reach = weapon.base_attack_reach
		stats.attack_width = weapon.attack_half_width * 2.0
	elif definition is ArmorDefinition:
		var armor := definition as ArmorDefinition
		stats.defense = armor.defense
		stats.max_health = armor.max_health_bonus
		stats.movement_speed = armor.movement_speed_modifier
	elif definition is JewelryDefinition:
		var jewelry := definition as JewelryDefinition
		stats.damage_percent = jewelry.damage_bonus
		stats.defense = jewelry.defense_bonus
		stats.max_health = jewelry.max_health_bonus
		stats.movement_speed = jewelry.movement_speed_bonus
		stats.attack_speed = jewelry.attack_speed_bonus
		stats.critical_chance = jewelry.critical_chance_bonus
		stats.critical_damage = jewelry.critical_damage_bonus
		stats.loot_chance = jewelry.loot_chance_bonus
	for roll in item.affixes:
		_apply_affix(stats, roll, content)
	if definition is WeaponDefinition:
		stats.damage *= maxf(0.05, 1.0 + stats.damage_percent)
		stats.cooldown = maxf(MINIMUM_ATTACK_COOLDOWN, stats.cooldown / maxf(0.25, 1.0 + stats.attack_speed))
		stats.attack_reach *= maxf(0.5, 1.0 + _sum_affix(item, content, ItemEnums.ItemStatType.ATTACK_REACH_PERCENT))
		stats.attack_width *= maxf(0.5, 1.0 + _sum_affix(item, content, ItemEnums.ItemStatType.ATTACK_WIDTH_PERCENT))
	return stats

static func _apply_affix(stats: ItemInstanceStats, roll: ItemAffixRoll, content: GameContent) -> void:
	var affix := content.item_affix(roll.affix_id) if content != null and roll != null else null
	if affix == null:
		return
	match affix.stat_type:
		ItemEnums.ItemStatType.DAMAGE_FLAT: stats.damage += roll.value
		ItemEnums.ItemStatType.DAMAGE_PERCENT: stats.damage_percent += roll.value
		ItemEnums.ItemStatType.DEFENSE_FLAT: stats.defense += roll.value
		ItemEnums.ItemStatType.MAX_HEALTH_FLAT: stats.max_health += roll.value
		ItemEnums.ItemStatType.ATTACK_SPEED_PERCENT: stats.attack_speed += roll.value
		ItemEnums.ItemStatType.MOVEMENT_SPEED_PERCENT: stats.movement_speed += roll.value
		ItemEnums.ItemStatType.CRITICAL_CHANCE: stats.critical_chance += roll.value
		ItemEnums.ItemStatType.CRITICAL_DAMAGE: stats.critical_damage += roll.value
		ItemEnums.ItemStatType.LOOT_CHANCE: stats.loot_chance += roll.value

static func _sum_affix(
	item: ItemInstance,
	content: GameContent,
	stat_type: ItemEnums.ItemStatType
) -> float:
	var result := 0.0
	for roll in item.affixes:
		var definition := content.item_affix(roll.affix_id) if content != null and roll != null else null
		if definition != null and definition.stat_type == stat_type:
			result += roll.value
	return result
