class_name GameContent
extends Resource

@export var enemies: Array[EnemyDefinition] = []
@export var spells: Array[SpellDefinition] = []
@export var weapons: Array[WeaponDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []
@export var waves: Array[WaveDefinition] = []
@export var props: Array[PropDefinition] = []

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

func wave_count() -> int:
	return waves.size()
