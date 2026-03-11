class_name CRWTILES_TileAtlasResource
extends Resource
const TileAtlasResource = CRWTILES_TileAtlasResource

const Socket = CRWTILES_Socket.Socket
const Tile = CRWTILES_Tile.Tile

@export_file("*.glb") var scene_file # = "res://blender/exports/crwtiles/tile_library.glb"
#@export_file("*.json") var json_file = "res://blender/exports/crwtiles/tile_library.json"

@export var socket_index: Dictionary[String, Socket] = {}
@export var tiles: Array[Tile] = []
@export var empty_tile: Tile
@export var solid_tile: Tile
@export var tile_grid: Dictionary[Vector3i, Tile] = {}
@export var mesh_index: Dictionary[String, Mesh] = {}
