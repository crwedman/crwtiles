class_name CRWTILES_WFCKernel
extends Node

const Face = CRWTILES_Face.Face
const Socket = CRWTILES_Socket.Socket
const Tile = CRWTILES_Tile.Tile
const Cell = CRWTILES_Cell.Cell
const TileAtlasResource = CRWTILES_TileAtlasResource.TileAtlasResource

var atlas: TileAtlasResource
@export var max_retries = 3
@export var max_failures = 500

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0

var _version_stack: Array[Array] = []
var _cells: Dictionary[Vector3i, Cell] = {}
var _uncollapsed: Dictionary[Vector3i, bool] = {}
var _retries = 0
var _fail_count = 0
var _world_size = 0

var _step_by_step = false
var _updates_mutex = Mutex.new()
var updates_semaphore = Semaphore.new()
var resume_semaphore = Semaphore.new()

func _init(tile_atlas: CRWTILES_TileAtlasResource, seed_value = 0):
	_seed = seed_value
	_rng.seed = hash(_seed)
	atlas = tile_atlas

func _get_observe_rules(): return []
func _get_propagate_rules(): return []

func size(): return _world_size

const CELLS_VERSIONSTACK_INDEX = 0
func _snapshot() -> void:
	var previous = [
		_cells,
		_uncollapsed,
		_retries,
		_world_size
	]
	_version_stack.push_back(previous)
	_cells = {}
	_uncollapsed = _uncollapsed.duplicate()

func _restore() -> bool:
	if _version_stack.size() == 0:
		return false

	var previous = _version_stack.pop_back()

	var curr_cells = _cells

	_world_size = previous.pop_back()
	_retries = previous.pop_back()
	_retries += 1
	_uncollapsed = previous.pop_back()
	_cells = previous.pop_back()

	_post_update(curr_cells)

	return true

func _commit() -> void:
	if _version_stack.size() > 0:
		var previous = _version_stack.pop_back()
		_cells.merge(previous[CELLS_VERSIONSTACK_INDEX])
		_retries = 1

var _info = {}
func get_all_updates() -> Dictionary:
	var info
	_updates_mutex.lock()
	info = _info
	_info = {}
	_updates_mutex.unlock()
	return info

func _post_update(cells):
	_updates_mutex.lock()
	for pos in cells:
		var cell = Cell.new(cells[pos].tiles)
		_info[pos] = cell
	_updates_mutex.unlock()

	if _step_by_step:
		updates_semaphore.post()
		resume_semaphore.wait()
	else:
		updates_semaphore.post()

var _is_paused = false
var pause_semaphore = Semaphore.new()
var unpause_semaphore = Semaphore.new()
func _pause():
	_is_paused = true
	print("PAUSED")
	pause_semaphore.post()
	unpause_semaphore.wait()
	_is_paused = false
	print("UNPAUSED")


func update(pos: Vector3i, tiles: Array) -> Cell:
	assert(null != tiles)
	assert(len(tiles) > 0)

	var cell: Cell = _cells.get(pos)
	if cell:
		cell.tiles = tiles
	else:
		# might exist in a previous stack
		if not exists_at(pos):
			_world_size += 1
		# create a new cell for the version stack
		cell = Cell.new(tiles)
		_cells[pos] = cell

	if cell.is_collapsed():
		cell.entropy = 0.0
		_uncollapsed.erase(pos)
	else:
		cell.entropy = cell.calculate_entropy()
		_uncollapsed[pos] = true

	_post_update({pos: cell})
	return cell

func remove(pos):
	if exists_at(pos):
		_world_size -= 1
		#_cells.erase(pos)
	_cells[pos] = null
	_uncollapsed[pos] = false


func at(pos: Vector3i) -> Cell:
	var cell = _cells.get(pos)
	if null == cell:
		var index = _version_stack.size();
		while index > 0:
			index -= 1
			if _version_stack[index][CELLS_VERSIONSTACK_INDEX].has(pos):
				cell = _version_stack[index][CELLS_VERSIONSTACK_INDEX].get(pos)
				if cell != null: break
	return cell

func exists_at(pos: Vector3i) -> bool:
	if _cells.get(pos):
		return true
	var index = _version_stack.size();
	while index > 0:
		index -= 1
		if _version_stack[index][CELLS_VERSIONSTACK_INDEX].has(pos):
			if _version_stack[index][CELLS_VERSIONSTACK_INDEX].get(pos) != null:
				return true
	return false

func offset(pos: Vector3i, face: int) -> Vector3i: return pos + Face.OFFSETS[face]

func _observe(observed: Array, rules: Array) -> bool:
	var least_entropy = []

	for pos in _uncollapsed.keys():
		least_entropy.append([pos, at(pos).entropy])

	if least_entropy.size() == 0:
		observed[0] = null
		return false

	least_entropy.sort_custom(func(a, b): return a[1] < b[1])

	var pos = least_entropy[0][0]
	observed[0] = pos

	var cell = at(pos)
	var tiles = cell.tiles
	for rule: Callable in rules:
		for face in Face.FACES:
			if not rule.call(cell, pos, face):
				print("observe fail:%s rule:%s face:%s cell:%s" % [pos, rule.get_method(), Face.NAME[face], cell])
				cell.tiles = tiles
				return false
			if cell.tiles.size() == 0:
				cell.tiles = tiles
				print("observe exhausted:%s rule:%s face:%s cell:%s" % [pos, rule.get_method(), Face.NAME[face], cell])
				return false

	# TODO: Tile weights adjusted by sample matrix
	var choice = _rng.rand_weighted(cell.tiles.map(func(t: Tile): return t.weight))
	var tile = cell.tiles[choice]
	#print("Collapsed %s:%s -> %s" % [pos, cell, tile.name])
	update(pos, [tile])

	return true

func _pre_propagate(_observed_pos) -> bool:
	return true

func _post_propagate(_observed_pos) -> bool:
	return true

func _propagate(observed_pos, rules) -> bool:
	var hit_count = [0]
	var skip = 0

	var queue = [observed_pos]
	var current = 0
	while current < queue.size():
		var pos: Vector3i = queue[current]

		var cell = at(pos)
		var tiles = cell.tiles
		for rule: Callable in rules:
			for face in Face.FACES:
				if not rule.call(cell, pos, face):
					print("propagate fail:%s rule:%s face:%s cell:%s" % [pos, rule.get_method(), Face.NAME[face], cell])
					cell.tiles = tiles
					return false
				if cell.tiles.size() == 0:
					cell.tiles = tiles
					print("propagate exhausted:%s rule:%s face:%s cell:%s" % [pos, rule.get_method(), Face.NAME[face], cell])
					return false

		update(pos, cell.tiles)

		var skipped_faces = 0
		for face in Face.FACES:
			var next_pos = offset(pos, face)
			var next = at(next_pos)
			if next and not next.is_collapsed():
				var index = queue.find(next_pos, skip)
				if index < 0:
					queue.append(next_pos)
					hit_count.append(1)
				else:
					hit_count[index] += 1
			else:
				skipped_faces += 1
		hit_count[current] += skipped_faces
		skip = hit_count.find_custom(func(i): return i < 6, skip)

		current += 1

	# assert((func():
	# 	for i in range(len(queue)):
	# 		var c = queue.count(queue[i])
	# 		if (c > 1):
	# 			return false
	# 	return true
	# ).call())

	return true

func collapse() -> Dictionary:
	# Main loop to collapse the wave function
	if _version_stack.size() == 0 and _cells.size() == 0:
		update(Vector3i.ZERO, atlas.tiles)

	var observed = [null]
	var success = true
	while true:
		if _is_paused:
			_pause()

		print("%03s of %03s, uncollapsed:%s, depth:%03s, attempt:%03s, fails:%03s" % [
			_world_size - len(_uncollapsed),
			_world_size,
			len(_uncollapsed),
			_version_stack.size(),
			_retries,
			_fail_count
		])

		_snapshot()
		success = _observe(observed, _get_observe_rules())

		if observed[0] == null:
			break

		if success: success = _pre_propagate(observed[0])
		if success: success = _propagate(observed[0], _get_propagate_rules())
		if success: success = _post_propagate(observed[0])

		if success:
			_commit()
			_snapshot()
		else:
			_fail_count += 1
			if not _restore(): break
			if _retries > max_retries:
				if not _restore(): break
			if _fail_count > max_failures:
				while _version_stack.size() > 0:
					_restore()
				_fail_count = 0

	if observed[0] == null and len(_uncollapsed) == 0:
		success = true

	var search_depth = _version_stack.size()
	while _version_stack.size() > 0:
		_commit()

	if success:
		print("Solution Found")
	else:
		printerr("No Solution Found")

	print("World Size: %s, Uncollapsed: %s, Cells: %s, Search Depth: %s" % [
		_world_size,
		len(_uncollapsed),
		_cells.size(),
		search_depth
	])

	if success: for pos in _cells.keys():
		var cell = _cells[pos]
		if cell.tiles[0].name == atlas.solid_tile.name:
			_cells.erase(pos)
			continue
		if cell.tiles[0].name == atlas.empty_tile.name:
			_cells.erase(pos)
			continue

	_post_update(_cells)

	return _cells
