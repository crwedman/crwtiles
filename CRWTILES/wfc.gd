class_name CRWTILES_WFC
extends CRWTILES_WFCKernel
const WFC = CRWTILES_WFC
const MinimumPassageRule = preload("res://CRWTILES/rules/minimum_passage_rule.gd")

@export var growth_limit: int = 200
@export var enforce_minimum_passage_rule := true
@export_range(1, 4, 1) var minimum_passage_width := 2

@export var observe_rules: Array[CRWTILES_Rule] = []
@export var propagate_rules: Array[CRWTILES_Rule] = []

const DisjointSet = CRWTILES_DisjointSet.DisjointSet
var _reachable_set: DisjointSet = DisjointSet.new()
var _propagated_set: DisjointSet
var _propagated = {}
var _root_pos
var _reachable_stack = []
var _cap_ends = false
var _minimum_passage_rule = MinimumPassageRule.new(self )

func _get_modular_rules() -> Array:
	if not enforce_minimum_passage_rule:
		return []

	_minimum_passage_rule.minimum_width = minimum_passage_width
	return [
		_minimum_passage_rule.observe,
	]

func _get_observe_rules():
	var rules = [
		expand.bind(1),
		cap_ends,
		match_edges.bind(true),
	]
	rules.append_array(_get_modular_rules())
	rules.append(fuzz_tiles)
	return rules

func _get_propagate_rules():
	return [
		match_edges
	]

func _is_collapsed_open(cell: Cell) -> bool:
	return cell != null and cell.is_collapsed() and not cell.tiles[0].is_solid()

func _track_propagated_pos(queue: Array, pos: Vector3i) -> void:
	if _propagated.has(pos):
		return

	_propagated[pos] = true
	queue.push_back(pos)

func _process_capped_frontier(observed_pos: Vector3i) -> void:
	if not _cap_ends:
		return

	var queue = _propagated.keys()
	_track_propagated_pos(queue, observed_pos)

	var current = 0
	while current < queue.size():
		var pos: Vector3i = queue[current]
		current += 1

		var cell = at(pos)
		if null == cell:
			continue

		for face in Face.FACES:
			var neighbor_pos = offset(pos, face)
			var had_neighbor = exists_at(neighbor_pos)
			cap_ends(cell, pos, face)
			if not had_neighbor and exists_at(neighbor_pos):
				_track_propagated_pos(queue, neighbor_pos)

func _all_positions() -> Dictionary:
	var positions = {}
	for pos in _cells.keys():
		if exists_at(pos):
			positions[pos] = true

	for frame in _version_stack:
		var frame_cells: Dictionary = frame[CELLS_VERSIONSTACK_INDEX]
		for pos in frame_cells.keys():
			if exists_at(pos):
				positions[pos] = true

	return positions

func _collapsed_open_cells() -> Dictionary:
	var collapsed_open = {}
	for pos in _all_positions().keys():
		var cell = at(pos)
		if _is_collapsed_open(cell):
			collapsed_open[pos] = cell

	return collapsed_open

func _build_open_components(collapsed_open: Dictionary) -> Dictionary:
	for pos in collapsed_open.keys():
		_propagated_set.find(pos)

	for pos in collapsed_open.keys():
		var cell: Cell = collapsed_open[pos]
		var tile: Tile = cell.tiles[0]
		for face in Face.FACES:
			if tile.is_solid(face):
				continue

			var neighbor_pos = offset(pos, face)
			var neighbor: Cell = collapsed_open.get(neighbor_pos)
			if neighbor and not neighbor.tiles[0].is_solid(Face.OPPOSITE[face]):
				_propagated_set.union(pos, neighbor_pos)

	var component_openings = {}
	for pos in collapsed_open.keys():
		var cell: Cell = collapsed_open[pos]
		var tile: Tile = cell.tiles[0]
		var root = _propagated_set.find(pos)
		if not component_openings.has(root):
			component_openings[root] = 0

		for face in Face.FACES:
			if tile.is_solid(face):
				continue

			var neighbor_pos = offset(pos, face)
			var neighbor = at(neighbor_pos)
			if not _is_collapsed_open(neighbor):
				component_openings[root] += 1
				continue
			if neighbor.tiles[0].is_solid(Face.OPPOSITE[face]):
				component_openings[root] += 1

	return component_openings

func _collect_root_reachable_cells() -> Dictionary:
	var reachable = {}
	if null == _root_pos or not exists_at(_root_pos):
		return reachable

	var root_cell = at(_root_pos)
	if null == root_cell:
		return reachable

	var queue = [_root_pos]
	reachable[_root_pos] = true

	var current = 0
	while current < queue.size():
		var pos: Vector3i = queue[current]
		current += 1

		var cell = at(pos)
		if null == cell:
			continue

		for face in Face.FACES:
			if not cell.is_passable(face):
				continue

			var neighbor_pos = offset(pos, face)
			var neighbor = at(neighbor_pos)
			if null == neighbor or not neighbor.is_passable(Face.OPPOSITE[face]):
				continue
			if reachable.has(neighbor_pos):
				continue

			reachable[neighbor_pos] = true
			queue.push_back(neighbor_pos)

	return reachable

func _prune_disconnected_cells() -> int:
	var reachable = _collect_root_reachable_cells()
	if reachable.is_empty():
		return 0

	var removed = {}
	for pos in _all_positions().keys():
		if reachable.has(pos) or not exists_at(pos):
			continue

		remove(pos)
		removed[pos] = null

	if not removed.is_empty():
		_post_update(removed)

	return removed.size()

func _commit_pruned_state() -> void:
	_flatten_search_state()
	_reachable_stack.clear()

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
	_process_capped_frontier(observed_pos)

	var collapsed_open = _collapsed_open_cells()
	if collapsed_open.is_empty():
		return true

	var observed_cell = at(observed_pos)
	if null == _root_pos or not collapsed_open.has(_root_pos):
		if _is_collapsed_open(observed_cell):
			_root_pos = observed_pos
		else:
			_root_pos = collapsed_open.keys()[0]
		print("Root: %s" % [_root_pos])

	var component_openings = _build_open_components(collapsed_open)
	var root = _propagated_set.find(_root_pos)
	var disconnected_components = {}

	for pos in collapsed_open.keys():
		var component = _propagated_set.find(pos)
		if component != root:
			disconnected_components[component] = true

	if _cap_ends:
		if disconnected_components.size() > 0:
			var pruned_count = _prune_disconnected_cells()
			if pruned_count > 0:
				print("pruned disconnected:%s world:%s" % [pruned_count, _world_size])
				_cap_ends = false
				_propagated_set = DisjointSet.new()
				collapsed_open = _collapsed_open_cells()
				if collapsed_open.is_empty():
					_reachable_set = DisjointSet.new()
					_root_pos = null
				else:
					if not collapsed_open.has(_root_pos):
						_root_pos = collapsed_open.keys()[0]
					_build_open_components(collapsed_open)
					_reachable_set = _propagated_set.duplicate()
				_commit_pruned_state()
				return true

		for component in disconnected_components.keys():
			if component_openings.get(component, 0) == 0:
				print("sealed disconnected component:%s" % [component])
				return false

		if component_openings.get(root, 0) == 0 and disconnected_components.size() > 0:
			print("root component closed before reconnection")
			return false

	if len(_uncollapsed) == 0:
		if disconnected_components.size() > 0:
			print("final disconnected open components:%s" % [disconnected_components.size()])
			return false
		if component_openings.get(root, 0) > 0:
			print("final map still open:%s" % [component_openings.get(root, 0)])
			return false

	_reachable_set = _propagated_set.duplicate()

	return true
