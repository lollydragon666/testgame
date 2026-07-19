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
var swing_direction := 1.0
var next_swing_direction := 1.0
var swing_aim_direction := Vector2.RIGHT
var previous_swing_offset := 0.0
var hit_targets: Dictionary = {}
var host

func setup(player_host) -> void:
	host = player_host

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if swing_time > 0.0:
		swing_time = maxf(0.0, swing_time - delta)
		var current_offset := swing_offset() if swing_time > 0.0 else swing_end_offset()
		_hit_groups_between(previous_swing_offset, current_offset)
		previous_swing_offset = current_offset
		if host != null:
			host.queue_redraw()

func try_attack() -> void:
	if host == null or cooldown > 0.0 or not host.is_alive:
		return
	cooldown = cooldown_duration
	swing_time = swing_duration
	swing_direction = next_swing_direction
	next_swing_direction *= -1.0
	swing_aim_direction = host.aim_direction
	previous_swing_offset = swing_start_offset()
	hit_targets.clear()
	attack_started.emit()
	_hit_groups_between(previous_swing_offset, previous_swing_offset)
	host.queue_redraw()

func _hit_groups_between(from_offset: float, to_offset: float) -> void:
	_hit_group_between(&"enemy", &"take_damage", from_offset, to_offset)
	_hit_group_between(&"enemy_projectile", &"destroy_by_sword", from_offset, to_offset)
	_hit_group_between(&"destructible", &"hit_by_sword", from_offset, to_offset)

func _hit_group_between(group_name: StringName, method_name: StringName, from_offset: float, to_offset: float) -> void:
	for target in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(target) or not target.has_method(method_name):
			continue
		var target_id := target.get_instance_id()
		if hit_targets.has(target_id):
			continue
		var target_radius: float = target.get("hit_radius") if target.get("hit_radius") != null else 8.0
		if group_name == &"enemy_projectile":
			target_radius += 7.0
		var target_position: Vector2 = target.get("world_position")
		if point_in_blade_sweep(target_position, target_radius, from_offset, to_offset):
			hit_targets[target_id] = true
			if method_name == &"take_damage":
				target.call(method_name, damage, swing_aim_direction)
			else:
				target.call(method_name)

func point_in_sweep(target_world_position: Vector2, target_radius: float = 0.0) -> bool:
	return point_in_blade_sweep(target_world_position, target_radius, SWEEP_START, SWEEP_END)

func point_in_blade_sweep(target_world_position: Vector2, target_radius: float, from_offset: float, to_offset: float) -> bool:
	var relative_screen := IsoMath.world_to_screen(target_world_position - host.world_position)
	var screen_distance := relative_screen.length()
	var blade_half_width := 5.0 + float(sword_tier) * 0.8
	var collision_radius := maxf(0.0, target_radius) * 1.05 + blade_half_width
	var guard_distance: float = float(host.radius) + (18.0 if sword_tier == 6 else 6.0)
	var blade_base := guard_distance + 5.0
	if screen_distance + collision_radius < blade_base:
		return false
	if screen_distance - collision_radius > sword_length:
		return false
	var base_angle := IsoMath.screen_angle(swing_aim_direction)
	var delta_angle := wrapf(relative_screen.angle() - base_angle, -PI, PI)
	var angular_padding := 0.08
	if screen_distance > 1.0:
		angular_padding = asin(minf(0.72, collision_radius / screen_distance))
	var minimum_offset := minf(from_offset, to_offset) - angular_padding
	var maximum_offset := maxf(from_offset, to_offset) + angular_padding
	return delta_angle >= minimum_offset and delta_angle <= maximum_offset

func swing_offset() -> float:
	if swing_time <= 0.0:
		return 0.0
	var progress := 1.0 - swing_time / swing_duration
	var eased_progress := ease(progress, -2.5)
	return lerpf(swing_start_offset(), swing_end_offset(), eased_progress)

func swing_start_offset() -> float:
	return SWEEP_START if swing_direction > 0.0 else SWEEP_END

func swing_end_offset() -> float:
	return SWEEP_END if swing_direction > 0.0 else SWEEP_START

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
	swing_direction = 1.0
	next_swing_direction = 1.0
	swing_aim_direction = Vector2.RIGHT
	previous_swing_offset = 0.0
	hit_targets.clear()
