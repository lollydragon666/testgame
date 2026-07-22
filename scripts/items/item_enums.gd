class_name ItemEnums
extends RefCounted

enum ItemType { WEAPON, ARMOR, JEWELRY, CONSUMABLE }
enum EquipmentSlot { NONE, WEAPON, ARMOR, AMULET, RING, RING_1, RING_2, CONSUMABLE_2, CONSUMABLE_3 }
enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum ConsumableEffectType { HEAL, DAMAGE_BOOST, DEFENSE_BOOST, ATTACK_SPEED_BOOST, MOVEMENT_SPEED_BOOST }
enum StatType { DAMAGE, DEFENSE, MAX_HEALTH, MOVEMENT_SPEED, ATTACK_SPEED, CRITICAL_CHANCE, CRITICAL_DAMAGE, LOOT_CHANCE }

const SWORD_CLASS := &"sword"

static func rarity_name(value: ItemRarity) -> String:
	return ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный"][clampi(value, ItemRarity.COMMON, ItemRarity.LEGENDARY)]

static func item_type_name(value: ItemType) -> String:
	return ["Оружие", "Броня", "Бижутерия", "Расходники"][clampi(value, ItemType.WEAPON, ItemType.CONSUMABLE)]
