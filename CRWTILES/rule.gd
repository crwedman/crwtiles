class_name CRWTILES_Rule
extends Resource

const WFC := CRWTILES_WFC.WFC
const Cell := CRWTILES_Cell.Cell
const Face = CRWTILES_Face.Face
const Tile = CRWTILES_Tile.Tile

var _wfc: WFC

func _init(wfc: WFC):
	_wfc = wfc

@warning_ignore_start("unused_parameter")

func observe(cell: Cell, pos: Vector3i, face: int) -> bool:
	return true

func propagate(cell: Cell, pos: Vector3i, face: int) -> bool:
	return true

@warning_ignore_restore("unused_parameter")
