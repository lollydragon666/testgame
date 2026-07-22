class_name GameContent
extends Resource

@export var enemies: Array[EnemyDefinition] = []
@export var enemy_spawn_groups: Array[EnemySpawnGroupDefinition] = []
@export var spells: Array[SpellDefinition] = []
@export var weapons: Array[WeaponDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []
@export var waves: Array[WaveDefinition] = []
@export var props: Array[PropDefinition] = []
@export var locations: Array[LocationDefinition] = []
@export var item_catalog: ItemCatalog
@export var shops: Array[ShopDefinition] = []
@export var loot_tables: Array[LootTable] = []
@export var item_affixes: ItemAffixCatalog

func enemy(id: StringName) -> EnemyDefinition:
	for definition in enemies:
		if definition.id == id:
			return definition
	return null

func enemy_spawn_group(id: StringName) -> EnemySpawnGroupDefinition:
	for definition in enemy_spawn_groups:
		if definition != null and definition.id == id:
			return definition
	return null

func spell(id: StringName) -> SpellDefinition:
	for definition in spells:
		if definition.id == id:
			return definition
	return null

func weapon(id: StringName) -> WeaponDefinition:
	for definition in weapons:
		if definition.id == id:
			return definition
	var item_definition := item(id)
	if item_definition is WeaponDefinition:
		return item_definition as WeaponDefinition
	return null

func item(id: StringName) -> ItemDefinition:
	return item_catalog.definition(id) if item_catalog != null else null

func all_items() -> Array[ItemDefinition]:
	return item_catalog.all_definitions() if item_catalog != null else []

func shop(id: StringName) -> ShopDefinition:
	for definition in shops:
		if definition != null and definition.id == id:
			return definition
	return null

func loot_table(id: StringName) -> LootTable:
	for definition in loot_tables:
		if definition != null and definition.id == id:
			return definition
	return null

func item_affix(id: StringName) -> ItemAffixDefinition:
	return item_affixes.definition(id) if item_affixes != null else null

func upgrade(id: StringName) -> UpgradeDefinition:
	for definition in upgrades:
		if definition.id == id:
			return definition
	return null

func wave(number: int) -> WaveDefinition:
	for definition in waves:
		if definition.number == number:
			return definition
	return null

func prop(id: StringName) -> PropDefinition:
	for definition in props:
		if definition.id == id:
			return definition
	return null

func location(id: StringName) -> LocationDefinition:
	for definition in locations:
		if definition != null and definition.id == id:
			return definition
	return null

func validate_locations() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for definition in locations:
		if definition == null:
			errors.append("location entry is null")
			continue
		if seen.has(definition.id):
			errors.append("duplicate location ID: %s" % definition.id)
		seen[definition.id] = true
		for location_error in definition.validate_definition():
			errors.append("location %s: %s" % [definition.id, location_error])
		var final_tier := definition.tier_definition(definition.maximum_tier())
		if final_tier == null or final_tier.tier != LocationDefinition.EXPECTED_TIER_COUNT:
			errors.append("location %s has no tier 10" % definition.id)
		elif final_tier.boss_id.is_empty() or enemy(final_tier.boss_id) == null:
			errors.append("location %s tier 10 references an unknown boss" % definition.id)
	return errors

func wave_count() -> int:
	return waves.size()
