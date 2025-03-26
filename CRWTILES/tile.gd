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
