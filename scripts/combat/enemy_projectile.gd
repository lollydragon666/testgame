class_name EnemyProjectile
extends DeflectableProjectile

var velocity := Vector2.ZERO
var damage := 12.0
var player: PlayerHero
var lifetime := 6.0

func _init() -> void:
	visual_radius = 20.0
	collision_radius = 14.0

func _ready() -> void:
	add_to_group("enemy_projectile")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func setup(player_target: PlayerHero, origin: Vector2, direction: Vector2, projectile_damage: float) -> void:
	player = player_target
	world_position = origin
	velocity = direction.normalized() * 280.0
	damage = projectile_damage

func _physics_process(delta: float) -> void:
	lifetime -= delta
	var previous_position := world_position
	var next_position := world_position + velocity * delta
	if world_state != null and world_state.is_position_blocked(next_position, collision_radius):
		queue_free()
		return
	world_position = next_position
	update_spatial_index()
	position = IsoMath.world_to_screen(world_position)
	if lifetime <= 0.0:
		queue_free()
		return
	if player != null:
		var hit_fraction := CollisionMath.segment_circle_hit_fraction(
			previous_position,
			next_position,
			player.world_position,
			collision_radius + player.collision_radius
		)
		if hit_fraction >= 0.0:
			world_position = previous_position.lerp(next_position, hit_fraction)
			update_spatial_index()
			position = IsoMath.world_to_screen(world_position)
			player.take_damage(damage)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	var direction := IsoMath.world_to_screen(velocity.normalized()).normalized()
	var side := direction.orthogonal()
	var tip := direction * visual_radius
	var shaft_end := tip - direction * 9.0
	var tail := direction * -visual_radius * 0.9
	var red := Color("af3029")
	draw_line(tail, shaft_end, red, 5.0)
	draw_colored_polygon(PackedVector2Array([
		tip,
		shaft_end + side * 8.0,
		shaft_end - side * 8.0
	]), red)
	draw_line(tail, tail + direction * 9.0 + side * 7.0, red, 3.0)
	draw_line(tail, tail + direction * 9.0 - side * 7.0, red, 3.0)
	draw_circle(tip, 2.2, Color("d4c4a4"))
