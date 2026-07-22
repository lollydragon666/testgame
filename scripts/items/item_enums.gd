class_name ItemEnums
extends RefCounted

enum ItemType { WEAPON, ARMOR, JEWELRY, CONSUMABLE }
enum EquipmentSlot { NONE, WEAPON, ARMOR, AMULET, RING, RING_1, RING_2, CONSUMABLE_2, CONSUMABLE_3 }
enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum ConsumableEffectType { HEAL, DAMAGE_BOOST, DEFENSE_BOOST, ATTACK_SPEED_BOOST, MOVEMENT_SPEED_BOOST }
enum ItemStatType {
	DAMAGE_FLAT,
	DAMAGE_PERCENT,
	DEFENSE_FLAT,
	MAX_HEALTH_FLAT,
	ATTACK_SPEED_PERCENT,
	MOVEMENT_SPEED_PERCENT,
	ATTACK_REACH_PERCENT,
	ATTACK_WIDTH_PERCENT,
	CRITICAL_CHANCE,
	CRITICAL_DAMAGE,
	LOOT_CHANCE,
}

# Compatibility alias for save/debug code written before randomized items were expanded.
const StatType = ItemStatType

const SWORD_CLASS := &"sword"

static func rarity_name(value: ItemRarity) -> String:
	return ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный"][clampi(value, ItemRarity.COMMON, ItemRarity.LEGENDARY)]

static func item_type_name(value: ItemType) -> String:
	return ["Оружие", "Броня", "Бижутерия", "Расходники"][clampi(value, ItemType.WEAPON, ItemType.CONSUMABLE)]
