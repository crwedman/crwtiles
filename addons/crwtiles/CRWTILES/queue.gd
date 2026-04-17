extends RefCounted
class_name CRWTILES_Queue
const Queue = CRWTILES_Queue

enum {
	VALUE = 0,
	NEXT
}

var head
var tail
var _size: int = 0

static func next(node): return node[NEXT]
static func value(node): return node[VALUE]

func size():
	return _size

func enqueue(_value):
	var new_node = [_value, null]
	if tail:
		tail[NEXT] = new_node
	tail = new_node
	if not head:
		head = tail
	_size += 1

func dequeue():
	if not head:
		return null
	var _value = head[VALUE]
	head = head[NEXT]
	if not head: # Queue is now empty
		tail = null
	_size -= 1
	return _value

func peek():
	if not head:
		return null
	return head[VALUE]

func has(_value) -> bool:
	var current = head
	while current:
		if current[VALUE] == _value:
			return true
		current = current[NEXT]
	return false

func duplicate() -> Queue:
	var queue = Queue.new()
	queue.head = head
	queue.tail = tail
	queue._size = _size
	return queue
