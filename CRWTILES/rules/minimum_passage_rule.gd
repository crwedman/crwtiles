class_name CRWTILES_MinimumPassageRule
extends CRWTILES_Rule


@export_range(1, 4, 1) var minimum_width := 2

func _init(wfc: WFC):
	super._init(wfc)

func observe(cell: Cell, pos: Vector3i, face: int) -> bool:
	if minimum_width <= 1:
		return true
	if null == cell or cell.tiles.is_empty():
		return true

	var candidate_cache = {}
	cell.tiles = cell.tiles.filter(func(tile: Tile): return _tile_has_minimum_passage(pos, tile, face, candidate_cache))
	return true

func _tile_has_minimum_passage(pos: Vector3i, tile: Tile, face: int, candidate_cache: Dictionary) -> bool:
	if tile.is_solid(face):
		return true
	return _face_has_minimum_passage(pos, tile, face, candidate_cache)

func _face_has_minimum_passage(pos: Vector3i, tile: Tile, face: int, candidate_cache: Dictionary) -> bool:
	var perpendicular = Face.PERPENDICULAR[face]
	var axis_a = [perpendicular[0], perpendicular[1]]
	var axis_b = [perpendicular[2], perpendicular[3]]

	for dir_a in axis_a:
		if tile.is_solid(dir_a):
			continue
		for dir_b in axis_b:
			if tile.is_solid(dir_b):
				continue
			if _square_supported(pos, tile, face, dir_a, dir_b, candidate_cache):
				return true

	return false

func _square_supported(pos: Vector3i, tile: Tile, face: int, dir_a: int, dir_b: int, candidate_cache: Dictionary) -> bool:
	var pos_a = _wfc.offset(pos, dir_a)
	var pos_b = _wfc.offset(pos, dir_b)
	var pos_ab = _wfc.offset(pos_a, dir_b)

	var tiles_a = _candidate_tiles(pos_a, [
		face,
		Face.OPPOSITE[dir_a],
		dir_b,
	], candidate_cache)
	var tiles_b = _candidate_tiles(pos_b, [
		face,
		Face.OPPOSITE[dir_b],
		dir_a,
	], candidate_cache)
	var tiles_ab = _candidate_tiles(pos_ab, [
		face,
		Face.OPPOSITE[dir_a],
		Face.OPPOSITE[dir_b],
	], candidate_cache)

	if tiles_a.is_empty() or tiles_b.is_empty() or tiles_ab.is_empty():
		return false

	# If this rule remains hot, precompute atlas-level pair/triple support tables
	# instead of re-scanning compatibility here for every candidate combination.
	for tile_a: Tile in tiles_a:
		if not tile.is_compatible_with(dir_a, tile_a):
			continue

		for tile_b: Tile in tiles_b:
			if not tile.is_compatible_with(dir_b, tile_b):
				continue

			for tile_ab: Tile in tiles_ab:
				if not tile_a.is_compatible_with(dir_b, tile_ab):
					continue
				if not tile_b.is_compatible_with(dir_a, tile_ab):
					continue
				return true

	return false

func _candidate_tiles(pos: Vector3i, required_open_faces: Array, candidate_cache: Dictionary) -> Array:
	var cache_key = _cache_key(pos, required_open_faces)
	if candidate_cache.has(cache_key):
		return candidate_cache[cache_key]

	var source: Array
	var cell = _wfc.at(pos)
	if null == cell:
		source = _wfc.atlas.tiles
	else:
		source = cell.tiles

	var candidates = source.filter(func(tile: Tile): return _has_open_faces(tile, required_open_faces))
	candidate_cache[cache_key] = candidates
	return candidates

func _cache_key(pos: Vector3i, required_open_faces: Array) -> String:
	var sorted_faces = required_open_faces.duplicate()
	sorted_faces.sort()
	return "%s|%s" % [pos, sorted_faces]

func _has_open_faces(tile: Tile, faces: Array) -> bool:
	for face in faces:
		if tile.is_solid(face):
			return false
	return true
