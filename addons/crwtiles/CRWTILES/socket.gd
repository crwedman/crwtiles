class_name CRWTILES_Socket
extends Resource
const Socket = CRWTILES_Socket

@export var edge_id: String
@export var orientation: int
@export var flipped_id: String
@export var flipped_orientation: int
@export var has_face: bool

func fits_beside(other: Socket) -> bool:
	if has_face and other.has_face:
		return false

	if edge_id == other.flipped_id and orientation == other.flipped_orientation:
		return true

	return false

func fits_stacked(other: Socket) -> bool:
	if edge_id == other.edge_id:
		return true

	return false

static var empty: Socket:
	get:
		if not empty:
			empty = Socket.new()
			empty.edge_id = "empty"
			empty.orientation = -1
			empty.flipped_id = "empty"
			empty.flipped_orientation = -1
			empty.has_face = false
			pass
		return empty

static var solid: Socket:
	get:
		if not solid:
			solid = Socket.new()
			solid.edge_id = "solid"
			solid.orientation = -1
			solid.flipped_id = "solid"
			solid.flipped_orientation = -1
			solid.has_face = false
			pass
		return solid
