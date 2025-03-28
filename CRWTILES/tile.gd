class_name CRWTILES_Tile
extends Resource
const Tile = CRWTILES_Tile

const Socket = CRWTILES_Socket.Socket
const Face = CRWTILES_Face.Face

@export var tile_id: String
@export var name: String
@export var rotation_index: int
@export var weight: float = 1
@export var sockets: Array[Socket] = []
@export var neighbors = []


func is_compatible_with(my_face: int, other: Tile) -> bool:
	var socket: Socket = sockets[my_face]
	var other_socket: Socket = other.sockets[Face.OPPOSITE[my_face]]
	var result

	if my_face < (len(sockets) - 2):
		result = socket.fits_beside(other_socket)
	else:
		result = socket.fits_stacked(other_socket)

	return result


func is_solid(my_face: int = -1):
	if my_face < 0:
		return sockets.all(func(s: Socket): return s.edge_id == &"solid")
	else:
		return sockets[my_face].edge_id.begins_with(&"solid")


func is_empty(my_face: int = -1):
	if my_face < 0:
		return sockets.all(func(s: Socket): return s.edge_id == &"empty")
	else:
		return sockets[my_face].edge_id.begins_with(&"empty")

static var empty: Tile:
	get:
		if not empty:
			empty = Tile.new()
			empty.tile_id = '_EMPTY_'
			empty.name = "_EMPTY_"
			empty.rotation_index = 0
			empty.weight = 1.0

			var empty_socket = Socket.empty
			for i in range(6):
				empty.sockets.append(empty_socket)
		return empty

static var solid: Tile:
	get:
		if not solid:
			solid = Tile.new()
			solid.tile_id = '_SOLID_'
			solid.name = "_SOLID_"
			solid.rotation_index = 0
			solid.weight = 1.0

			var solid_socket = Socket.solid
			for i in range(6):
				solid.sockets.append(solid_socket)
		return solid