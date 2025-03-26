import bpy
from typing import List, Tuple, Dict
from math import pi, radians, cos, sin
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler
from collections import defaultdict, Counter
import hashlib
import bmesh
import json

from crwtiles.utils import logger
from crwtiles.utils.orientation import Orientation
from crwtiles.utils.mesh import is_inside

class HashCollisionError(Exception):

    def __init__(self, hash):
        self.hash = hash
        super().__init__()

    def __str__(self):
        return f"Hash collision: {self.hash}"

class SocketAtlas:

    threshold: float = 1e-6


    def __init__(self, num_rotations=4):

        self.rotated_sockets = {}
        self.index = ["empty", "solid"]
        self.edges = { "empty": [], "solid": []}
        self.has_face = { "empty": False, "solid": False }
        self.orientations = { "empty": Vector((0,0,0)), "solid": Vector((0,0,0))}
        self.symmetries = { "empty": { 0: "empty" }, "solid": { 0: "solid" } }
        self.canonical  = { "empty": "empty", "solid": "solid" }

        self.axis_symmetries = [
            # only x-axis, for now?
            (1,0,0)
        ]
        # only Z rotations, for now?
        self.rotations = [2 * pi * i / num_rotations for i in range(num_rotations)]


    def export(self):
        orientations = { id: Orientation.snap(ori) for id, ori in self.orientations.items() }
        socket_index = { id: {
            "edge_id": id,
            "orientation": orientations[id],
            "has_face": self.has_face[id]
            } for id in self.index }
        tiles = []

        for id in self.index:
            flipped = self.symmetries.get(id)
            flipped_id = flipped.get(0)
            if not flipped_id:
                # XXX socket was initially found, but not used again?  Fix for completeness.
                self._catalog_symmetry(id)
                flipped = self.symmetries.get(id)
                flipped_id = flipped.get(0)
            flipped_orientation = orientations.get(flipped_id)
            socket : Dict = socket_index[id]
            socket.update({
                "flipped_id": flipped_id,
                "flipped_orientation": flipped_orientation
            })

        unique = {}
        for obj, socket_ids in self.rotated_sockets.items():
            # XXX
            if not unique.get(obj["tile_id"]) is None:
                continue
            unique[obj["tile_id"]] = True

            found = []
            variants = []
            for i, sockets in enumerate(socket_ids):
                if sockets in found:
                    continue
                found.append(sockets)
                variants.append({
                    "rotation_index": i,
                    "sockets": sockets
                })

            pos = [ int(v) for v in obj["pos"].split(',') ]
            tiles.append({
                "tile_id": obj["tile_id"],
                "name": obj.name,
                "pos": pos,
                "variants": variants
                })

        return {
            "sockets": socket_index,
            "tiles": tiles
        }

    def add_tile(self, obj: bpy.types.Object):
        if obj.type != 'MESH':
            logger.debug("Object not type 'MESH' {obj}")
            return
        rotated_sockets = []
        socket_hashes = []

        self._generate_and_apply_hash(obj)

        for i, rot in enumerate(self.rotations):
            euler = Euler((radians(-90), rot, 0))
            matrix = Matrix.Identity(3)
            matrix.rotate(euler)
            right = matrix.row[0] # @ Vector((1,0,0))
            up = matrix.row[1] # @ Vector((0,1,0))
            location = matrix.row[2] # @ Vector((0,0,1))
            socket_hash = self._catalog_face(obj.data, right, up, location)
            self._catalog_symmetry(socket_hash, 0)

            socket_hashes.append(socket_hash)

        top_hash = self._catalog_face(obj.data, Vector((1,0,0)), Vector((0,1,0)), Vector((0,0,1)))
        bottom_hash = self._catalog_face(obj.data, Vector((1,0,0)), Vector((0,1,0)), Vector((0,0,-1)))

        num_rotations = len(self.rotations)
        for i in range(num_rotations):
            # top
            hash = self._catalog_rotation(top_hash, i)
            self._catalog_symmetry(hash, 0)
            socket_hashes.append(hash)

            # bottom
            hash = self._catalog_rotation(bottom_hash, i)
            self._catalog_symmetry(hash, 0)
            socket_hashes.append(hash)

            rotated_sockets.append(socket_hashes)

            # 'rotate' sides for next iteration
            first = socket_hashes[0]
            socket_hashes = socket_hashes[1:num_rotations]
            socket_hashes.append(first)

        self.rotated_sockets[obj] = rotated_sockets


    def add_custom_properties(self, obj):

        orientations = { hash: Orientation.snap(ori) for hash, ori in self.orientations.items() }

        flipped = {}
        for hash in self.symmetries.keys():
            entry = self.symmetries[hash]
            target = entry.get(0)
            #logger.debug(f"{entry}")
            if target:
                #logger.debug(f"flipped {hash} <--> {target}")
                flipped[hash] = entry.get(0)


        sockets = []
        variant = self.rotated_sockets[obj][0]
        for hash in variant:
            ori = self.orientations[hash]
            socket = {
                "edge_id": hash,
                "flipped_id": flipped.get(hash),
                "orientation": orientations[hash]
            }
            entry = self.symmetries[hash]
            socket["flipped_orientation"] = orientations.get(entry.get(0, -1))
            sockets.append(socket)
        obj["sockets"] = json.dumps(sockets)


    def _generate_and_apply_hash(self, obj):

        def get_tile_vertices(obj: bpy.types.Object):
            return [obj.matrix_world.inverted() @ v.co for v in obj.data.vertices]

        def apply_rotation(vertices, rotation):
            matrix = Matrix.Rotation(rotation, 3, 'Z')
            return [matrix @ v for v in vertices]

        def round_vertex(v): return tuple(round(n,5)+0.0 for n in v)

        vertices = get_tile_vertices(obj)

        id_verts = [round_vertex(v) for v in vertices]
        id_verts = sorted(id_verts)
        hash_str = ':'.join(f"{v[0]},{v[1]},{v[2]}" for v in id_verts)
        hash = hashlib.sha256(hash_str.encode('utf-8')).hexdigest()[:16]

        obj["hash"] = hash

        id_verts = None
        canonical = None
        for i, rot in enumerate(self.rotations):
            rotated = apply_rotation(vertices, rot)
            rotated = [round_vertex(v) for v in rotated]
            rotated = sorted(rotated)
            if canonical is None or canonical > rotated:
                canonical = rotated

        # Flatten canonical form and hash it
        hash_str = ':'.join(f"{v[0]},{v[1]},{v[2]}" for v in canonical)
        hash = hashlib.sha256(hash_str.encode('utf-8')).hexdigest()[:16]
        #logger.debug(f"{hash}: {hash_str}")

        # Ugh! XXX
        obj["tile_id"] = hash


    def _check_for_hash_collision(self, hash, edges):
        try:
            existing_edges = self.edges[hash]
        except KeyError:
            return
        if existing_edges != edges:
            raise HashCollisionError(hash)


    def _catalog_hash(self, hash, edges, orientation, has_face):
        if not hash in self.index:
            self.index.append(hash)
            self.edges[hash] = edges
            self.orientations[hash] = orientation
            self.has_face[hash] = has_face
        else:
            self._check_for_hash_collision(hash, edges)

        if not hash in self.symmetries:
            self.symmetries[hash] = {}


    def _catalog_face(self, mesh: bpy.types.Mesh, right, up, location):
        #mesh.calc_normals()
        edges, orientation, has_face = collect_projected_plane_edges(mesh, right, up, location, self.threshold)

        if 0 == len(edges):
            boundary = location * (1 + self.threshold)
            if is_inside(mesh, boundary):
                return "solid"
            else:
                return "empty"

        edges = merge_collinear_edge_chains(edges)
        edges_normalized = normalize_edges(edges)
        hash = hash_edges(edges_normalized, orientation)

        self._catalog_hash(hash, edges_normalized, orientation, has_face)

        return hash


    def _catalog_symmetry(self, hash, axis_index=0):
        edges = self.edges[hash]
        orientation = self.orientations[hash]
        if 0 == len(edges): return hash

        # No Vector.to_3x3() in Python 3.9.2, manually calculate outer product
        normal = Vector(self.axis_symmetries[axis_index])
        outer_product = Matrix((
            (normal.x * normal.x, normal.x * normal.y, normal.x * normal.z),
            (normal.y * normal.x, normal.y * normal.y, normal.y * normal.z),
            (normal.z * normal.x, normal.z * normal.y, normal.z * normal.z),
            ))

        mirror_matrix = Matrix.Identity(3) - 2 * outer_product
        mirrored_edges = normalize_edges([(mirror_matrix @ Vector(e[0]), mirror_matrix @ Vector(e[1])) for e in edges])
        mirrored_orientaton = mirror_matrix @ orientation
        mirrored_hash = hash_edges(mirrored_edges, mirrored_orientaton)

        self._catalog_hash(mirrored_hash, mirrored_edges, mirrored_orientaton, self.has_face[hash])
        self.symmetries[hash][axis_index] = mirrored_hash

        return mirrored_hash


    def _catalog_rotation(self, hash, rot_idx):
        edges = self.edges[hash]
        orientation = self.orientations[hash]
        if 0 == len(edges): return hash

        rotation = self.rotations[rot_idx]

        rotation_matrix = Matrix.Rotation(rotation, 3, 'Z')
        rotated_edges = normalize_edges([(rotation_matrix @ Vector(e[0]), rotation_matrix @ Vector(e[1])) for e in edges])
        rotated_orientation = rotation_matrix @ orientation
        rotated_hash = hash_edges(rotated_edges, rotated_orientation)

        self._catalog_hash(rotated_hash, rotated_edges, rotated_orientation, self.has_face[hash])

        return rotated_hash


def normalize_edges(edges):
    # round off floating point drift and avoid -0.0
    def r(v): return tuple(round(n,5)+0.0 for n in v)
    rounded_edges = [sorted((r(e[0]),r(e[1]))) for e in edges]
    sorted_edges = sorted(rounded_edges, key=lambda e: (e[0], e[1]))
    return sorted_edges


def hash_edges(edges, orientation) -> str:

    assert(len(edges))
    #normalized_edges = normalize_edges(edges)
    #hash_str = ":".join(f"({p[0][0]},{p[0][1]}),({p[1][0]},{p[1][1]})" for p in normalized_edges)
    hash_str = ":".join(f"({p[0][0]},{p[0][1]}),({p[1][0]},{p[1][1]})" for p in edges)
    hash_str += f"-{Orientation.snap(orientation)}"
    hash = hashlib.sha256(hash_str.encode('utf-8')).hexdigest()[:8]
    #logger.debug(f"hash: {hash} {hash_str}")
    return hash


def collect_plane_edges(mesh: bpy.types.Mesh, location: Vector, normal: Vector, threshold=1e-6):
    def vertex_is_on_plane(vertex_index):
        vertex = mesh.vertices[vertex_index].co
        return abs((vertex - location).dot(normal)) <= threshold

    def face_is_on_plane(face: bpy.types.MeshPolygon):
        # Check if all vertices of the face are on the plane
        return all(vertex_is_on_plane(v) for v in face.vertices)

    # Precompute which faces lie on the plane
    faces_on_plane = set(face.index for face in mesh.polygons if face_is_on_plane(face))

    # Get all edges and filter
    mesh_edges = [(edge.vertices[0], edge.vertices[1]) for edge in mesh.edges]
    edges_on_plane = []
    has_face = False

    for edge_verts in mesh_edges:
        # Check if edge vertices are on the plane
        if not all(vertex_is_on_plane(v) for v in edge_verts):
            continue

        # Check if edge belongs to any face on the plane
        # XXX FIXME
        # - need "has_face" flag?
        #   - true:true -> no socket match
        #   - true:false, false:false --> ok!
        edge_in_face_on_plane = False
        for face in mesh.polygons:
            if face.index in faces_on_plane:
                face_verts = face.vertices[:]
                if edge_verts[0] in face_verts and edge_verts[1] in face_verts:
                    edge_in_face_on_plane = True
                    break

        # flag for faces
        if edge_in_face_on_plane:
            has_face = True

        edges_on_plane.append(edge_verts)

    return edges_on_plane, has_face


def project_vertex(v: Vector, up: Vector, right: Vector, normal: Vector = Vector((0,0,0))):
    x = v.dot(right)
    y = v.dot(up)
    z = v.dot(normal)
    return Vector((x,y,z))


def collect_projected_plane_edges(mesh: bpy.types.Mesh, right: Vector, up: Vector, location: Vector, threshold=1e-6):
    # Calculate the normal from the 'up' and 'right' axes
    normal = up.cross(right)

    # Collect edges that are on the defined plane
    edges_on_plane, has_face = collect_plane_edges(mesh, location, normal, threshold)

    # Project the vertices of each edge onto the 2D plane
    projected_edges: List[Tuple[Vector, Vector]] = []
    orientation = Vector((0,0,0))
    for edge in edges_on_plane:
        # Project each vertex of the edge onto the 2D plane
        vertex1 = mesh.vertices[edge[0]].co
        vertex2 = mesh.vertices[edge[1]].co

        # Project both vertices
        projected_v1 = project_vertex(vertex1, up, right)
        projected_v2 = project_vertex(vertex2, up, right)

        # Store the projected edge as a tuple
        projected_edges.append((projected_v1, projected_v2))

        normal1 = mesh.vertices[edge[0]].normal
        normal2 = mesh.vertices[edge[1]].normal
        orientation += (projected_v1 - projected_v2).length * (normal1 + normal2) / 2

    if len(projected_edges):
        orientation = project_vertex(orientation, up, right)
        orientation.normalize()

    return projected_edges, orientation, has_face


def merge_collinear_edge_chains(edges: List[Tuple[Vector, Vector]], threshold: float = 1e-6):
    """Create a mapping of vertices to their connected edges."""
    vertex_to_edges = defaultdict(list)
    for edge in edges:
        v1, v2 = edge
        v1.freeze()
        v2.freeze()
        vertex_to_edges[v1].append(edge)
        vertex_to_edges[v2].append(edge)

    # Traverse and merge collinear edge chains
    processed_edges: List[Tuple[Vector, Vector]] = []
    visited_edges = set()

    def traverse_chain(start_edge):
        """Recursively find all collinear edges in a chain."""
        chain = [start_edge]
        visited_edges.add(start_edge)

        v1, v2 = start_edge
        current_dir = (v2 - v1).normalized()

        for vertex in (v1, v2):
            for other_edge in vertex_to_edges[vertex]:
                if other_edge in visited_edges:
                    continue

                ov1, ov2 = other_edge
                other_dir = (ov2 - ov1).normalized()

                # Check if directions are collinear
                if abs(current_dir.dot(other_dir)) > 1.0 - threshold:
                    chain.extend(traverse_chain(other_edge))

        return chain

    for edge in edges:
        if edge in visited_edges:
            continue

        # Get the entire collinear chain
        chain = traverse_chain(edge)

        # Merge the chain into a single edge
        all_vertices = [v for e in chain for v in e]
        min_vertex = min(all_vertices, key=lambda v: (v.x, v.y))
        max_vertex = max(all_vertices, key=lambda v: (v.x, v.y))
        processed_edges.append((min_vertex, max_vertex))

    # Cull zero length edges
    processed_edges = [(v1, v2) for v1, v2 in processed_edges if (v2 - v1).length > threshold]

    return processed_edges
