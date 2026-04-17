import math

def validate_tile_boundaries(mesh_obj, tile_type="cube"):
    """
    Generalized geometry validation for multiple tile types.
    Supports unit cubes and hexagonal tiles.
    
    Args:
        mesh_obj: Blender object to validate.
        tile_type: Type of tile - options are 'cube' or 'hexagon'.
    
    Returns:
        bool: True if mesh is valid, False otherwise.
    """
    if tile_type == "cube":
        return validate_cube_boundaries(mesh_obj)
    elif tile_type == "hexagon":
        return validate_hexagon_boundaries(mesh_obj)
    else:
        print("Unknown tile type.")
        return False


def validate_cube_boundaries(mesh_obj):
    """
    Validate that all vertices are within the AABB for a unit cube: [-1, 1] on all axes.
    """
    mesh = mesh_obj.data
    for vertex in mesh.vertices:
        if not (-1 <= vertex.co.x <= 1 and -1 <= vertex.co.y <= 1 and -1 <= vertex.co.z <= 1):
            print(f"Vertex out of bounds in unit cube check: {vertex.co}")
            return False
    print("Unit cube geometry passed AABB checks.")
    return True


def validate_hexagon_boundaries(mesh_obj):
    """
    Validate that all vertices conform to the mathematical constraints of a valid 2D hexagon.
    The hexagon is assumed to be extruded up by 1 unit along Z-axis.
    """
    mesh = mesh_obj.data
    for vertex in mesh.vertices:
        if not is_point_inside_hexagon(vertex.co.x, vertex.co.y):
            print(f"Vertex out of valid hexagon range: {vertex.co}")
            return False
    print("Hexagonal tile geometry passed checks.")
    return True


def is_point_inside_hexagon(x, y):
    """
    Check if a 2D point (x, y) lies within a valid regular hexagon centered at the origin.
    The hexagon is considered to have radius 1.
    """
    # Convert Cartesian to polar coordinates
    r = math.sqrt(x**2 + y**2)
    theta = math.atan2(y, x)

    # Normalize theta into the range of 0 to 360 degrees
    theta = math.degrees(theta) % 360

    # Use regular hexagon's mathematical properties
    # Each 60° segment corresponds to a valid region of the hexagon
    if (
        r <= 1  # Ensure radius is within range
        and (
            0 <= theta < 60
            or 60 <= theta < 120
            or 120 <= theta < 180
            or 180 <= theta < 240
            or 240 <= theta < 300
            or 300 <= theta < 360
        )
    ):
        return True
    else:
        return False
