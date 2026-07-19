class_name PlayerAttack
extends Node

signal attack_started

const SWEEP_START := -1.22
const SWEEP_END := 1.04

@export var damage := 34.0
@export var sword_length := 91.0
@export var cooldown_duration := 0.36
@export var swing_duration := 0.28

var sword_tier := 1
var cooldown := 0.0
var swing_time := 0.0
var host

func setup(player_host) -> void:
	host = player_host

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	swing_time = maxf(0.0, swing_time - delta)
	if host != null and swing_time > 0.0:
		host.queue_redraw()

func try_attack() -> void:
	if host == null or cooldown > 0.0 or not host.is_alive:
		return
	cooldown = cooldown_duration
	swing_time = swing_duration
	attack_started.emit()
	_hit_group("enemy", "take_damage")
	_hit_group("enemy_projectile", "destroy_by_sword")
	_hit_group("destructible", "hit_by_sword")
	host.queue_redraw()

func _hit_group(group_name: StringName, method_name: StringName) -> void:
	for target in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(target) or not target.has_method(method_name):
			continue
		var target_radius: float = target.get("hit_radius") if target.get("hit_radius") != null else 8.0
		var target_position: Vector2 = target.get("world_position")
		if point_in_sweep(target_position, target_radius):
			if method_name == &"take_damage":
				target.call(method_name, damage, host.aim_direction)
			else:
				target.call(method_name)

func point_in_sweep(target_world_position: Vector2, target_radius: float = 0.0) -> bool:
	var relative_screen := IsoMath.world_to_screen(target_world_position - host.world_position)
	var screen_distance := relative_screen.length()
	var target_screen_radius := maxf(0.0, target_radius) * 1.05
	var blade_base := host.radius + 11.0
	if screen_distance + target_screen_radius < blade_base:
		return false
	if screen_distance - target_screen_radius > sword_length:
		return false
	var base_angle := IsoMath.screen_angle(host.aim_direction)
	var delta_angle := wrapf(relative_screen.angle() - base_angle, -PI, PI)
	var angular_padding := 0.36
	if screen_distance > 1.0:
		angular_padding = asin(minf(0.36, target_screen_radius / screen_distance))
	return delta_angle >= SWEEP_START - angular_padding and delta_angle <= SWEEP_END + angular_padding

func swing_offset() -> float:
	if swing_time <= 0.0:
		return 0.0
	var progress := 1.0 - swing_time / swing_duration
	return lerpf(SWEEP_START, SWEEP_END, ease(progress, -2.5))

func upgrade_sword() -> void:
	sword_length += 11.0
	damage += 2.0
	sword_tier = mini(6, sword_tier + 1)
	if sword_tier == 6:
		sword_length += 8.0
		damage += 2.0

func reset() -> void:
	damage = 34.0
	sword_length = 91.0
	sword_tier = 1
	cooldown = 0.0
	swing_time = 0.0

