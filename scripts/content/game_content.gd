class_name GameContent
extends Resource

@export var enemies: Array[EnemyDefinition] = []
@export var spells: Array[SpellDefinition] = []
@export var weapons: Array[WeaponDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []
@export var waves: Array[WaveDefinition] = []
@export var props: Array[PropDefinition] = []
@export var locations: Array[LocationDefinition] = []

func enemy(id: StringName) -> EnemyDefinition:
	for definition in enemies:
		if definition.id == id:
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
	return null

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
