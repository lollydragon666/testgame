class_name RandomItemDebugCommand
extends RefCounted

const COMMAND := "spawn_random_item"

static func execute(
	command_text: String,
	inventory: InventoryService,
	content: GameContent
) -> ItemInstance:
	if not OS.is_debug_build() or inventory == null or content == null:
		return null
	var parts := command_text.strip_edges().split(" ", false)
	if parts.size() != 5 or parts[0] != COMMAND:
		return null
	var definition_id := StringName(parts[1])
	var definition := content.item(definition_id)
	if definition == null or not parts[2].is_valid_int() or not parts[4].is_valid_int():
		return null
	var rarity := _parse_rarity(parts[3])
	if rarity < 0:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = int(parts[4])
	var factory := ItemFactory.new()
	factory.configure(content)
	var item := factory.create_random_item(definition_id, int(parts[2]), rarity as ItemEnums.ItemRarity, rng)
	if item == null or not inventory.add_item(item):
		return null
	return item

static func _parse_rarity(value: String) -> int:
	match value.to_lower():
		"common", "обычный": return ItemEnums.ItemRarity.COMMON
		"uncommon", "необычный": return ItemEnums.ItemRarity.UNCOMMON
		"rare", "редкий": return ItemEnums.ItemRarity.RARE
		"epic", "эпический": return ItemEnums.ItemRarity.EPIC
		"legendary", "легендарный": return ItemEnums.ItemRarity.LEGENDARY
	return -1
