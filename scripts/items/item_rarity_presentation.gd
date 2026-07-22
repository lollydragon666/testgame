class_name ItemRarityPresentation
extends RefCounted

const COLORS: Array[Color] = [
	Color("c6c3bb"),
	Color("73b86b"),
	Color("5f91d8"),
	Color("a477d4"),
	Color("d99045"),
]
const NAMES: Array[String] = [
	"Обычный",
	"Необычный",
	"Редкий",
	"Эпический",
	"Легендарный",
]

static func color(rarity: ItemEnums.ItemRarity) -> Color:
	return COLORS[clampi(int(rarity), ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY)]

static func color_html(rarity: ItemEnums.ItemRarity) -> String:
	return color(rarity).to_html(false)

static func rarity_name(rarity: ItemEnums.ItemRarity) -> String:
	return NAMES[clampi(int(rarity), ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY)]

static func display_name(item: ItemInstance, definition: ItemDefinition) -> String:
	return definition.display_name if item != null and definition != null else ""

static func format_affix(roll: ItemAffixRoll, content: GameContent) -> String:
	if roll == null or content == null:
		return ""
	var definition := content.item_affix(roll.affix_id)
	if definition == null:
		return String(roll.affix_id)
	var value_pattern := "%+." + String.num_int64(definition.decimals) + "f"
	var value_text := value_pattern % roll.value
	if definition.percentage:
		value_text = "%+.1f%%" % (roll.value * 100.0)
	return "%s: %s" % [definition.display_name, value_text]
