class_name CRWTILES_WFC
extends CRWTILES_WFCKernel
const WFC = CRWTILES_WFC

@export var growth_limit: int = 100

const DisjointSet = CRWTILES_DisjointSet.DisjointSet
var _reachable_set: DisjointSet = DisjointSet.new()
var _propagated_set: DisjointSet
var _propagated = {}
var _root_pos
var _reachable_stack = []
var _cap_ends = false

func _get_observe_rules():
	return [
		expand.bind(1),
		cap_ends,
		match_edges.bind(true),
		fuzz_tiles,
	]

func _get_propagate_rules():
	return [
		match_edges
	]

func fuzz_tiles(cell: Cell, _pos: Vector3i, _face: int) -> bool:
	cell._randomize_tiles(_rng)
	return true

func cap_ends(cell: Cell, pos: Vector3i, face: int) -> bool:
	if not _cap_ends:
		return true

	var neighbor_pos = offset(pos, face)
	if not exists_at(neighbor_pos) and not cell.is_solid(face):
		var tiles = atlas.tiles
		if not exists_at(offset(neighbor_pos, face)):
			tiles = tiles.filter(func(t: Tile): return t.is_solid(face))
		for perp_face in Face.FACES.filter(func(f): return f != face and f != Face.OPPOSITE[f]):
			if cell.is_solid(perp_face):
				tiles = tiles.filter(func(t: Tile): return t.is_solid(perp_face))
		update(neighbor_pos, tiles)
	return true

func match_edges(cell: Cell, pos: Vector3i, face: int, block_empty = false) -> bool:
	var neighbor = at(pos + Face.OFFSETS[face])
	if neighbor:
		cell.tiles = Cell.potential_matches(cell.tiles, face, neighbor.tiles)
	elif block_empty and not _cap_ends:
		cell.tiles = cell.tiles.filter(func(t: Tile): return t.is_solid(face))
	return true

func expand(cell: Cell, pos: Vector3i, face: int, siz = 1) -> bool:
	if _world_size > growth_limit:
		return true

	var new_cells = []
	var perp_faces = Face.FACES.filter(func(f): return f != face and f != Face.OPPOSITE[face])
	var next_pos = pos
	for n in range(siz):
		next_pos = offset(next_pos, face)
		for perp_face in perp_faces:
			var perp_pos = offset(next_pos, perp_face)
			if cell.is_passable(perp_face):
				new_cells.append(perp_pos)

	var min_x = pos.x
	var max_x = pos.x
	var min_z = pos.z
	var max_z = pos.z
	var min_y = pos.y
	var max_y = pos.y
	for new_pos in new_cells:
		if not exists_at(new_pos):
			if new_pos.x < min_x: min_x = new_pos.x
			if new_pos.x > max_x: max_x = new_pos.x
			if new_pos.z < min_z: min_z = new_pos.z
			if new_pos.z > max_z: max_z = new_pos.z
			if new_pos.y < min_y: min_y = new_pos.y
			if new_pos.y > max_y: max_y = new_pos.y

	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			for y in range(min_y, max_y + 1):
				var new_pos = Vector3i(x, y, z)
				if not exists_at(new_pos):
					update(new_pos, atlas.tiles)

	return true

func _snapshot():
	super._snapshot()
	var data = []
	data.push_back(_reachable_set)
	data.push_back(_root_pos)
	data.push_back(_cap_ends)
	_reachable_stack.push_back(data)
	_reachable_set = _reachable_set.duplicate()

func _restore() -> bool:
	if not super._restore():
		return false
	var previous = _reachable_stack.pop_back()
	_cap_ends = previous.pop_back()
	_root_pos = previous.pop_back()
	_reachable_set = previous.pop_back()
	return true

func _commit():
	super._commit()
	if _reachable_stack.size() > 0:
		_reachable_stack.pop_back()

func _pre_propagate(_pos: Vector3i) -> bool:
	_propagated_set = _reachable_set.duplicate()
	_propagated = _uncollapsed.duplicate()
	if _world_size > growth_limit:
		_cap_ends = true
	return true

func _post_propagate(observed_pos):
	var to_update = _propagated.keys()
	for pos in to_update:
		var cell = at(pos)
		for face in Face.FACES:
			if cell.is_passable(face):
				_propagated_set.union(pos, offset(pos, face))
			if _cap_ends:
				cap_ends(cell, pos, face)

	var tile: Tile = at(observed_pos).tiles[0]
	for face in Face.FACES:
		if not tile.is_solid():
			_propagated_set.union(observed_pos, observed_pos + Face.OFFSETS[face])

	if _root_pos != null:
		var root = _propagated_set.find(_root_pos)

		if not tile.is_solid() and root != _propagated_set.find(observed_pos):
			print("observed unreachable:%s" % [observed_pos])
			#return false
			pass # XXX

		for pos in to_update:
			var cell = at(pos)
			var my_root = _propagated_set.find(pos)
			if not cell.is_solid() and root != my_root:
				#print("propagated unreachable:%s" % [pos])
				#return false
				#update(pos, [atlas.solid_tile])
				pass # XXX

		# finally, update the collapsed cell
		for face in Face.FACES:
			if not tile.is_solid(face):
				_reachable_set.union(observed_pos, observed_pos + Face.OFFSETS[face])

	if null == _root_pos:
		_root_pos = observed_pos
		print("Root: %s" % [_root_pos])

	return true
