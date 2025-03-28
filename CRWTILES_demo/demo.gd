extends Node

const WFC = CRWTILES_WFC.WFC
const Cell = WFC.Cell
const TileAtlasResource = CRWTILES_TileAtlasResource.TileAtlasResource

var tile_atlas: TileAtlasResource = load("res://CRWTILES_demo/resources/exports/crwtiles/tile_library.tres")

var pause = false
var cell_nodes = {}
var final_output

@onready var wfc_root = %WFCRoot
@export var wf: WFC
var wf_thread: Thread = null

var solid_material = preload("res://addons/crwtiles/resources/solid_material.tres")
var empty_material = preload("res://addons/crwtiles/resources/empty_material.tres")
var uncollapsed_material = preload("res://addons/crwtiles/resources/uncollapsed_material.tres")

func _init():
	print("possible tiles (%s): " % tile_atlas.tiles.size(), tile_atlas.tiles.map(func(t): return t.name))

func _ready():
	go()

var is_running = false
func go():
	wf = WFC.new(tile_atlas, randi())
	print("Seed: ", wf._seed)
	for pos in cell_nodes:
		wfc_root.remove_child(cell_nodes[pos])
	cell_nodes = {}
	wf_thread = Thread.new()
	wf_thread.start(func(): final_output = wf.collapse())
	is_running = true

func _input(event: InputEvent):
	if event is InputEventKey:
		if KEY_SPACE == event.keycode and not event.pressed:
			if wf.pause_semaphore.try_wait():
				wf.unpause_semaphore.post()
			else:
				if wf._is_paused:
					wf._is_paused = false
					wf.resume_semaphore.post()
				else:
					wf._is_paused = true
		if KEY_R == event.keycode and not event.pressed:
			if not is_running:
				go()

func _process(_delta):
	if wf_thread:
		if wf_thread.is_alive():
			if not wf._is_paused:
				process_updates()
		elif is_running:
			is_running = false
			wf_thread.wait_to_finish()
			var cells = final_output
			for pos in cell_nodes:
				wfc_root.remove_child(cell_nodes[pos])
			cell_nodes = {}
			for pos in cells.keys():
				handle_cell_update(cells[pos], pos)

func process_updates():
	if not wf.updates_semaphore.try_wait():
		return

	var cells = wf.get_all_updates()

	for pos in cells.keys():
		handle_cell_update(cells[pos], pos)
	wf.resume_semaphore.post()

class CellNode3D extends Node3D:
	var cell: WFC.Cell

func handle_cell_update(cell: Cell, pos: Vector3i):
	var node: Node3D = cell_nodes.get(pos)

	if null == cell:
		if node:
			if node.get_parent() == wfc_root:
				wfc_root.remove_child(node)
			cell_nodes.erase(pos)
			node.queue_free()
		return

	var origin = 2 * Vector3(pos.x, pos.y, pos.z)

	if not node:
		node = CellNode3D.new()
		node.cell = cell
		node.transform.origin = origin
		wfc_root.add_child(node)
		cell_nodes[pos] = node

	node.cell = cell

	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

	var child
	if cell.is_collapsed():
		child = get_mesh_instance(cell, 0)
	elif true:
		child = get_mesh_instance(cell, cell.tiles.find_custom(func(t): return not t.name.begins_with('_')))
	node.add_child(child)

func get_mesh_instance(cell, index):
	var tile = cell.tiles[index]

	if ('_SOLID_' == tile.tile_id or '_EMPTY_' == tile.tile_id):
		var cube = CSGBox3D.new()
		cube.size = Vector3i(2, 2, 2)
		if '_SOLID_' == tile.tile_id:
			cube.material = solid_material
		else:
			cube.material = empty_material
		return cube

	var mesh_instance = MeshInstance3D.new()
	var mesh = tile_atlas.mesh_index[tile.name]
	var mat: BaseMaterial3D = mesh.surface_get_material(0)

	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.mesh = mesh

	if not cell.is_collapsed():
		for i in range(mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(i, uncollapsed_material)

	match int(tile.rotation_index):
		1: mesh_instance.rotate_y(deg_to_rad(90))
		2: mesh_instance.rotate_y(deg_to_rad(180))
		3: mesh_instance.rotate_y(deg_to_rad(270))

	return mesh_instance
