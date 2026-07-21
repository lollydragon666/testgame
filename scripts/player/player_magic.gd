class_name PlayerMagic
extends Node

signal cast_requested(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int)
signal magic_changed(spell_kind: StringName, spell_level: int)

# Нулевой уровень означает, что заклинание ещё не выбрано при повышении уровня.
var spell_levels: Dictionary[StringName, int] = {
	GameIds.SPELL_LIGHTNING: 0,
	GameIds.SPELL_FIREBALL: 0,
}
var active_spell: StringName = &""
## Общая перезарядка правой кнопки мыши для выбранного заклинания.
var cooldown := 0.0
var host: PlayerHero

func setup(player_host: PlayerHero) -> void:
	host = player_host

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func try_cast() -> void:
	if host == null or not host.is_alive or active_spell.is_empty() or cooldown > 0.0:
		return
	var spell_level := int(spell_levels[active_spell])
	var spell_damage := 0.0
	match active_spell:
		GameIds.SPELL_LIGHTNING:
			spell_damage = 30.0 + float(spell_level - 1) * 8.0
			cooldown = maxf(0.32, 0.68 - float(spell_level - 1) * 0.04)
		GameIds.SPELL_FIREBALL:
			spell_damage = 42.0 + float(spell_level - 1) * 11.0
			cooldown = maxf(0.48, 0.95 - float(spell_level - 1) * 0.05)
	var origin: Vector2 = host.world_position + host.aim_direction * (float(host.radius) + 14.0)
	cast_requested.emit(active_spell, origin, host.aim_direction, spell_damage, spell_level)

func unlock_or_upgrade(spell_kind: StringName) -> void:
	# Выбранная магия одновременно повышается и становится активной для ПКМ.
	if not spell_levels.has(spell_kind):
		push_error("Unknown player spell: %s" % spell_kind)
		return
	spell_levels[spell_kind] = int(spell_levels[spell_kind]) + 1
	active_spell = spell_kind
	magic_changed.emit(active_spell, int(spell_levels[active_spell]))

func get_spell_level(spell_kind: StringName) -> int:
	return int(spell_levels.get(spell_kind, 0))

func reset() -> void:
	spell_levels[GameIds.SPELL_LIGHTNING] = 0
	spell_levels[GameIds.SPELL_FIREBALL] = 0
	active_spell = &""
	cooldown = 0.0
	magic_changed.emit(active_spell, 0)
