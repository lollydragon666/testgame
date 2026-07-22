class_name EnemyAttackController
extends RefCounted

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

var phase := Phase.IDLE
var phase_remaining := 0.0
var cooldown_remaining := 0.0
var windup := 0.25
var active_time := 0.08
var recovery := 0.30
var cooldown := 1.4

func configure(definition: EnemyDefinition) -> void:
	windup = maxf(0.0, definition.attack_windup)
	active_time = maxf(0.01, definition.attack_active_time)
	recovery = maxf(0.0, definition.attack_recovery)
	cooldown = maxf(0.0, definition.attack_cooldown)
	reset()

func try_start() -> bool:
	if phase != Phase.IDLE or cooldown_remaining > 0.0:
		return false
	phase = Phase.WINDUP
	phase_remaining = windup
	return true

func tick(delta: float, speed_multiplier := 1.0) -> bool:
	var scaled_delta := delta * maxf(0.01, speed_multiplier)
	cooldown_remaining = maxf(0.0, cooldown_remaining - scaled_delta)
	if phase == Phase.IDLE:
		return false
	phase_remaining = maxf(0.0, phase_remaining - scaled_delta)
	if phase_remaining > 0.0:
		return false
	match phase:
		Phase.WINDUP:
			phase = Phase.ACTIVE
			phase_remaining = active_time
			return true
		Phase.ACTIVE:
			phase = Phase.RECOVERY
			phase_remaining = recovery
		Phase.RECOVERY:
			phase = Phase.IDLE
			cooldown_remaining = cooldown
	return false

func is_busy() -> bool:
	return phase != Phase.IDLE

func reset() -> void:
	phase = Phase.IDLE
	phase_remaining = 0.0
	cooldown_remaining = 0.0
