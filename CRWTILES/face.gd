extends Object
class_name CRWTILES_Face
const Face = CRWTILES_Face

enum {
	front = 0,
	right = 1,
	back = 2,
	left = 3,
	top = 4,
	bottom = 5
}

const FACES = [
	front,
	right,
	back,
	left,
	top,
	bottom
]

const NAME = [
	&"front",
	&"right",
	&"back",
	&"left",
	&"top",
	&"bottom"
]

const OPPOSITE = [
	back,
	left,
	front,
	right,
	bottom,
	top
]

const OFFSETS = [
	Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, -1),
	Vector3i(1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0)
]

const CORNERS = [
	OFFSETS[top] + OFFSETS[front] + OFFSETS[right],
	OFFSETS[top] + OFFSETS[front] + OFFSETS[left],
	OFFSETS[top] + OFFSETS[Face.back] + OFFSETS[right],
	OFFSETS[top] + OFFSETS[Face.back] + OFFSETS[left],
	OFFSETS[back] + OFFSETS[front] + OFFSETS[right],
	OFFSETS[back] + OFFSETS[front] + OFFSETS[left],
	OFFSETS[back] + OFFSETS[back] + OFFSETS[right],
	OFFSETS[back] + OFFSETS[back] + OFFSETS[left]
]

const PERPENDICULAR = [
	[left, right, top, bottom], # front
	[front, back, top, bottom], # right
	[left, right, top, bottom], # back
	[front, back, top, bottom], # left
	[left, right, front, back], # top
	[left, right, front, back], # bottom
]
