class_name ItemAffixGenerator
extends RefCounted

var catalog: ItemAffixCatalog
var rarity_roller := ItemRarityRoller.new()

func configure(affix_catalog: ItemAffixCatalog) -> void:
	catalog = affix_catalog

func apply_to_item(
	item: ItemInstance,
	definition: ItemDefinition,
	wave: int,
	rng: RandomNumberGenerator
) -> void:
	if item == null or definition == null or rng == null:
		return
	item.affixes.clear()
	var rolled_rarity := roll_rarity(wave, rng)
	item.rarity = maxi(definition.rarity, rolled_rarity) as ItemEnums.ItemRarity
	apply_affixes(item, definition, rng)

func apply_affixes(
	item: ItemInstance,
	definition: ItemDefinition,
	rng: RandomNumberGenerator
) -> void:
	if item == null or definition == null or rng == null:
		return
	item.affixes.clear()
	if definition.item_type == ItemEnums.ItemType.CONSUMABLE or catalog == null:
		return
	var available := catalog.compatible(definition, item.item_level)
	var target_count := mini(affix_count_for_rarity(item.rarity), available.size())
	for _index in target_count:
		var selected := _weighted_take(available, rng)
		if selected == null:
			break
		var roll := selected.roll(rng, item.item_level)
		if roll != null:
			item.affixes.append(roll)
		if not selected.exclusive_group.is_empty():
			_remove_exclusive_group(available, selected.exclusive_group)

func roll_rarity(wave: int, rng: RandomNumberGenerator) -> ItemEnums.ItemRarity:
	return rarity_roller.roll(wave, rng)

func maximum_rarity_for_wave(wave: int) -> ItemEnums.ItemRarity:
	return rarity_roller.maximum_for_wave(wave)

func affix_count_for_rarity(rarity: ItemEnums.ItemRarity) -> int:
	return clampi(int(rarity), 0, 4)

func _weighted_take(
	available: Array[ItemAffixDefinition],
	rng: RandomNumberGenerator
) -> ItemAffixDefinition:
	var total_weight := 0.0
	for definition in available:
		total_weight += maxf(0.0, definition.weight)
	if total_weight <= 0.0:
		return null
	var roll := rng.randf() * total_weight
	for definition in available:
		roll -= maxf(0.0, definition.weight)
		if roll <= 0.0:
			available.erase(definition)
			return definition
	var fallback: ItemAffixDefinition = available.back()
	available.pop_back()
	return fallback

func _remove_exclusive_group(
	available: Array[ItemAffixDefinition],
	exclusive_group: StringName
) -> void:
	for index in range(available.size() - 1, -1, -1):
		if available[index].exclusive_group == exclusive_group:
			available.remove_at(index)
