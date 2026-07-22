class_name ItemAffixGenerator
extends RefCounted

var catalog: ItemAffixCatalog

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
	if definition.item_type == ItemEnums.ItemType.CONSUMABLE or catalog == null:
		return
	var available := catalog.compatible(definition.item_type)
	var target_count := mini(affix_count_for_rarity(item.rarity), available.size())
	for _index in target_count:
		var selected := _weighted_take(available, rng)
		if selected == null:
			break
		var roll := selected.roll(rng)
		if roll != null:
			item.affixes.append(roll)

func roll_rarity(wave: int, rng: RandomNumberGenerator) -> ItemEnums.ItemRarity:
	var roll := rng.randf()
	var rarity := ItemEnums.ItemRarity.COMMON
	if roll >= 0.99:
		rarity = ItemEnums.ItemRarity.LEGENDARY
	elif roll >= 0.95:
		rarity = ItemEnums.ItemRarity.EPIC
	elif roll >= 0.85:
		rarity = ItemEnums.ItemRarity.RARE
	elif roll >= 0.60:
		rarity = ItemEnums.ItemRarity.UNCOMMON
	return mini(rarity, maximum_rarity_for_wave(wave)) as ItemEnums.ItemRarity

func maximum_rarity_for_wave(wave: int) -> ItemEnums.ItemRarity:
	if wave <= 3:
		return ItemEnums.ItemRarity.UNCOMMON
	if wave <= 7:
		return ItemEnums.ItemRarity.RARE
	if wave <= 12:
		return ItemEnums.ItemRarity.EPIC
	return ItemEnums.ItemRarity.LEGENDARY

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
