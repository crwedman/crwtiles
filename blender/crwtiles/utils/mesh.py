import bpy
from mathutils import Vector
from typing import List, Tuple


def get_face_centroid(mesh: bpy.types.Mesh, face: bpy.types.MeshPolygon, point: Vector) -> Vector:
    centroid = Vector((0, 0, 0))
    for i in face.vertices:
        centroid += mesh.vertices[i].co
    return centroid / len(face.vertices)


def get_closest_face(mesh: bpy.types.Mesh, point: Vector):
    distances = []
    for polygon in mesh.polygons:
        centroid = get_face_centroid(mesh, polygon, point)
        distance = (point - centroid).length
        distances.append((distance, polygon))

    distances.sort(key=lambda x: x[0])
    return distances[0][1]


def is_inside(mesh: bpy.types.Mesh, boundary):
    if len(mesh.polygons):
        polygon = get_closest_face(mesh, boundary)
        return polygon.normal.dot(boundary) < 0
    return False


def collect_plane_edges(mesh: bpy.types.Mesh, location: Vector, normal: Vector, threshold=1e-6):

    def vertex_is_on_plane(vertex_index):
        vertex = mesh.vertices[vertex_index].co
        return abs((vertex - location).dot(normal)) <= threshold

    mesh_edges = (edge.vertices for edge in mesh.edges)
    edges_on_plane = filter(lambda e: all(vertex_is_on_plane(v) for v in e), mesh_edges)

    return list(edges_on_plane)

