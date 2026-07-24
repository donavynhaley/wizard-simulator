"""Generate the editable wizard homestead environment in Blender.

Run from the repository root:

    blender --background --python tools/authoring/generate_wizard_homestead.py

The script writes an editable Blender source file, a Godot-ready GLB, a tiled
terrain albedo texture, a JSON layout manifest, and two preview renders under
/tmp.
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BLEND_PATH = PROJECT_ROOT / "source_assets/blender/environments/wizard_homestead.blend"
GLB_PATH = PROJECT_ROOT / "assets/models/environments/wizard_homestead_environment.glb"
LAYOUT_PATH = PROJECT_ROOT / "source_assets/blender/environments/wizard_homestead_layout.json"
GROUND_TEXTURE_PATH = PROJECT_ROOT / "assets/textures/environments/homestead_ground_dark.png"
OVERVIEW_PATH = Path("/tmp/wizard_homestead_overview.png")
HILL_PATH = Path("/tmp/wizard_homestead_hill.png")
TREE_MODEL_PATHS = [
    PROJECT_ROOT / "assets/models/tree_1.glb",
    PROJECT_ROOT / "assets/models/tree_2.glb",
    PROJECT_ROOT / "assets/models/tree_3.glb",
]

SEED = 74218
MOVE_SPEED = 4.2
TARGET_SECONDS = {
    "woods": 30.0,
    "farm": 60.0,
    "village": 120.0,
}
TARGET_LENGTHS = {name: seconds * MOVE_SPEED for name, seconds in TARGET_SECONDS.items()}

TERRAIN_X_MIN = -400.0
TERRAIN_X_MAX = 400.0
TERRAIN_Y_MIN = -620.0
TERRAIN_Y_MAX = 180.0
TERRAIN_STEP = 5.0
HILL_HEIGHT = 32.0
HILL_PLATEAU_RADIUS = 14.0
HILL_BASE_RADIUS = 110.0
SUMMIT_HEIGHT = -0.08
FOREST_INNER_RADIUS = 104.0
FOREST_OUTER_RADIUS = 158.0
FOREST_TREE_COUNT = 360

MATERIALS: dict[str, bpy.types.Material] = {}
EXPORT_OBJECTS: list[bpy.types.Object] = []


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    t = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a: float, b: float, weight: float) -> float:
    return a + (b - a) * weight


def distance_2d(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def polyline_length(points: list[tuple[float, ...]]) -> float:
    total = 0.0
    for a, b in zip(points, points[1:]):
        total += math.sqrt(sum((b[index] - a[index]) ** 2 for index in range(len(a))))
    return total


def normalize_2d(vector: tuple[float, float]) -> tuple[float, float]:
    length = math.hypot(vector[0], vector[1])
    if length <= 0.000001:
        return (0.0, -1.0)
    return (vector[0] / length, vector[1] / length)


def rotate_2d(point: tuple[float, float], angle: float) -> tuple[float, float]:
    cosine = math.cos(angle)
    sine = math.sin(angle)
    return (
        point[0] * cosine - point[1] * sine,
        point[0] * sine + point[1] * cosine,
    )


def local_to_world(
    center: tuple[float, float],
    right: tuple[float, float],
    forward: tuple[float, float],
    local_right: float,
    local_forward: float,
) -> tuple[float, float]:
    return (
        center[0] + right[0] * local_right + forward[0] * local_forward,
        center[1] + right[1] * local_right + forward[1] * local_forward,
    )


def catmull_rom(
    controls: list[tuple[float, float]], samples_per_segment: int = 24
) -> list[tuple[float, float]]:
    padded = [controls[0], *controls, controls[-1]]
    result: list[tuple[float, float]] = []
    for index in range(1, len(padded) - 2):
        p0 = padded[index - 1]
        p1 = padded[index]
        p2 = padded[index + 1]
        p3 = padded[index + 2]
        for sample in range(samples_per_segment):
            t = sample / samples_per_segment
            t2 = t * t
            t3 = t2 * t
            x = 0.5 * (
                2.0 * p1[0]
                + (-p0[0] + p2[0]) * t
                + (2.0 * p0[0] - 5.0 * p1[0] + 4.0 * p2[0] - p3[0]) * t2
                + (-p0[0] + 3.0 * p1[0] - 3.0 * p2[0] + p3[0]) * t3
            )
            y = 0.5 * (
                2.0 * p1[1]
                + (-p0[1] + p2[1]) * t
                + (2.0 * p0[1] - 5.0 * p1[1] + 4.0 * p2[1] - p3[1]) * t2
                + (-p0[1] + 3.0 * p1[1] - 3.0 * p2[1] + p3[1]) * t3
            )
            result.append((x, y))
    result.append(controls[-1])
    return result


def scale_polyline(
    points: list[tuple[float, float]], target_length: float
) -> list[tuple[float, float]]:
    current_length = polyline_length(points)
    scale = target_length / current_length
    origin = points[0]
    return [
        (
            origin[0] + (point[0] - origin[0]) * scale,
            origin[1] + (point[1] - origin[1]) * scale,
        )
        for point in points
    ]


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def create_collection(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    if parent is None:
        bpy.context.scene.collection.children.link(collection)
    else:
        parent.children.link(collection)
    return collection


def create_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.9,
    albedo_image: bpy.types.Image | None = None,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name=name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    if albedo_image is not None:
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.name = "Dark moss and earth albedo"
        texture.image = albedo_image
        texture.interpolation = "Linear"
        texture.extension = "REPEAT"
        material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    MATERIALS[name] = material
    return material


def create_ground_texture(size: int = 512) -> bpy.types.Image:
    """Build a seamless, low-frequency moss and damp-earth albedo texture."""
    GROUND_TEXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.new("homestead_ground_dark", width=size, height=size, alpha=True)
    pixels: list[float] = []
    moss = (0.115, 0.185, 0.115)
    earth = (0.18, 0.115, 0.075)
    stone = (0.22, 0.225, 0.205)
    texture_random = random.Random(SEED + 91)
    waves: list[tuple[int, int, float, float]] = []
    for frequency_min, frequency_max, amplitude, count in (
        (1, 4, 1.0, 10),
        (5, 12, 0.42, 14),
        (13, 30, 0.16, 18),
    ):
        for _wave in range(count):
            wave_x = texture_random.randint(frequency_min, frequency_max)
            wave_y = texture_random.randint(frequency_min, frequency_max)
            if texture_random.random() < 0.5:
                wave_x = -wave_x
            if texture_random.random() < 0.5:
                wave_y = -wave_y
            phase = texture_random.uniform(0.0, math.tau)
            waves.append((wave_x, wave_y, phase, amplitude))
    amplitude_total = sum(wave[3] for wave in waves)
    for y in range(size):
        v = y / size * math.tau
        for x in range(size):
            u = x / size * math.tau
            noise = sum(
                math.cos(wave_x * u + wave_y * v + phase) * amplitude
                for wave_x, wave_y, phase, amplitude in waves
            ) / amplitude_total
            moss_weight = smoothstep(-0.16, 0.18, noise)
            detail = sum(
                math.cos(wave_x * u - wave_y * v + phase * 1.73) * amplitude
                for wave_x, wave_y, phase, amplitude in waves[24:]
            ) / sum(wave[3] for wave in waves[24:])
            stone_weight = smoothstep(0.18, 0.27, detail) * 0.55 * (1.0 - moss_weight * 0.72)
            color = tuple(
                lerp(lerp(earth[channel], moss[channel], moss_weight), stone[channel], stone_weight)
                for channel in range(3)
            )
            pixels.extend((*color, 1.0))
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(GROUND_TEXTURE_PATH)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def restyle_tree_materials(mesh: bpy.types.Mesh) -> None:
    for material in mesh.materials:
        if material is None:
            continue
        material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        material_name = material.name.lower()
        if "leaf" in material_name or "leaves" in material_name:
            color = (0.035, 0.105, 0.060, 1.0)
        else:
            color = (0.11, 0.055, 0.035, 1.0)
        material.diffuse_color = color
        if shader is not None:
            shader.inputs["Base Color"].default_value = color
            shader.inputs["Roughness"].default_value = 0.98


def create_empty(name: str, collection: bpy.types.Collection, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 4.0
    obj.parent = parent
    EXPORT_OBJECTS.append(obj)
    return obj


def create_mesh_object(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object | None,
    smooth: bool = False,
    uvs: list[tuple[float, float]] | None = None,
    export: bool = True,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    if uvs is not None:
        uv_layer = mesh.uv_layers.new(name="UVMap")
        for polygon in mesh.polygons:
            for loop_index in polygon.loop_indices:
                vertex_index = mesh.loops[loop_index].vertex_index
                uv_layer.data[loop_index].uv = uvs[vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    if export:
        EXPORT_OBJECTS.append(obj)
    return obj


def load_tree_model_meshes(
) -> list[
    tuple[
        bpy.types.Mesh,
        tuple[float, float, float],
        Quaternion,
        float,
        str,
    ]
]:
    tree_meshes: list[
        tuple[
            bpy.types.Mesh,
            tuple[float, float, float],
            Quaternion,
            float,
            str,
        ]
    ] = []
    for model_path in TREE_MODEL_PATHS:
        bpy.ops.import_scene.gltf(filepath=str(model_path))
        imported_objects = list(bpy.context.selected_objects)
        imported_meshes = [obj for obj in imported_objects if obj.type == "MESH"]
        if len(imported_meshes) != 1:
            raise RuntimeError(f"Expected one mesh in {model_path}, found {len(imported_meshes)}")
        imported_object = imported_meshes[0]
        mesh = imported_object.data
        mesh.name = f"forest_{model_path.stem}_mesh"
        restyle_tree_materials(mesh)
        source_scale = tuple(float(component) for component in imported_object.scale)
        source_rotation = imported_object.rotation_quaternion.copy()
        source_transform = Matrix.LocRotScale(
            Vector((0.0, 0.0, 0.0)),
            source_rotation,
            Vector(source_scale),
        )
        minimum_z = min((source_transform @ vertex.co).z for vertex in mesh.vertices)
        tree_meshes.append(
            (mesh, source_scale, source_rotation, minimum_z, model_path.name)
        )
        for obj in imported_objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    return tree_meshes


def append_box(
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    angle: float = 0.0,
) -> None:
    offset = len(vertices)
    half_x = size[0] * 0.5
    half_y = size[1] * 0.5
    half_z = size[2] * 0.5
    corners = [
        (-half_x, -half_y, -half_z),
        (half_x, -half_y, -half_z),
        (half_x, half_y, -half_z),
        (-half_x, half_y, -half_z),
        (-half_x, -half_y, half_z),
        (half_x, -half_y, half_z),
        (half_x, half_y, half_z),
        (-half_x, half_y, half_z),
    ]
    for x, y, z in corners:
        rotated_x, rotated_y = rotate_2d((x, y), angle)
        vertices.append((center[0] + rotated_x, center[1] + rotated_y, center[2] + z))
    faces.extend(
        [
            (offset + 0, offset + 1, offset + 2, offset + 3),
            (offset + 4, offset + 7, offset + 6, offset + 5),
            (offset + 0, offset + 4, offset + 5, offset + 1),
            (offset + 1, offset + 5, offset + 6, offset + 2),
            (offset + 2, offset + 6, offset + 7, offset + 3),
            (offset + 4, offset + 0, offset + 3, offset + 7),
        ]
    )


def append_cylinder(
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    sides: int = 8,
) -> None:
    offset = len(vertices)
    bottom_z = center[2] - depth * 0.5
    top_z = center[2] + depth * 0.5
    for level_z in (bottom_z, top_z):
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append(
                (center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius, level_z)
            )
    faces.append(tuple(offset + index for index in reversed(range(sides))))
    faces.append(tuple(offset + sides + index for index in range(sides)))
    for index in range(sides):
        next_index = (index + 1) % sides
        faces.append(
            (
                offset + index,
                offset + next_index,
                offset + sides + next_index,
                offset + sides + index,
            )
        )


def append_cone(
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    center: tuple[float, float, float],
    bottom_radius: float,
    top_radius: float,
    depth: float,
    sides: int = 8,
) -> None:
    offset = len(vertices)
    bottom_z = center[2] - depth * 0.5
    top_z = center[2] + depth * 0.5
    for radius, level_z in ((bottom_radius, bottom_z), (top_radius, top_z)):
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append(
                (center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius, level_z)
            )
    faces.append(tuple(offset + index for index in reversed(range(sides))))
    faces.append(tuple(offset + sides + index for index in range(sides)))
    for index in range(sides):
        next_index = (index + 1) % sides
        faces.append(
            (
                offset + index,
                offset + next_index,
                offset + sides + next_index,
                offset + sides + index,
            )
        )


def append_gable_roof(
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    center: tuple[float, float, float],
    width: float,
    depth: float,
    height: float,
    angle: float,
) -> None:
    offset = len(vertices)
    half_width = width * 0.5
    half_depth = depth * 0.5
    local_vertices = [
        (-half_width, -half_depth, 0.0),
        (half_width, -half_depth, 0.0),
        (0.0, -half_depth, height),
        (-half_width, half_depth, 0.0),
        (half_width, half_depth, 0.0),
        (0.0, half_depth, height),
    ]
    for x, y, z in local_vertices:
        rotated_x, rotated_y = rotate_2d((x, y), angle)
        vertices.append((center[0] + rotated_x, center[1] + rotated_y, center[2] + z))
    faces.extend(
        [
            (offset + 0, offset + 1, offset + 2),
            (offset + 5, offset + 4, offset + 3),
            (offset + 0, offset + 3, offset + 4, offset + 1),
            (offset + 0, offset + 2, offset + 5, offset + 3),
            (offset + 1, offset + 4, offset + 5, offset + 2),
        ]
    )


ROUTE_CONTROL_POINTS = {
    "woods": [
        (2.0, -7.0),
        (18.0, -17.0),
        (43.0, -21.0),
        (70.0, -31.0),
        (99.0, -49.0),
    ],
    "farm": [
        (-2.0, -7.0),
        (-23.0, -30.0),
        (-57.0, -48.0),
        (-93.0, -69.0),
        (-139.0, -89.0),
        (-190.0, -116.0),
    ],
    "village": [
        (0.0, -7.0),
        (10.0, -54.0),
        (-6.0, -113.0),
        (16.0, -178.0),
        (5.0, -247.0),
        (-12.0, -326.0),
        (0.0, -427.0),
    ],
}

ROUTE_WIDTHS = {
    "woods": 3.6,
    "farm": 4.6,
    "village": 5.8,
}

def natural_height(x: float, y: float) -> float:
    radius = math.hypot(x, y)
    rolling = (
        0.65 * math.sin(x * 0.033 + 0.8) * math.cos(y * 0.026 - 0.3)
        + 0.34 * math.sin((x + y) * 0.061)
        + 0.22 * math.cos((x - y) * 0.095)
    )
    if radius <= HILL_PLATEAU_RADIUS:
        return SUMMIT_HEIGHT

    hill_progress = clamp(
        (radius - HILL_PLATEAU_RADIUS) / (HILL_BASE_RADIUS - HILL_PLATEAU_RADIUS),
        0.0,
        1.0,
    )
    eased_descent = 0.5 - 0.5 * math.cos(math.pi * hill_progress)
    hill_height = SUMMIT_HEIGHT - HILL_HEIGHT * eased_descent
    rolling_weight = smoothstep(HILL_PLATEAU_RADIUS + 12.0, HILL_BASE_RADIUS, radius)
    return hill_height + rolling * rolling_weight


def fit_route_to_3d_length(
    controls: list[tuple[float, float]], target_length: float
) -> list[tuple[float, float]]:
    points = scale_polyline(catmull_rom(controls), target_length)
    for _iteration in range(8):
        route_3d = [(x, y, natural_height(x, y)) for x, y in points]
        current_3d_length = polyline_length(route_3d)
        current_2d_length = polyline_length(points)
        points = scale_polyline(
            points,
            current_2d_length * target_length / current_3d_length,
        )
    return points


ROUTES_2D = {
    name: fit_route_to_3d_length(controls, TARGET_LENGTHS[name])
    for name, controls in ROUTE_CONTROL_POINTS.items()
}


def endpoint_direction(route_name: str) -> tuple[float, float]:
    points = ROUTES_2D[route_name]
    return normalize_2d((points[-1][0] - points[-8][0], points[-1][1] - points[-8][1]))


FARM_FORWARD = endpoint_direction("farm")
FARM_RIGHT = (-FARM_FORWARD[1], FARM_FORWARD[0])
FARM_GATE = ROUTES_2D["farm"][-1]
FARM_CENTER = local_to_world(FARM_GATE, FARM_RIGHT, FARM_FORWARD, 0.0, 48.0)

VILLAGE_FORWARD = endpoint_direction("village")
VILLAGE_RIGHT = (-VILLAGE_FORWARD[1], VILLAGE_FORWARD[0])
VILLAGE_GATE = ROUTES_2D["village"][-1]
VILLAGE_CENTER = local_to_world(VILLAGE_GATE, VILLAGE_RIGHT, VILLAGE_FORWARD, 0.0, 28.0)

WOODS_FORWARD = endpoint_direction("woods")
WOODS_RIGHT = (-WOODS_FORWARD[1], WOODS_FORWARD[0])
WOODS_GATE = ROUTES_2D["woods"][-1]
WOODS_CENTER = local_to_world(WOODS_GATE, WOODS_RIGHT, WOODS_FORWARD, 0.0, 15.0)


def destination_flattened_height(x: float, y: float) -> float:
    height = natural_height(x, y)

    farm_dx = (x - FARM_CENTER[0]) * FARM_RIGHT[0] + (y - FARM_CENTER[1]) * FARM_RIGHT[1]
    farm_dy = (x - FARM_CENTER[0]) * FARM_FORWARD[0] + (y - FARM_CENTER[1]) * FARM_FORWARD[1]
    farm_radius = math.sqrt((farm_dx / 66.0) ** 2 + (farm_dy / 78.0) ** 2)
    farm_weight = 1.0 - smoothstep(0.74, 1.05, farm_radius)
    farm_level = natural_height(FARM_CENTER[0], FARM_CENTER[1])
    height = lerp(height, farm_level, farm_weight)

    village_distance = math.hypot(x - VILLAGE_CENTER[0], y - VILLAGE_CENTER[1])
    village_weight = 1.0 - smoothstep(48.0, 64.0, village_distance)
    village_level = natural_height(VILLAGE_CENTER[0], VILLAGE_CENTER[1])
    height = lerp(height, village_level, village_weight)
    return height


def smooth_values(values: list[float], radius: int = 5) -> list[float]:
    result: list[float] = []
    for index in range(len(values)):
        start = max(0, index - radius)
        end = min(len(values), index + radius + 1)
        result.append(sum(values[start:end]) / (end - start))
    return result


ROUTES_3D: dict[str, list[tuple[float, float, float]]] = {}
for route_name, points in ROUTES_2D.items():
    heights = smooth_values([destination_flattened_height(x, y) for x, y in points])
    ROUTES_3D[route_name] = [(point[0], point[1], heights[index]) for index, point in enumerate(points)]


def nearest_route_sample(
    x: float, y: float, route: list[tuple[float, float, float]]
) -> tuple[float, float]:
    nearest_distance_squared = float("inf")
    nearest_height = route[0][2]
    for a, b in zip(route, route[1:]):
        segment_x = b[0] - a[0]
        segment_y = b[1] - a[1]
        segment_length_squared = segment_x * segment_x + segment_y * segment_y
        if segment_length_squared <= 0.000001:
            continue
        t = clamp(
            ((x - a[0]) * segment_x + (y - a[1]) * segment_y) / segment_length_squared,
            0.0,
            1.0,
        )
        closest_x = a[0] + segment_x * t
        closest_y = a[1] + segment_y * t
        distance_squared = (x - closest_x) ** 2 + (y - closest_y) ** 2
        if distance_squared < nearest_distance_squared:
            nearest_distance_squared = distance_squared
            nearest_height = lerp(a[2], b[2], t)
    return math.sqrt(nearest_distance_squared), nearest_height


def terrain_height(x: float, y: float) -> float:
    height = destination_flattened_height(x, y)
    strongest_weight = 0.0
    strongest_height = height
    for route_name, route in ROUTES_3D.items():
        distance, route_height = nearest_route_sample(x, y, route)
        flat_radius = ROUTE_WIDTHS[route_name] * 0.5 + 3.0
        corridor = ROUTE_WIDTHS[route_name] * 0.5 + 9.0
        weight = 1.0 - smoothstep(flat_radius, corridor, distance)
        if weight > strongest_weight:
            strongest_weight = weight
            strongest_height = route_height
    return lerp(height, strongest_height, strongest_weight)


def create_terrain(collection: bpy.types.Collection, parent: bpy.types.Object) -> bpy.types.Object:
    x_count = int(round((TERRAIN_X_MAX - TERRAIN_X_MIN) / TERRAIN_STEP)) + 1
    y_count = int(round((TERRAIN_Y_MAX - TERRAIN_Y_MIN) / TERRAIN_STEP)) + 1
    vertices: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    for y_index in range(y_count):
        y = TERRAIN_Y_MIN + y_index * TERRAIN_STEP
        for x_index in range(x_count):
            x = TERRAIN_X_MIN + x_index * TERRAIN_STEP
            vertices.append((x, y, terrain_height(x, y)))
            uvs.append((x / 46.0, y / 46.0))
    faces: list[tuple[int, ...]] = []
    for y_index in range(y_count - 1):
        for x_index in range(x_count - 1):
            bottom_left = y_index * x_count + x_index
            bottom_right = bottom_left + 1
            top_left = bottom_left + x_count
            top_right = top_left + 1
            if (x_index + y_index) % 2 == 0:
                faces.append((bottom_left, bottom_right, top_right))
                faces.append((bottom_left, top_right, top_left))
            else:
                faces.append((bottom_left, bottom_right, top_left))
                faces.append((bottom_right, top_right, top_left))
    return create_mesh_object(
        "terrain-ground-col",
        vertices,
        faces,
        MATERIALS["grass_moss"],
        collection,
        parent,
        smooth=True,
        uvs=uvs,
    )


def create_path_mesh(
    route_name: str, collection: bpy.types.Collection, parent: bpy.types.Object
) -> bpy.types.Object:
    route = ROUTES_3D[route_name]
    width = ROUTE_WIDTHS[route_name]
    vertices: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    accumulated = 0.0
    for index, point in enumerate(route):
        previous = route[max(0, index - 1)]
        following = route[min(len(route) - 1, index + 1)]
        tangent = normalize_2d((following[0] - previous[0], following[1] - previous[1]))
        normal = (-tangent[1], tangent[0])
        if index > 0:
            accumulated += distance_2d((route[index - 1][0], route[index - 1][1]), (point[0], point[1]))
        left = (point[0] + normal[0] * width * 0.5, point[1] + normal[1] * width * 0.5)
        right = (point[0] - normal[0] * width * 0.5, point[1] - normal[1] * width * 0.5)
        vertices.append((left[0], left[1], point[2] + 0.10))
        vertices.append((right[0], right[1], point[2] + 0.10))
        uvs.append((0.0, accumulated / 4.0))
        uvs.append((1.0, accumulated / 4.0))
    faces = [
        (index * 2, index * 2 + 1, index * 2 + 3, index * 2 + 2)
        for index in range(len(route) - 1)
    ]
    return create_mesh_object(
        f"path_{route_name}",
        vertices,
        faces,
        MATERIALS[f"path_{route_name}"],
        collection,
        parent,
        smooth=True,
        uvs=uvs,
    )


def create_woods(
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    rng: random.Random,
    tree_meshes: list[
        tuple[
            bpy.types.Mesh,
            tuple[float, float, float],
            Quaternion,
            float,
            str,
        ]
    ],
) -> None:
    collision_clusters = 8
    collision_geometry = [([], []) for _ in range(collision_clusters)]
    accepted: list[tuple[float, float, float, float]] = []
    attempts = 0
    while len(accepted) < FOREST_TREE_COUNT and attempts < 18000:
        attempts += 1
        radius = math.sqrt(
            rng.uniform(FOREST_INNER_RADIUS**2, FOREST_OUTER_RADIUS**2)
        )
        angle = rng.uniform(-math.pi, math.pi)
        x = math.cos(angle) * radius
        y = math.sin(angle) * radius
        nearest_path_distance = min(
            nearest_route_sample(x, y, route)[0]
            for route in ROUTES_3D.values()
        )
        if nearest_path_distance < 9.0:
            continue
        if any(math.hypot(x - other[0], y - other[1]) < 4.2 for other in accepted):
            continue
        accepted.append((x, y, terrain_height(x, y), angle))

    if len(accepted) != FOREST_TREE_COUNT:
        raise RuntimeError(
            f"Placed {len(accepted)} of {FOREST_TREE_COUNT} requested forest trees"
        )

    for index, (x, y, ground_z, radial_angle) in enumerate(accepted):
        tree_mesh, source_scale, source_rotation, minimum_z, source_name = tree_meshes[
            index % len(tree_meshes)
        ]
        scale = rng.uniform(0.88, 1.24)
        yaw = radial_angle + rng.uniform(-math.pi, math.pi)
        tree = bpy.data.objects.new(f"forest_tree_{index + 1:03d}", tree_mesh)
        collection.objects.link(tree)
        tree.parent = parent
        tree.location = (x, y, ground_z - minimum_z * scale)
        tree.rotation_mode = "QUATERNION"
        tree.rotation_quaternion = Quaternion((0.0, 0.0, 1.0), yaw) @ source_rotation
        tree.scale = tuple(component * scale for component in source_scale)
        tree["source_tree_model"] = source_name
        tree["source_rotation_preserved"] = True
        tree["forest_ring_radius_m"] = round(math.hypot(x, y), 3)
        EXPORT_OBJECTS.append(tree)

        collision_vertices, collision_faces = collision_geometry[index % collision_clusters]
        append_cylinder(
            collision_vertices,
            collision_faces,
            (x, y, ground_z + 1.35 * scale),
            0.38 * scale,
            2.7 * scale,
            sides=7,
        )

    for index, (collision_vertices, collision_faces) in enumerate(collision_geometry):
        create_mesh_object(
            f"forest_trunks_{index + 1}-col",
            collision_vertices,
            collision_faces,
            MATERIALS["bark_dark"],
            collection,
            parent,
        )

    marker_vertices: list[tuple[float, float, float]] = []
    marker_faces: list[tuple[int, ...]] = []
    marker_z = terrain_height(WOODS_GATE[0], WOODS_GATE[1])
    append_box(marker_vertices, marker_faces, (WOODS_GATE[0], WOODS_GATE[1], marker_z + 1.6), (4.8, 0.5, 0.7), math.atan2(WOODS_FORWARD[1], WOODS_FORWARD[0]))
    create_mesh_object("woods_waystone", marker_vertices, marker_faces, MATERIALS["stone_cool"], collection, parent)


def create_farm(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    forward_angle = math.atan2(FARM_FORWARD[1], FARM_FORWARD[0]) - math.pi * 0.5
    farm_level = terrain_height(FARM_CENTER[0], FARM_CENTER[1])

    soil_vertices: list[tuple[float, float, float]] = []
    soil_faces: list[tuple[int, ...]] = []
    crop_vertices: list[tuple[float, float, float]] = []
    crop_faces: list[tuple[int, ...]] = []
    plot_centers = [(-24.0, -26.0), (24.0, -26.0), (-24.0, 28.0), (24.0, 28.0)]
    for plot_index, (local_right, local_forward) in enumerate(plot_centers):
        x, y = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, local_right, local_forward)
        append_box(soil_vertices, soil_faces, (x, y, farm_level + 0.18), (38.0, 46.0, 0.35), forward_angle)
        for row in range(9):
            row_right = local_right - 16.0 + row * 4.0
            row_x, row_y = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, row_right, local_forward)
            append_box(
                crop_vertices,
                crop_faces,
                (row_x, row_y, farm_level + 0.65),
                (0.75, 40.0, 0.9 + (plot_index % 2) * 0.2),
                forward_angle,
            )
    create_mesh_object("farm_soil", soil_vertices, soil_faces, MATERIALS["soil_rich"], collection, parent)
    create_mesh_object("farm_crops", crop_vertices, crop_faces, MATERIALS["crop_green"], collection, parent)

    fence_vertices: list[tuple[float, float, float]] = []
    fence_faces: list[tuple[int, ...]] = []
    half_width = 52.0
    half_depth = 61.0
    for local_forward in (-half_depth, half_depth):
        for local_right in range(-50, 51, 5):
            x, y = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, float(local_right), local_forward)
            append_box(fence_vertices, fence_faces, (x, y, farm_level + 1.0), (0.35, 0.35, 2.0), forward_angle)
        for rail_height in (0.65, 1.35):
            x, y = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, 0.0, local_forward)
            append_box(fence_vertices, fence_faces, (x, y, farm_level + rail_height), (104.0, 0.25, 0.25), forward_angle)
    for local_right in (-half_width, half_width):
        for local_forward in range(-60, 61, 5):
            x, y = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, local_right, float(local_forward))
            append_box(fence_vertices, fence_faces, (x, y, farm_level + 1.0), (0.35, 0.35, 2.0), forward_angle)
        for rail_height in (0.65, 1.35):
            x, y = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, local_right, 0.0)
            append_box(fence_vertices, fence_faces, (x, y, farm_level + rail_height), (0.25, 122.0, 0.25), forward_angle)
    create_mesh_object("farm_fence-col", fence_vertices, fence_faces, MATERIALS["wood_weathered"], collection, parent)

    barn_center = local_to_world(FARM_CENTER, FARM_RIGHT, FARM_FORWARD, 0.0, 78.0)
    barn_vertices: list[tuple[float, float, float]] = []
    barn_faces: list[tuple[int, ...]] = []
    append_box(barn_vertices, barn_faces, (barn_center[0], barn_center[1], farm_level + 4.5), (18.0, 24.0, 9.0), forward_angle)
    create_mesh_object("farm_barn_walls-col", barn_vertices, barn_faces, MATERIALS["barn_red"], collection, parent)
    roof_vertices: list[tuple[float, float, float]] = []
    roof_faces: list[tuple[int, ...]] = []
    append_gable_roof(roof_vertices, roof_faces, (barn_center[0], barn_center[1], farm_level + 9.0), 21.0, 27.0, 5.0, forward_angle)
    create_mesh_object("farm_barn_roof-col", roof_vertices, roof_faces, MATERIALS["roof_dark"], collection, parent)


def create_village(collection: bpy.types.Collection, parent: bpy.types.Object, rng: random.Random) -> None:
    village_level = terrain_height(VILLAGE_CENTER[0], VILLAGE_CENTER[1])
    plaza_vertices: list[tuple[float, float, float]] = []
    plaza_faces: list[tuple[int, ...]] = []
    append_cylinder(plaza_vertices, plaza_faces, (VILLAGE_CENTER[0], VILLAGE_CENTER[1], village_level + 0.06), 20.0, 0.12, sides=24)
    create_mesh_object("village_plaza", plaza_vertices, plaza_faces, MATERIALS["stone_path"], collection, parent)

    wall_vertices: list[tuple[float, float, float]] = []
    wall_faces: list[tuple[int, ...]] = []
    roof_vertices: list[tuple[float, float, float]] = []
    roof_faces: list[tuple[int, ...]] = []
    house_count = 14
    for index in range(house_count):
        ring_angle = math.tau * index / house_count + rng.uniform(-0.10, 0.10)
        radius = 34.0 + (index % 3) * 8.0 + rng.uniform(-2.0, 2.0)
        x = VILLAGE_CENTER[0] + math.cos(ring_angle) * radius
        y = VILLAGE_CENTER[1] + math.sin(ring_angle) * radius
        ground_z = terrain_height(x, y)
        width = rng.uniform(7.0, 10.5)
        depth = rng.uniform(8.0, 12.0)
        wall_height = rng.uniform(4.5, 6.5)
        facing_angle = ring_angle + math.pi * 0.5
        append_box(wall_vertices, wall_faces, (x, y, ground_z + wall_height * 0.5), (width, depth, wall_height), facing_angle)
        append_gable_roof(roof_vertices, roof_faces, (x, y, ground_z + wall_height), width + 1.8, depth + 1.8, 3.2, facing_angle)
    create_mesh_object("village_house_walls-col", wall_vertices, wall_faces, MATERIALS["plaster_warm"], collection, parent)
    create_mesh_object("village_house_roofs-col", roof_vertices, roof_faces, MATERIALS["roof_village"], collection, parent)

    well_vertices: list[tuple[float, float, float]] = []
    well_faces: list[tuple[int, ...]] = []
    append_cylinder(well_vertices, well_faces, (VILLAGE_CENTER[0], VILLAGE_CENTER[1], village_level + 0.8), 2.4, 1.6, sides=16)
    create_mesh_object("village_well-col", well_vertices, well_faces, MATERIALS["stone_cool"], collection, parent)


def create_landmarks(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    junction_x = 0.0
    junction_y = -10.5
    junction_z = terrain_height(junction_x, junction_y)
    pad_vertices: list[tuple[float, float, float]] = []
    pad_faces: list[tuple[int, ...]] = []
    append_cylinder(
        pad_vertices,
        pad_faces,
        (junction_x, junction_y, junction_z + 0.09),
        7.0,
        0.18,
        sides=24,
    )
    create_mesh_object(
        "tower_crossroads_clearing",
        pad_vertices,
        pad_faces,
        MATERIALS["path_village"],
        collection,
        parent,
    )

    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    append_cylinder(vertices, faces, (junction_x, junction_y, junction_z + 1.8), 0.28, 3.6, sides=8)
    append_box(vertices, faces, (junction_x + 0.7, junction_y, junction_z + 2.8), (2.8, 0.35, 0.55), 0.0)
    append_box(vertices, faces, (junction_x - 0.7, junction_y, junction_z + 2.15), (2.8, 0.35, 0.55), 0.0)
    create_mesh_object("tower_crossroads_sign-col", vertices, faces, MATERIALS["wood_weathered"], collection, parent)


def create_reference_tower(collection: bpy.types.Collection) -> None:
    tower_material = create_material("reference_tower", (0.20, 0.26, 0.38, 1.0), 0.82)
    roof_material = create_material("reference_roof", (0.13, 0.08, 0.19, 1.0), 0.88)
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    append_cylinder(vertices, faces, (0.0, 0.0, 4.0), 6.0, 8.0, sides=8)
    create_mesh_object("REFERENCE_tower", vertices, faces, tower_material, collection, None, export=False)
    roof_vertices: list[tuple[float, float, float]] = []
    roof_faces: list[tuple[int, ...]] = []
    append_cone(roof_vertices, roof_faces, (0.0, 0.0, 10.0), 7.2, 0.35, 4.0, sides=8)
    create_mesh_object("REFERENCE_tower_roof", roof_vertices, roof_faces, roof_material, collection, None, export=False)


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_render() -> tuple[bpy.types.Object, bpy.types.Object]:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.055, 0.085, 0.13)
    scene.view_settings.look = "AgX - Medium High Contrast"

    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 300.0))
    sun = bpy.context.object
    sun.name = "PREVIEW_sun"
    sun.rotation_euler = (math.radians(28.0), math.radians(-22.0), math.radians(-28.0))
    sun.data.energy = 2.4
    sun.data.color = (1.0, 0.82, 0.62)

    bpy.ops.object.light_add(type="AREA", location=(-100.0, -160.0, 260.0))
    fill = bpy.context.object
    fill.name = "PREVIEW_fill"
    fill.data.energy = 2400.0
    fill.data.shape = "DISK"
    fill.data.size = 180.0
    look_at(fill, (0.0, -220.0, -5.0))

    bpy.ops.object.camera_add(location=(0.0, -220.0, 800.0))
    overview_camera = bpy.context.object
    overview_camera.name = "PREVIEW_overview_camera"
    overview_camera.data.type = "ORTHO"
    overview_camera.data.ortho_scale = 820.0
    overview_camera.rotation_euler = (0.0, 0.0, 0.0)

    bpy.ops.object.camera_add(location=(0.0, -126.0, -14.2))
    hill_camera = bpy.context.object
    hill_camera.name = "PREVIEW_hill_camera"
    hill_camera.data.lens = 52.0
    look_at(hill_camera, (0.0, 0.0, 3.5))
    return overview_camera, hill_camera


def export_glb() -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in EXPORT_OBJECTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = EXPORT_OBJECTS[0]
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )


def write_layout_manifest() -> None:
    routes = {}
    for name, route in ROUTES_3D.items():
        blender_endpoint = route[-1]
        godot_endpoint = (blender_endpoint[0], blender_endpoint[2], -blender_endpoint[1])
        route_length_3d = polyline_length(route)
        routes[name] = {
            "target_seconds": TARGET_SECONDS[name],
            "target_length_m": TARGET_LENGTHS[name],
            "generated_length_m": round(route_length_3d, 3),
            "expected_walk_seconds": round(route_length_3d / MOVE_SPEED, 3),
            "blender_endpoint_xyz": [round(value, 3) for value in blender_endpoint],
            "godot_endpoint_xyz": [round(value, 3) for value in godot_endpoint],
        }
    manifest = {
        "seed": SEED,
        "player_move_speed_mps": MOVE_SPEED,
        "tower_origin_godot_xyz": [0.0, 0.0, 0.0],
        "hill": {
            "height_m": HILL_HEIGHT,
            "plateau_radius_m": HILL_PLATEAU_RADIUS,
            "base_radius_m": HILL_BASE_RADIUS,
            "summit_height_m": SUMMIT_HEIGHT,
        },
        "forest": {
            "tree_count": FOREST_TREE_COUNT,
            "inner_radius_m": FOREST_INNER_RADIUS,
            "outer_radius_m": FOREST_OUTER_RADIUS,
            "source_models": [path.name for path in TREE_MODEL_PATHS],
        },
        "terrain_bounds_blender_xy": [
            TERRAIN_X_MIN,
            TERRAIN_Y_MIN,
            TERRAIN_X_MAX,
            TERRAIN_Y_MAX,
        ],
        "routes": routes,
    }
    LAYOUT_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    random_generator = random.Random(SEED)
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    ground_texture = create_ground_texture()

    reset_scene()

    export_collection = create_collection("EXPORT")
    terrain_collection = create_collection("Terrain", export_collection)
    paths_collection = create_collection("Paths", export_collection)
    woods_collection = create_collection("Woods", export_collection)
    farm_collection = create_collection("Farm", export_collection)
    village_collection = create_collection("Village", export_collection)
    landmarks_collection = create_collection("Landmarks", export_collection)
    reference_collection = create_collection("REFERENCE")

    create_material("grass_moss", (0.12, 0.18, 0.12, 1.0), 0.98, ground_texture)
    create_material("path_woods", (0.16, 0.105, 0.065, 1.0), 1.0)
    create_material("path_farm", (0.22, 0.16, 0.085, 1.0), 1.0)
    create_material("path_village", (0.19, 0.17, 0.14, 1.0), 0.98)
    create_material("bark_dark", (0.075, 0.035, 0.025, 1.0), 0.98)
    create_material("pine_deep", (0.035, 0.105, 0.060, 1.0), 0.98)
    create_material("pine_mid", (0.055, 0.14, 0.075, 1.0), 0.98)
    create_material("stone_cool", (0.18, 0.20, 0.21, 1.0), 0.96)
    create_material("stone_path", (0.22, 0.23, 0.22, 1.0), 0.98)
    create_material("soil_rich", (0.085, 0.042, 0.028, 1.0), 1.0)
    create_material("crop_green", (0.12, 0.19, 0.055, 1.0), 0.98)
    create_material("wood_weathered", (0.15, 0.095, 0.055, 1.0), 0.98)
    create_material("barn_red", (0.20, 0.045, 0.035, 1.0), 0.96)
    create_material("roof_dark", (0.055, 0.042, 0.045, 1.0), 0.98)
    create_material("plaster_warm", (0.30, 0.25, 0.19, 1.0), 0.97)
    create_material("roof_village", (0.13, 0.055, 0.040, 1.0), 0.98)
    tree_meshes = load_tree_model_meshes()

    root = create_empty("ExteriorHomestead", export_collection)
    root["generation_seed"] = SEED
    root["player_move_speed_mps"] = MOVE_SPEED

    terrain_root = create_empty("Terrain", terrain_collection, root)
    paths_root = create_empty("Paths", paths_collection, root)
    woods_root = create_empty("Woods", woods_collection, root)
    farm_root = create_empty("Farm", farm_collection, root)
    village_root = create_empty("Village", village_collection, root)
    landmarks_root = create_empty("Landmarks", landmarks_collection, root)

    create_terrain(terrain_collection, terrain_root)
    for route_name in ("woods", "farm", "village"):
        path_object = create_path_mesh(route_name, paths_collection, paths_root)
        path_object["target_walk_seconds"] = TARGET_SECONDS[route_name]
        path_object["route_length_m"] = polyline_length(ROUTES_3D[route_name])
    create_woods(woods_collection, woods_root, random_generator, tree_meshes)
    create_farm(farm_collection, farm_root)
    create_village(village_collection, village_root, random_generator)
    create_landmarks(landmarks_collection, landmarks_root)
    create_reference_tower(reference_collection)

    overview_camera, hill_camera = configure_render()
    write_layout_manifest()
    export_glb()

    scene = bpy.context.scene
    scene.camera = overview_camera
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1400
    scene.render.filepath = str(OVERVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    scene.camera = hill_camera
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1000
    scene.render.filepath = str(HILL_PATH)
    bpy.ops.render.render(write_still=True)

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    print(f"Saved Blender source: {BLEND_PATH}")
    print(f"Exported Godot GLB: {GLB_PATH}")
    print(f"Wrote layout manifest: {LAYOUT_PATH}")
    print(f"Rendered overview: {OVERVIEW_PATH}")
    print(f"Rendered hill view: {HILL_PATH}")
    for route_name, route in ROUTES_3D.items():
        route_length = polyline_length(route)
        print(
            f"{route_name}: {route_length:.2f} m, "
            f"{route_length / MOVE_SPEED:.2f} seconds, endpoint={route[-1]}"
        )


if __name__ == "__main__":
    main()
