class_name PlayerMagic
extends Node

signal cast_requested(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int)
signal magic_changed(spell_kind: StringName, spell_level: int)

# Оставлено как совместимый верхний предел для старых тестов; реальные лимиты лежат в SpellDefinition.
const MAX_SPELL_LEVEL := 6

var spell_levels: Dictionary[StringName, int] = {}
var active_spell: StringName = &""
var cooldown := 0.0
var host: PlayerHero
var game_content: GameContent

func setup(player_host: PlayerHero, content: GameContent) -> void:
	host = player_host
	game_content = content
	reset()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func try_cast() -> void:
	if host == null or not host.is_alive or active_spell.is_empty() or cooldown > 0.0:
		return
	var definition := game_content.spell(active_spell)
	if definition == null:
		push_error("Unknown player spell: %s" % active_spell)
		return
	var spell_level := int(spell_levels[active_spell])
	var spell_damage := effective_spell_damage(active_spell)
	cooldown = effective_spell_cooldown(active_spell)
	var origin := host.world_position + host.aim_direction * (host.collision_radius + 14.0)
	cast_requested.emit(active_spell, origin, host.aim_direction, spell_damage, spell_level)

func unlock_or_upgrade(spell_kind: StringName) -> bool:
	if not can_upgrade_spell(spell_kind):
		return false
	spell_levels[spell_kind] = int(spell_levels[spell_kind]) + 1
	active_spell = spell_kind
	magic_changed.emit(active_spell, int(spell_levels[active_spell]))
	return true

func can_upgrade_spell(spell_kind: StringName) -> bool:
	var definition := game_content.spell(spell_kind) if game_content != null else null
	return definition != null and spell_levels.has(spell_kind) and int(spell_levels[spell_kind]) < definition.max_level

func get_spell_level(spell_kind: StringName) -> int:
	return int(spell_levels.get(spell_kind, 0))

func effective_spell_damage(spell_kind: StringName) -> float:
	var definition := game_content.spell(spell_kind) if game_content != null else null
	if definition == null:
		return 0.0
	var level_offset := float(maxi(1, get_spell_level(spell_kind)) - 1)
	var base_value := definition.base_damage + level_offset * definition.damage_per_level
	return base_value * (host.power_multiplier if host != null else 1.0)

func effective_spell_cooldown(spell_kind: StringName) -> float:
	var definition := game_content.spell(spell_kind) if game_content != null else null
	if definition == null:
		return 0.0
	var level_offset := float(maxi(1, get_spell_level(spell_kind)) - 1)
	var leveled_cooldown := definition.base_cooldown - level_offset * definition.cooldown_reduction_per_level
	var haste_multiplier := host.haste_cooldown_multiplier if host != null else 1.0
	return maxf(definition.minimum_cooldown, leveled_cooldown * haste_multiplier)

func reset() -> void:
	spell_levels.clear()
	if game_content != null:
		for definition in game_content.spells:
			spell_levels[definition.id] = 0
	active_spell = &""
	cooldown = 0.0
	magic_changed.emit(active_spell, 0)
