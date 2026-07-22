class_name ItemFactory
extends RefCounted

const MINIMUM_ITEM_LEVEL := 1
const MAXIMUM_ITEM_LEVEL := 30

var game_content: GameContent
var affix_generator := ItemAffixGenerator.new()

func configure(content: GameContent) -> void:
	game_content = content
	affix_generator.configure(content.item_affixes if content != null else null)

func create_random_item(
	definition_id: StringName,
	item_level: int,
	rarity: ItemEnums.ItemRarity,
	rng: RandomNumberGenerator
) -> ItemInstance:
	if game_content == null or rng == null:
		return null
	var definition := game_content.item(definition_id)
	if definition == null:
		return null
	var final_rarity := rarity
	if definition.item_type == ItemEnums.ItemType.CONSUMABLE:
		final_rarity = definition.rarity
	var item := ItemInstance.create(definition_id, 1, final_rarity)
	item.item_level = clampi(item_level, MINIMUM_ITEM_LEVEL, MAXIMUM_ITEM_LEVEL)
	item.generated_seed = int(rng.state)
	item.affixes = affix_generator.generate_affixes(
		definition,
		item.rarity,
		item.item_level,
		rng
	)
	if not validate_item_instance(item):
		push_error("ItemFactory generated an invalid item: %s" % definition_id)
		return null
	return item

func create_fixed_item(definition_id: StringName, quantity := 1) -> ItemInstance:
	if game_content == null or quantity <= 0:
		return null
	var definition := game_content.item(definition_id)
	if definition == null:
		return null
	var final_quantity := quantity if definition.stackable else 1
	var item := ItemInstance.create(definition_id, final_quantity, definition.rarity)
	item.item_level = MINIMUM_ITEM_LEVEL
	item.generated_seed = 0
	if not validate_item_instance(item):
		return null
	return item

func validate_item_instance(item: ItemInstance) -> bool:
	if item == null or game_content == null:
		return false
	if item.instance_id.is_empty() or item.quantity <= 0:
		return false
	var definition := game_content.item(item.definition_id)
	if definition == null:
		return false
	if not definition.stackable and item.quantity != 1:
		return false
	if item.rarity < ItemEnums.ItemRarity.COMMON or item.rarity > ItemEnums.ItemRarity.LEGENDARY:
		return false
	if item.item_level < MINIMUM_ITEM_LEVEL or item.item_level > MAXIMUM_ITEM_LEVEL:
		return false
	if item.affixes.size() > affix_generator.affix_count_for_rarity(item.rarity):
		return false
	if definition.item_type == ItemEnums.ItemType.CONSUMABLE and not item.affixes.is_empty():
		return false
	var seen_ids: Dictionary[StringName, bool] = {}
	var seen_groups: Dictionary[StringName, bool] = {}
	for roll in item.affixes:
		if roll == null or roll.affix_id.is_empty() or seen_ids.has(roll.affix_id):
			return false
		if not is_finite(roll.value):
			return false
		var affix_definition := game_content.item_affix(roll.affix_id)
		if affix_definition == null or not affix_definition.supports(definition, item.item_level):
			return false
		if not affix_definition.exclusive_group.is_empty():
			if seen_groups.has(affix_definition.exclusive_group):
				return false
			seen_groups[affix_definition.exclusive_group] = true
		seen_ids[roll.affix_id] = true
	return true
