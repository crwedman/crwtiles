class_name CRWTILES_DisjointSet
extends RefCounted
const DisjointSet = CRWTILES_DisjointSet

enum {
	PARENT = 0,
	SIZE
}

var _nodes: PackedInt32Array = [0, 0]
var _index: Dictionary[Vector3i, int] = {}

func find(pos: Vector3i) -> int:
	var x = _index.get(pos, 0)

	if 0 == x:
		x = len(_nodes)
		_nodes.append(x)
		_nodes.append(1)
		_index[pos] = x

	# Path compression (path halving):
	# 	Replaces replaces every other index pointer
	var p = _nodes[x]
	while _nodes[p] != p:
		_nodes[p] = _nodes[_nodes[p]] # node.index = node.index.index
		p = _nodes[p] # node = node.index

	return p

func union(pos1: Vector3i, pos2: Vector3i) -> void:
	var x = find(pos1)
	var y = find(pos2)

	if x == y:
		return

	if _nodes[x + SIZE] < _nodes[y + SIZE]:
		_nodes[x] = y
	else:
		_nodes[y] = x
		_nodes[x + SIZE] = _nodes[x + SIZE] + _nodes[y + SIZE]


func index(pos: Vector3i):
	var x = _index.get(pos)
	if not x:
		x = find(x)
	return x

func parent_of(pos: Vector3i):
	var x = find(pos)
	if x == 0:
		return null
	for item in _index.keys():
		if _index.get(item) == x:
			return item
	return null

func size_of(pos: Vector3i):
	var x = _index.get(pos, 0)
	return _nodes[x + SIZE]

func duplicate():
	var dup = DisjointSet.new()
	dup._nodes = _nodes.duplicate()
	dup._index = _index.duplicate()
	return dup
