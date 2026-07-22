class_name ItemRarityRoller
extends RefCounted

func roll(
	wave: int,
	rng: RandomNumberGenerator,
	is_elite := false,
	is_boss := false
) -> ItemEnums.ItemRarity:
	if rng == null:
		return ItemEnums.ItemRarity.COMMON
	var rarity := _roll_once(rng)
	if is_elite:
		rarity = maxi(rarity, _roll_once(rng)) as ItemEnums.ItemRarity
	if is_boss:
		rarity = mini(int(rarity) + 1, ItemEnums.ItemRarity.LEGENDARY) as ItemEnums.ItemRarity
	return mini(rarity, maximum_for_wave(wave)) as ItemEnums.ItemRarity

func maximum_for_wave(wave: int) -> ItemEnums.ItemRarity:
	if wave <= 3:
		return ItemEnums.ItemRarity.UNCOMMON
	if wave <= 7:
		return ItemEnums.ItemRarity.RARE
	if wave <= 12:
		return ItemEnums.ItemRarity.EPIC
	return ItemEnums.ItemRarity.LEGENDARY

func affix_count(rarity: ItemEnums.ItemRarity) -> int:
	return clampi(int(rarity), 0, 4)

func _roll_once(rng: RandomNumberGenerator) -> ItemEnums.ItemRarity:
	var value := rng.randf()
	if value >= 0.99:
		return ItemEnums.ItemRarity.LEGENDARY
	if value >= 0.95:
		return ItemEnums.ItemRarity.EPIC
	if value >= 0.85:
		return ItemEnums.ItemRarity.RARE
	if value >= 0.60:
		return ItemEnums.ItemRarity.UNCOMMON
	return ItemEnums.ItemRarity.COMMON
