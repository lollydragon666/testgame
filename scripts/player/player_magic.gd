class_name PlayerMagic
extends Node

signal cast_requested(spell_kind: String, origin: Vector2, direction: Vector2, damage: float, spell_level: int)
signal magic_changed(spell_kind: String, spell_level: int)

var spell_levels: Dictionary = {
	"lightning": 0,
	"fireball": 0
}
var active_spell := ""
var cooldown := 0.0
var host

func setup(player_host) -> void:
	host = player_host

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func try_cast() -> void:
	if host == null or not host.is_alive or active_spell.is_empty() or cooldown > 0.0:
		return
	var spell_level := int(spell_levels[active_spell])
	var spell_damage := 0.0
	match active_spell:
		"lightning":
			spell_damage = 30.0 + float(spell_level - 1) * 8.0
			cooldown = maxf(0.32, 0.68 - float(spell_level - 1) * 0.04)
		"fireball":
			spell_damage = 42.0 + float(spell_level - 1) * 11.0
			cooldown = maxf(0.48, 0.95 - float(spell_level - 1) * 0.05)
	var origin: Vector2 = host.world_position + host.aim_direction * (float(host.radius) + 14.0)
	cast_requested.emit(active_spell, origin, host.aim_direction, spell_damage, spell_level)

func unlock_or_upgrade(spell_kind: String) -> void:
	if not spell_levels.has(spell_kind):
		return
	spell_levels[spell_kind] = int(spell_levels[spell_kind]) + 1
	active_spell = spell_kind
	magic_changed.emit(active_spell, int(spell_levels[active_spell]))

func get_spell_level(spell_kind: String) -> int:
	return int(spell_levels.get(spell_kind, 0))

func reset() -> void:
	spell_levels["lightning"] = 0
	spell_levels["fireball"] = 0
	active_spell = ""
	cooldown = 0.0
	magic_changed.emit(active_spell, 0)

