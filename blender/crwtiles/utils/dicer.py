import bpy
import bmesh
from mathutils import Vector, Matrix, Euler
from math import floor, ceil, radians

from crwtiles.utils import logger

class Dicer:

    def __init__(self, collection: bpy.types.Collection, tile_size=(2,2,2), precision=5) -> None:
        self.tiles = {}
        self.source_collection = collection
        self.tile_size = tile_size
        self.precision = precision

    def execute(self, context: bpy.types.Context = bpy.context):
        tmp_collection = bpy.data.collections.new("tmp")
        context.scene.collection.children.link(tmp_collection)

        if bpy.context.active_object:
            bpy.ops.object.mode_set(mode='OBJECT')

        bpy.ops.object.select_all(action='DESELECT')
        for obj in self.source_collection.objects:
            dup = obj.copy()
            dup.name = obj.name + "-tmp"
            dup.data = obj.data.copy()
            tmp_collection.objects.link(dup)
            context.view_layer.objects.active = dup
            for mod in dup.modifiers:
                print(f"{mod.name}")
                bpy.ops.object.modifier_apply(modifier=mod.name)
            dup.to_mesh()
            dup.select_set(True)

        joined_obj = bpy.data.objects.new("Joined", bpy.data.meshes.new("Mesh"))
        tmp_collection.objects.link(joined_obj)
        joined_obj.select_set(True)
        context.view_layer.objects.active = joined_obj
        bpy.ops.object.join()

        context.scene.collection.objects.link(joined_obj)

        bpy.data.collections.remove(tmp_collection)

        cut_mesh_into_cubes(joined_obj, self.tile_size)

        self.tiles = separate_cube_tiles(joined_obj, self.tile_size, self.precision)

        context.scene.collection.objects.unlink(joined_obj)
        bpy.data.objects.remove(joined_obj)


def cut_mesh_into_cubes(obj, tile_size=(2.0, 2.0, 2.0)):
    """
    Cuts edges into a mesh object, defined by cube_size.

    :param obj: The Blender object to slice.
    :param cube_size: The size of the cubes for slicing (as a float or tuple).
    """
    # Ensure cube_size is a tuple for slicing along x, y, and z axes
    if isinstance(tile_size, (float, int)):
        tile_size = (tile_size, tile_size, tile_size)

    # Convert the object to a bmesh
    bm: bmesh.types.BMesh = bmesh.new()
    bm.from_mesh(obj.data)

    # Get the bounding box
    bbox_min = Vector(obj.bound_box[0])
    bbox_max = Vector(obj.bound_box[6])

    # Create slicing planes for each axis
    cutting_planes = []
    for axis, step in enumerate(tile_size):
        start = bbox_min[axis]
        end = bbox_max[axis]
        for value in range(int(start // step), int(end // step) + 1):
            cutting_planes.append((axis, value * step))

    # Bisect the mesh with planes
    for axis, value in cutting_planes:
        # Define the plane normal and center
        plane_no = Vector((0, 0, 0))
        plane_no[axis] = 1.0
        plane_co = Vector((0, 0, 0))
        plane_co[axis] = value

        # Slice the mesh along the plane
        bmesh.ops.bisect_plane(
            bm,
            geom=bm.faces[:] + bm.edges[:] + bm.verts[:],
            plane_co=plane_co,
            plane_no=plane_no,
            use_snap_center=False,
            clear_outer=False,
            clear_inner=False,
        )

    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    # Update the object's mesh
    bm.to_mesh(obj.data)
    bm.free()


def separate_cube_tiles(obj: bpy.types.Object, tile_size=(2.0, 2.0, 2.0), precision=5):
    """
    Separates the input object into cubic tiles of the given size.
    The object should have edges defined for each cube.

    :param obj: The object to slice.
    :param tile_size: Tuple (x, y, z) defining the size of each cube tile.
    """

    # Ensure object scales are applied ???
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Calculate the bounding box of the object
    min_bound = (round(i,precision) for i in obj.bound_box[0])
    max_bound = (round(i,precision) for i in obj.bound_box[6])
    min_bound = Vector(min_bound) @ obj.matrix_world
    max_bound = Vector(max_bound) @ obj.matrix_world

    # Compute grid dimensions
    grid_min = Vector((floor(min_bound[i] / tile_size[i]) * tile_size[i] for i in range(3)))
    grid_max = Vector((ceil(max_bound[i] / tile_size[i]) * tile_size[i] for i in range(3)))

    center_offset = Vector(tile_size) / 2

    # Duplicate the mesh into a temporary bmesh for slicing
    bm: bmesh.types.BMesh = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)

    uv_layer = bm.loops.layers.uv.active
    if not uv_layer:
        logger.debug(f"Object {obj.name} has no UV layer")

    tiles = {}
    # Iterate over each cube in the grid
    i = -1
    for x in range(int(grid_min.x), int(grid_max.x), int(tile_size[0])):
        i += 1
        j = -1
        for y in range(int(grid_min.y), int(grid_max.y), int(tile_size[1])):
            j += 1
            k = -1
            for z in range(int(grid_min.z), int(grid_max.z), int(tile_size[2])):
                k += 1
                # Define the cube bounds
                min_corner = Vector((x, y, z))
                max_corner = min_corner + Vector(tile_size)

                # Extract geometry within the bounds
                new_mesh: bmesh.types.BMesh
                new_mesh = bmesh.new()

                new_uv_layer = new_mesh.loops.layers.uv.new()

                for face in bm.faces:
                    if all(min_corner[i] <= round(v.co[i], precision) <= max_corner[i] for v in face.verts for i in range(3)):
                        face_copy: bmesh.types.BMFace
                        face_copy = new_mesh.faces.new([new_mesh.verts.new(v.co) for v in face.verts])

                        if uv_layer:
                            for loop, new_loop in zip(face.loops, face_copy.loops):
                                new_loop[new_uv_layer].uv = loop[uv_layer].uv

                        face_copy.material_index = face.material_index

                        bm.faces.remove(face)

                bmesh.ops.remove_doubles(new_mesh, verts=new_mesh.verts, dist=1/(10**precision))

                # Skip empty tiles
                if 0 == len(new_mesh.faces) or len(new_mesh.verts) < 3:
                    #logger.debug(f"Skipping [{i},{k},{j}]")
                    new_mesh.free()
                    continue
                #else:
                #    logger.debug(f"[{i},{k},{j}]: Faces: {len(new_mesh.faces)}, Verts: {len(new_mesh.verts)}")

                # move to tile origin
                translation = -1 * (min_corner + center_offset)
                bmesh.ops.translate(new_mesh, verts=new_mesh.verts, vec=translation)

                # Create a new object for the tile
                tile_mesh = bpy.data.meshes.new(f"Mesh_{i}_{k}_{j}")
                new_mesh.to_mesh(tile_mesh)
                new_mesh.free()

                # Assign materials
                for mat in obj.data.materials:
                    tile_mesh.materials.append(mat)

                tile_object = bpy.data.objects.new(f"Tile_{i}_{k}_{j}", tile_mesh)
                tile_object["pos"] = f"{i},{k},{j}"
                tile_object.location = Vector((x,y,z))
                tiles[(i,k,j)] = tile_object

    bm.free()
    return tiles

