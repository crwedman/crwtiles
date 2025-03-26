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
