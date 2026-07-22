class_name ItemAffixGenerator
extends RefCounted

const MAX_AFFIX_ATTEMPTS := 100

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
	item.item_level = clampi(wave, 1, 30)
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
	item.affixes = generate_affixes(definition, item.rarity, item.item_level, rng)

func generate_affixes(
	definition: ItemDefinition,
	rarity: ItemEnums.ItemRarity,
	item_level: int,
	rng: RandomNumberGenerator
) -> Array[ItemAffixRoll]:
	var result: Array[ItemAffixRoll] = []
	if definition == null or rng == null or catalog == null:
		return result
	if definition.item_type == ItemEnums.ItemType.CONSUMABLE:
		return result
	var available := catalog.compatible(definition, item_level)
	var target_count := affix_count_for_rarity(rarity)
	var attempts := 0
	while result.size() < target_count and not available.is_empty() and attempts < MAX_AFFIX_ATTEMPTS:
		attempts += 1
		var selected := _weighted_take(available, rng)
		if selected == null:
			break
		var roll := selected.roll(rng, item_level)
		if roll != null:
			result.append(roll)
		if not selected.exclusive_group.is_empty():
			_remove_exclusive_group(available, selected.exclusive_group)
	if result.size() < target_count and OS.is_debug_build():
		push_warning(
			"Generated %d of %d requested affixes for %s at item level %d"
			% [result.size(), target_count, definition.id, item_level]
		)
	return result

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
