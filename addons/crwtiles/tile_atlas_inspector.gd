@tool
class_name CRWTILES_TileAtlasInspector
extends EditorInspectorPlugin
const TileAtlasInspector = CRWTILES_TileAtlasInspector

const TileAtlasResource = CRWTILES_TileAtlasResource.TileAtlasResource
const WFC = CRWTILES_WFC.WFC
const Socket = WFC.Socket
const Tile = WFC.Tile
const Face = CRWTILES_Face.Face


var import_button

static var empty_tile: Tile
static var solid_tile: Tile

func _can_handle(object):
	if object is TileAtlasResource:
		if not empty_tile:
			empty_tile = Tile.new()
			empty_tile.tile_id = '_EMPTY_'
			empty_tile.name = "_EMPTY_"
			empty_tile.rotation_index = 0
			empty_tile.entropy = 1.0

			solid_tile = Tile.new()
			solid_tile.tile_id = '_SOLID_'
			solid_tile.name = "_SOLID_"
			solid_tile.rotation_index = 0
			solid_tile.entropy = 1.0

		return true
	return false


func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if "scene_file" == name:
		import_button = Button.new()
		import_button.text = "Import"
		import_button.pressed.connect(import_scene.bind(object))
		add_custom_control(import_button)


func import_scene(tile_atlas: TileAtlasResource):
	var scene: PackedScene = load(tile_atlas.scene_file)

	if null == scene:
		push_error("Failed to load resource: ", tile_atlas.scene_file)
		return false

	print_debug("Importing from ", tile_atlas.scene_file)

	var root = scene.instantiate()

	var json_path: String = tile_atlas.scene_file.get_basename() + ".json"
	#var json_path = tile_atlas.json_file
	if tile_atlas.scene_file.begins_with("uid://"):
		var uid = ResourceLoader.get_resource_uid(tile_atlas.scene_file)
		var real_path = ResourceUID.get_id_path(uid)
		json_path = tile_atlas.scene_file.get_basename() + ".json"
		#json_path = ResourceLoader.get_resource_uid(json_path)

	print("JSON: %s" % [json_path])
	var json_text = FileAccess.get_file_as_string(json_path)
	print("Length:", json_text.length())
	var json = JSON.parse_string(json_text)

	var tiles = []
	var socket_index = {}
	var mesh_index = {}
	var tile_index = {}
	var tile_grid = {}
	var tile_neighbors = {}

	for id in json["sockets"]:
		var socket = Socket.new()
		var data = json["sockets"][id]
		for p in data:
			if p == "edge_id" or p == "flipped_id":
				var s = data[p]
				socket.set(p, s)
			else:
				socket.set(p, data[p])
		socket_index[id] = socket

	if empty_tile.sockets.size() == 0:
		var empty_socket = socket_index["empty"]
		for i in range(6):
			empty_tile.sockets.append(empty_socket)


		var solid_socket = socket_index["solid"]
		for i in range(6):
			solid_tile.sockets.append(solid_socket)

	tiles.append(solid_tile)
	tiles.append(empty_tile)
	for tile_info in json["tiles"]:
		#print_debug("processing tile:\n", tile_info)
		var mesh_name = tile_info["name"]
		var node = root.find_child(mesh_name)
		mesh_index[mesh_name] = node.mesh

		for variant in tile_info["variants"]:
			var tile = Tile.new()
			tile.tile_id = tile_info["tile_id"]
			tile.name = tile_info["name"]
			tile.rotation_index = variant["rotation_index"]
			tile.entropy = 1.0
			for id in variant["sockets"]:
				tile.sockets.append(socket_index[id])
			tiles.append(tile)
			tile_index[tile.tile_id] = tile


	for node in root.get_children():
		if node is MeshInstance3D:
			var extras = node.get_meta("extras")
			var pos_str: String = extras.get("pos")
			var pos = pos_str.split(",")
			pos = Vector3i(pos[0].to_int(), pos[1].to_int(), pos[2].to_int())
			var id = extras.get("tile_id")
			tile_grid[pos] = tile_index.get(id)

	for pos in tile_grid.keys():
		var tile = tile_grid[pos]
		for face in range(6):
			var dir = Face.OFFSETS[face]
			var grid_tile = tile_grid.get(dir)


	tile_atlas.socket_index = socket_index
	tile_atlas.tiles = tiles
	tile_atlas.mesh_index = mesh_index
	tile_atlas.tile_grid = tile_grid
	tile_atlas.solid_tile = solid_tile.duplicate(true)
	tile_atlas.empty_tile = empty_tile.duplicate(true)

	if OK != ResourceSaver.save(tile_atlas, tile_atlas.resource_path):
		push_error("Failed to save ", tile_atlas.resource_path)
