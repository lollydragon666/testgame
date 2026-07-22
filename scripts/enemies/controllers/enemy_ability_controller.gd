class_name EnemyAbilityController
extends RefCounted

var cooldown := 0.0
var remaining := 0.0

func configure(cooldown_duration: float) -> void:
	cooldown = maxf(0.0, cooldown_duration)
	remaining = 0.0

func tick(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

func consume() -> bool:
	if remaining > 0.0:
		return false
	remaining = cooldown
	return true

func ready() -> bool:
	return remaining <= 0.0
