class_name CRWTILES_Cell
extends RefCounted

const Cell = CRWTILES_Cell
const Tile = CRWTILES_Tile.Tile

var tiles: Array
var entropy: float = INF


class Fuzz:
	var index: int
	var weight: float
	func _init(i, w):
		index = i
		weight = w

func _init(possible_tiles: Array):
	tiles = possible_tiles

func _to_string():
	return "(%0.3f):%s" % [
		entropy,
		tiles.map(func(tile): return "%s(%s)" % [tile.name, [0, 90, 180, 270][int(tile.rotation_index)]])
		]

func _randomize_tiles(rng: RandomNumberGenerator):
	var fuzzy = []
	for i in len(tiles):
		var tile = tiles[i]
		fuzzy.append(Fuzz.new(i, tile.weight * rng.randf()))
	fuzzy.sort_custom(func(a: Fuzz, b: Fuzz): return a.weight < b.weight)

	var result = []
	result.resize(len(tiles))
	for i in fuzzy.size():
		var sorted_idx = fuzzy[i].index
		result[sorted_idx] = tiles[i]

	tiles = result

func calculate_entropy():
	var total_entropy = 0.0
	var log_sum = 0.0
	var e: float
	for tile in tiles:
		e = 1 / (1 + tile.weight)
		total_entropy += e
		log_sum += e * log(e)

	if total_entropy > 0:
		entropy = log(total_entropy) - (log_sum / total_entropy)
	else:
		entropy = 0.0
	return entropy

func is_collapsed() -> bool:
	return 1 == len(tiles)

func is_superposition() -> bool:
	return 1 < len(tiles)

func is_valid() -> bool:
	return 0 < len(tiles)

func is_solid(face: int = -1) -> bool:
	assert(len(tiles))
	return tiles.all(func(t: Tile): return t.is_solid(face))

func is_empty(face: int = -1) -> bool:
	assert(len(tiles))
	return tiles.all(func(t: Tile): return t.is_empty(face))

func is_passable(my_face):
	assert(len(tiles))
	return tiles.any(func(tile: Tile): return not tile.is_solid(my_face))

static func potential_matches(my_tiles, my_face, their_tiles):
	assert(len(their_tiles))
	#if len(their_tiles) == 0: return my_tiles
	return my_tiles.filter(func(my_tile):
		return their_tiles.any(func(their_tile):
			return my_tile.is_compatible_with(my_face, their_tile)
		)
	)
