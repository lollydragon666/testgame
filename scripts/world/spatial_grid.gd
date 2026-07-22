class_name SpatialGrid
extends RefCounted

var cell_size := 180.0
var _cells: Dictionary[Vector2i, Array] = {}
var _object_cells: Dictionary[int, Vector2i] = {}

func configure(value: float) -> void:
	cell_size = maxf(1.0, value)

func insert(object: Object, world_position: Vector2) -> void:
	if object == null:
		return
	var object_id := object.get_instance_id()
	if _object_cells.has(object_id):
		update(object, world_position)
		return
	var cell := _cell_for(world_position)
	var bucket: Array = _cells.get(cell, [])
	bucket.append(object)
	_cells[cell] = bucket
	_object_cells[object_id] = cell

func update(object: Object, world_position: Vector2) -> void:
	if object == null:
		return
	var object_id := object.get_instance_id()
	var next_cell := _cell_for(world_position)
	if not _object_cells.has(object_id):
		insert(object, world_position)
		return
	var previous_cell: Vector2i = _object_cells[object_id]
	if previous_cell == next_cell:
		return
	_remove_from_cell(object, previous_cell)
	var bucket: Array = _cells.get(next_cell, [])
	bucket.append(object)
	_cells[next_cell] = bucket
	_object_cells[object_id] = next_cell

func remove(object: Object) -> void:
	if object == null:
		return
	var object_id := object.get_instance_id()
	if not _object_cells.has(object_id):
		return
	var cell: Vector2i = _object_cells[object_id]
	_remove_from_cell(object, cell)
	_object_cells.erase(object_id)

func query(world_position: Vector2, radius: float) -> Array[Object]:
	var result: Array[Object] = []
	query_into(world_position, radius, result)
	return result

func query_into(world_position: Vector2, radius: float, output: Array) -> void:
	output.clear()
	var center := _cell_for(world_position)
	var cell_radius := ceili(maxf(0.0, radius) / cell_size)
	for x_offset in range(-cell_radius, cell_radius + 1):
		for y_offset in range(-cell_radius, cell_radius + 1):
			var cell := center + Vector2i(x_offset, y_offset)
			if not _cells.has(cell):
				continue
			var bucket: Array = _cells[cell]
			for object in bucket:
				if is_instance_valid(object):
					output.append(object)

func clear() -> void:
	_cells.clear()
	_object_cells.clear()

func cell_count() -> int:
	return _cells.size()

func _cell_for(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))

func _remove_from_cell(object: Object, cell: Vector2i) -> void:
	var bucket: Array = _cells.get(cell, [])
	bucket.erase(object)
	if bucket.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = bucket
