"""Generate the editable wizard tower source and Godot runtime GLB.

Run from the repository root:
    blender --background --python tools/authoring/generate_wizard_tower.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BLEND_PATH = PROJECT_ROOT / "source_assets/blender/environments/wizard_tower.blend"
GLB_PATH = PROJECT_ROOT / "assets/models/environments/wizard_tower.glb"
EXTERIOR_PREVIEW_PATH = Path("/tmp/wizard_tower_exterior.png")
CUTAWAY_PREVIEW_PATH = Path("/tmp/wizard_tower_cutaway.png")

TAU = math.tau
TOWER_RADIUS = 6.0
STONE_CENTER_RADIUS = 5.69
MORTAR_CENTER_RADIUS = STONE_CENTER_RADIUS
MORTAR_DEPTH = 0.20
WALL_COLLISION_CENTER_RADIUS = STONE_CENTER_RADIUS
WALL_COLLISION_DEPTH = 0.68
FLOOR_SLAB_RADIUS = 5.72
FLOOR_WALL_OVERLAP = FLOOR_SLAB_RADIUS - (MORTAR_CENTER_RADIUS - MORTAR_DEPTH * 0.5)
FLOOR_HEIGHT = 3.8
BASEMENT_FLOOR_Z = -3.6
GROUND_FLOOR_Z = 0.2
FLOOR_Z = [GROUND_FLOOR_Z + FLOOR_HEIGHT * index for index in range(4)]
ROOF_BASE_Z = FLOOR_Z[-1] + 3.65
ROOF_HEIGHT = 15.5
ROOF_EAVE_RADIUS = 6.62
ROOF_TIP_RADIUS = 0.01
ROOF_TIP_Z = ROOF_BASE_Z + ROOF_HEIGHT
ROOF_PITCH_DEGREES = math.degrees(
    math.atan2(ROOF_HEIGHT, ROOF_EAVE_RADIUS - ROOF_TIP_RADIUS)
)
HATCH_CENTER = Vector((3.45, -1.45, GROUND_FLOOR_Z))
HATCH_SIZE = 3.0

RNG = random.Random(1986)
MATERIALS: dict[str, bpy.types.Material] = {}


class MeshBuilder:
    def __init__(self) -> None:
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.material_indices: list[int] = []

    def box(
        self,
        center: Vector,
        dimensions: Vector,
        rotation_z: float = 0.0,
        material_index: int = 0,
        basis: Matrix | None = None,
    ) -> None:
        half = dimensions * 0.5
        local = [
            Vector((-half.x, -half.y, -half.z)),
            Vector((half.x, -half.y, -half.z)),
            Vector((half.x, half.y, -half.z)),
            Vector((-half.x, half.y, -half.z)),
            Vector((-half.x, -half.y, half.z)),
            Vector((half.x, -half.y, half.z)),
            Vector((half.x, half.y, half.z)),
            Vector((-half.x, half.y, half.z)),
        ]
        if basis is None:
            basis = Matrix.Rotation(rotation_z, 4, "Z")
        start = len(self.vertices)
        self.vertices.extend(tuple(basis @ point + center) for point in local)
        self.faces.extend(
            (
                (start + 0, start + 3, start + 2, start + 1),
                (start + 4, start + 5, start + 6, start + 7),
                (start + 0, start + 1, start + 5, start + 4),
                (start + 1, start + 2, start + 6, start + 5),
                (start + 2, start + 3, start + 7, start + 6),
                (start + 3, start + 0, start + 4, start + 7),
            )
        )
        self.material_indices.extend([material_index] * 6)

    def irregular_stone(
        self,
        center: Vector,
        dimensions: Vector,
        rotation_z: float = 0.0,
        material_index: int = 0,
    ) -> None:
        """Add a subtly skewed ashlar block with uneven faces."""
        half = dimensions * 0.5
        bottom_half_width = half.x * RNG.uniform(0.88, 1.08)
        top_half_width = half.x * RNG.uniform(0.84, 1.10)
        bottom_shift = half.x * RNG.uniform(-0.08, 0.08)
        top_shift = half.x * RNG.uniform(-0.10, 0.10)
        inner_depth = -half.y * RNG.uniform(0.90, 1.02)
        outer_bottom_depth = half.y * RNG.uniform(0.92, 1.04)
        outer_top_depth = half.y * RNG.uniform(0.86, 1.08)
        local = [
            Vector((bottom_shift - bottom_half_width, inner_depth, -half.z)),
            Vector((bottom_shift + bottom_half_width, inner_depth, -half.z)),
            Vector((bottom_shift + bottom_half_width, outer_bottom_depth, -half.z)),
            Vector((bottom_shift - bottom_half_width, outer_bottom_depth, -half.z)),
            Vector((top_shift - top_half_width, inner_depth, half.z)),
            Vector((top_shift + top_half_width, inner_depth, half.z)),
            Vector((top_shift + top_half_width, outer_top_depth, half.z)),
            Vector((top_shift - top_half_width, outer_top_depth, half.z)),
        ]
        basis = Matrix.Rotation(rotation_z, 4, "Z")
        start = len(self.vertices)
        self.vertices.extend(tuple(basis @ point + center) for point in local)
        self.faces.extend(
            (
                (start + 0, start + 3, start + 2, start + 1),
                (start + 4, start + 5, start + 6, start + 7),
                (start + 0, start + 1, start + 5, start + 4),
                (start + 1, start + 2, start + 6, start + 5),
                (start + 2, start + 3, start + 7, start + 6),
                (start + 3, start + 0, start + 4, start + 7),
            )
        )
        self.material_indices.extend([material_index] * 6)

    def annular_sector(
        self,
        center_z: float,
        inner_radius: float,
        outer_radius: float,
        start_angle: float,
        end_angle: float,
        thickness: float,
        material_index: int = 0,
        center_xy: Vector | None = None,
    ) -> None:
        if center_xy is None:
            center_xy = Vector((0.0, 0.0))
        bottom = center_z - thickness * 0.5
        top = center_z + thickness * 0.5
        angles = (start_angle, end_angle)
        points: list[Vector] = []
        for z_value in (bottom, top):
            for radius in (inner_radius, outer_radius):
                for angle in angles:
                    points.append(
                        Vector(
                            (
                                center_xy.x + math.cos(angle) * radius,
                                center_xy.y + math.sin(angle) * radius,
                                z_value,
                            )
                        )
                    )
        start = len(self.vertices)
        self.vertices.extend(tuple(point) for point in points)
        self.faces.extend(
            (
                (start + 0, start + 1, start + 3, start + 2),
                (start + 4, start + 6, start + 7, start + 5),
                (start + 0, start + 4, start + 5, start + 1),
                (start + 2, start + 3, start + 7, start + 6),
                (start + 0, start + 2, start + 6, start + 4),
                (start + 1, start + 5, start + 7, start + 3),
            )
        )
        self.material_indices.extend([material_index] * 6)

    def annular_ramp(
        self,
        inner_radius: float,
        outer_radius: float,
        start_angle: float,
        end_angle: float,
        start_z: float,
        end_z: float,
        thickness: float,
        segments: int,
        center_xy: Vector | None = None,
    ) -> None:
        """Add a segmented sloped annulus for ordinary walkable collision."""
        if center_xy is None:
            center_xy = Vector((0.0, 0.0))
        for index in range(segments):
            start_ratio = index / segments
            end_ratio = (index + 1) / segments
            angle_a = start_angle + (end_angle - start_angle) * start_ratio
            angle_b = start_angle + (end_angle - start_angle) * end_ratio
            top_a = start_z + (end_z - start_z) * start_ratio
            top_b = start_z + (end_z - start_z) * end_ratio
            points = []
            for z_a, z_b in ((top_a - thickness, top_b - thickness), (top_a, top_b)):
                for radius in (inner_radius, outer_radius):
                    points.extend(
                        (
                            Vector(
                                (
                                    center_xy.x + math.cos(angle_a) * radius,
                                    center_xy.y + math.sin(angle_a) * radius,
                                    z_a,
                                )
                            ),
                            Vector(
                                (
                                    center_xy.x + math.cos(angle_b) * radius,
                                    center_xy.y + math.sin(angle_b) * radius,
                                    z_b,
                                )
                            ),
                        )
                    )
            start = len(self.vertices)
            self.vertices.extend(tuple(point) for point in points)
            self.faces.extend(
                (
                    (start + 0, start + 1, start + 3, start + 2),
                    (start + 4, start + 6, start + 7, start + 5),
                    (start + 0, start + 4, start + 5, start + 1),
                    (start + 2, start + 3, start + 7, start + 6),
                    (start + 0, start + 2, start + 6, start + 4),
                    (start + 1, start + 5, start + 7, start + 3),
                )
            )
            self.material_indices.extend([0] * 6)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


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
    roughness: float,
    metallic: float = 0.0,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    double_sided: bool = False,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    material.use_backface_culling = not double_sided
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    metallic_input = shader.inputs.get("Metallic IOR Level") or shader.inputs.get("Metallic")
    metallic_input.default_value = metallic
    if emission is not None:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        emission_input.default_value = emission
        shader.inputs["Emission Strength"].default_value = emission_strength
    MATERIALS[name] = material
    return material


def create_materials() -> None:
    create_material("stone_charcoal", (0.105, 0.115, 0.11, 1.0), 0.96)
    create_material("stone_lichen", (0.145, 0.155, 0.125, 1.0), 0.98)
    create_material("stone_ash", (0.17, 0.165, 0.15, 1.0), 0.94)
    create_material("stone_ancient", (0.085, 0.09, 0.085, 1.0), 1.0)
    create_material("mortar_aged", (0.12, 0.105, 0.085, 1.0), 1.0)
    create_material("wood_blackened", (0.115, 0.047, 0.018, 1.0), 0.91)
    create_material("wood_weathered", (0.20, 0.095, 0.032, 1.0), 0.94)
    create_material("iron_old", (0.055, 0.06, 0.06, 1.0), 0.72, 0.72)
    create_material("brass_tarnished", (0.31, 0.19, 0.055, 1.0), 0.58, 0.76)
    create_material("roof_shingle", (0.055, 0.035, 0.05, 1.0), 0.97, double_sided=True)
    create_material(
        "glass_blood",
        (0.23, 0.012, 0.018, 1.0),
        0.5,
        emission=(0.45, 0.012, 0.018, 1.0),
        emission_strength=1.6,
    )
    create_material(
        "glass_amber",
        (0.30, 0.10, 0.012, 1.0),
        0.5,
        emission=(0.55, 0.15, 0.015, 1.0),
        emission_strength=1.7,
    )
    create_material(
        "glass_cobalt",
        (0.02, 0.055, 0.24, 1.0),
        0.46,
        emission=(0.025, 0.08, 0.52, 1.0),
        emission_strength=1.8,
    )
    create_material(
        "glass_sickly",
        (0.08, 0.22, 0.12, 1.0),
        0.54,
        emission=(0.10, 0.48, 0.20, 1.0),
        emission_strength=1.55,
    )
    create_material(
        "crystal_scrying",
        (0.045, 0.09, 0.16, 1.0),
        0.24,
        metallic=0.12,
        emission=(0.08, 0.32, 0.68, 1.0),
        emission_strength=2.8,
    )
    create_material(
        "resurrection_glow",
        (0.12, 0.29, 0.18, 1.0),
        0.66,
        emission=(0.16, 0.72, 0.33, 1.0),
        emission_strength=2.25,
    )


def create_mesh_object(
    name: str,
    builder: MeshBuilder,
    materials: list[bpy.types.Material],
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    bevel: float = 0.0,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update()
    for material in materials:
        mesh.materials.append(material)
    for polygon, material_index in zip(mesh.polygons, builder.material_indices, strict=True):
        polygon.material_index = material_index
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    if bevel > 0.0:
        modifier = obj.modifiers.new("worn_edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    return obj


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: Vector,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    vertices: int = 16,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(material)
    if bevel > 0.0:
        modifier = obj.modifiers.new("worn_edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def add_uv_sphere(
    name: str,
    radius: float,
    location: Vector,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(material)
    return obj


def add_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    location: Vector,
    rotation: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD",
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=24,
        minor_segments=6,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(material)
    return obj


def add_beam_between(
    builder: MeshBuilder,
    start: Vector,
    end: Vector,
    width: float,
    depth: float,
    material_index: int = 0,
) -> None:
    direction = end - start
    length = direction.length
    if length <= 0.0001:
        return
    z_axis = direction.normalized()
    helper = Vector((0.0, 0.0, 1.0))
    if abs(z_axis.dot(helper)) > 0.96:
        helper = Vector((0.0, 1.0, 0.0))
    x_axis = helper.cross(z_axis).normalized()
    y_axis = z_axis.cross(x_axis).normalized()
    basis = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
    builder.box((start + end) * 0.5, Vector((width, depth, length)), material_index=material_index, basis=basis)


def opening_kind(level_index: int, facet: int) -> str | None:
    windows_by_floor = {1: (0, 3, 6, 9), 2: (3, 6, 9), 3: (0, 3, 9)}
    if level_index == 0 and facet == 9:
        return "door"
    if (level_index == 2 and facet == 0) or (level_index == 3 and facet == 6):
        return "stair_access"
    if facet in windows_by_floor.get(level_index, ()):
        return "observatory_window" if level_index == 3 else "window"
    return None


def course_has_opening(level_index: int, facet: int, course: int) -> bool:
    kind = opening_kind(level_index, facet)
    if kind in ("door", "stair_access"):
        return course <= 4
    if kind == "window":
        return course in (2, 3, 4)
    if kind == "observatory_window":
        return course in (2, 3, 4)
    return False


def tile_span(start: float, end: float, minimum_width: float, maximum_width: float) -> list[tuple[float, float]]:
    """Split a wall span into differently sized stone slots."""
    slots: list[tuple[float, float]] = []
    cursor = start
    remaining = end - start
    while remaining > maximum_width:
        largest_safe_width = min(maximum_width, remaining - minimum_width)
        width = RNG.uniform(minimum_width, largest_safe_width)
        slots.append((cursor, cursor + width))
        cursor += width
        remaining = end - cursor
    slots.append((cursor, end))
    return slots


def add_mortar_wall_piece(
    builder: MeshBuilder,
    radial: Vector,
    tangent: Vector,
    angle: float,
    radius: float,
    depth: float,
    base_z: float,
    start: float,
    end: float,
    bottom: float,
    top: float,
) -> None:
    if end - start <= 0.001 or top - bottom <= 0.001:
        return
    center = radial * radius + tangent * ((start + end) * 0.5)
    center.z = base_z + (bottom + top) * 0.5
    builder.box(
        center,
        Vector((end - start, depth, top - bottom)),
        rotation_z=angle - math.pi * 0.5,
    )


def build_mortar_backing(
    level_index: int,
    base_z: float,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> None:
    builder = MeshBuilder()
    collision_builder = MeshBuilder()
    sides = 12
    wall_height = 3.56
    facet_width = 2.0 * TOWER_RADIUS * math.sin(math.pi / sides)
    half_facet = facet_width * 0.5
    opening_half_width = 0.79
    for facet in range(sides):
        angle = TAU * facet / sides
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
        kind = opening_kind(level_index, facet)
        if kind is None:
            add_mortar_wall_piece(
                builder,
                radial,
                tangent,
                angle,
                MORTAR_CENTER_RADIUS,
                MORTAR_DEPTH,
                base_z,
                -half_facet,
                half_facet,
                0.0,
                wall_height,
            )
            add_mortar_wall_piece(
                collision_builder,
                radial,
                tangent,
                angle,
                WALL_COLLISION_CENTER_RADIUS,
                WALL_COLLISION_DEPTH,
                base_z,
                -half_facet,
                half_facet,
                0.0,
                wall_height,
            )
            continue

        if kind in ("door", "stair_access"):
            opening_bottom = 0.0
            opening_top = 2.98
        elif kind == "window":
            opening_bottom = 1.12
            opening_top = 3.00
        else:
            opening_bottom = 1.10
            opening_top = 3.00
        for wall_builder, radius, depth in (
            (builder, MORTAR_CENTER_RADIUS, MORTAR_DEPTH),
            (collision_builder, WALL_COLLISION_CENTER_RADIUS, WALL_COLLISION_DEPTH),
        ):
            add_mortar_wall_piece(
                wall_builder,
                radial,
                tangent,
                angle,
                radius,
                depth,
                base_z,
                -half_facet,
                -opening_half_width,
                0.0,
                wall_height,
            )
            add_mortar_wall_piece(
                wall_builder,
                radial,
                tangent,
                angle,
                radius,
                depth,
                base_z,
                opening_half_width,
                half_facet,
                0.0,
                wall_height,
            )
            add_mortar_wall_piece(
                wall_builder,
                radial,
                tangent,
                angle,
                radius,
                depth,
                base_z,
                -opening_half_width,
                opening_half_width,
                0.0,
                opening_bottom,
            )
            add_mortar_wall_piece(
                wall_builder,
                radial,
                tangent,
                angle,
                radius,
                depth,
                base_z,
                -opening_half_width,
                opening_half_width,
                opening_top,
                wall_height,
            )
    obj = create_mesh_object(
        f"floor_{level_index + 1}_mortar_backing",
        builder,
        [MATERIALS["mortar_aged"]],
        collection,
        parent,
        bevel=0.012,
    )
    obj["mortar_backing"] = True
    obj["radially_centered_in_stones"] = True
    obj["center_radius_m"] = MORTAR_CENTER_RADIUS

    collision = create_mesh_object(
        f"floor_{level_index + 1}_wall_collision-colonly",
        collision_builder,
        [MATERIALS["mortar_aged"]],
        collection,
        parent,
    )
    collision.hide_render = True
    collision.hide_viewport = True
    collision["opening_aware_collision"] = True


def build_masonry_floor(
    level_index: int,
    base_z: float,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> None:
    builder = MeshBuilder()
    materials = [MATERIALS["stone_charcoal"], MATERIALS["stone_lichen"], MATERIALS["stone_ash"]]
    sides = 12
    courses = 6
    facet_width = 2.0 * TOWER_RADIUS * math.sin(math.pi / sides)
    half_facet = facet_width * 0.5
    opening_half_width = 0.82
    for facet in range(sides):
        angle = TAU * facet / sides
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
        for course in range(courses):
            spans = [(-half_facet, half_facet)]
            if course_has_opening(level_index, facet, course):
                active_half_width = opening_half_width
                if opening_kind(level_index, facet) == "observatory_window":
                    active_half_width = 0.78
                spans = [(-half_facet, -active_half_width), (active_half_width, half_facet)]
            for span_start, span_end in spans:
                for slot_start, slot_end in tile_span(span_start, span_end, 0.52, 1.34):
                    width = max(0.38, slot_end - slot_start - RNG.uniform(0.045, 0.075))
                    height = RNG.uniform(0.49, 0.64)
                    depth = RNG.uniform(0.54, 0.69)
                    offset = (slot_start + slot_end) * 0.5 + RNG.uniform(-0.018, 0.018)
                    radius = STONE_CENTER_RADIUS + RNG.uniform(-0.035, 0.035)
                    center = radial * radius + tangent * offset
                    center.z = base_z + 0.29 + course * 0.595 + RNG.uniform(-0.018, 0.018)
                    builder.irregular_stone(
                        center,
                        Vector((width, depth, height)),
                        rotation_z=angle - math.pi * 0.5 + RNG.uniform(-0.012, 0.012),
                        material_index=RNG.randrange(len(materials)),
                    )
    obj = create_mesh_object(
        f"floor_{level_index + 1}_masonry",
        builder,
        materials,
        collection,
        parent,
        bevel=0.035,
    )
    obj["floor_index"] = level_index + 1
    obj["exterior_radius_m"] = TOWER_RADIUS
    obj["mortar_backed"] = True
    obj["stone_width_min_m"] = 0.38
    obj["stone_width_max_m"] = 1.30
    obj["stone_shape"] = "irregular_trapezoid"


def build_basement_masonry(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    materials = [MATERIALS["stone_ancient"], MATERIALS["stone_charcoal"]]
    sides = 12
    courses = 5
    facet_width = 2.0 * TOWER_RADIUS * math.sin(math.pi / sides)
    half_facet = facet_width * 0.5
    for facet in range(sides):
        angle = TAU * facet / sides
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
        for course in range(courses):
            for slot_start, slot_end in tile_span(-half_facet, half_facet, 0.55, 1.38):
                width = max(0.42, slot_end - slot_start - RNG.uniform(0.05, 0.08))
                center = radial * (STONE_CENTER_RADIUS - 0.01 + RNG.uniform(-0.035, 0.035))
                center += tangent * ((slot_start + slot_end) * 0.5 + RNG.uniform(-0.018, 0.018))
                center.z = BASEMENT_FLOOR_Z + 0.35 + course * 0.72 + RNG.uniform(-0.018, 0.018)
                builder.irregular_stone(
                    center,
                    Vector((width, RNG.uniform(0.57, 0.71), RNG.uniform(0.61, 0.72))),
                    rotation_z=angle - math.pi * 0.5 + RNG.uniform(-0.012, 0.012),
                    material_index=(facet + course) % 2,
                )
    obj = create_mesh_object("basement_masonry", builder, materials, collection, parent, bevel=0.045)
    obj["secret_until_first_death"] = True
    obj["mortar_backed"] = True
    obj["stone_shape"] = "irregular_trapezoid"

    mortar_builder = MeshBuilder()
    collision_builder = MeshBuilder()
    for facet in range(sides):
        angle = TAU * facet / sides
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
        add_mortar_wall_piece(
            mortar_builder,
            radial,
            tangent,
            angle,
            MORTAR_CENTER_RADIUS,
            MORTAR_DEPTH,
            BASEMENT_FLOOR_Z,
            -half_facet,
            half_facet,
            0.0,
            3.56,
        )
        add_mortar_wall_piece(
            collision_builder,
            radial,
            tangent,
            angle,
            WALL_COLLISION_CENTER_RADIUS,
            WALL_COLLISION_DEPTH,
            BASEMENT_FLOOR_Z,
            -half_facet,
            half_facet,
            0.0,
            3.56,
        )
    mortar = create_mesh_object(
        "basement_mortar_backing",
        mortar_builder,
        [MATERIALS["mortar_aged"]],
        collection,
        parent,
        bevel=0.012,
    )
    mortar["mortar_backing"] = True
    mortar["radially_centered_in_stones"] = True
    mortar["center_radius_m"] = MORTAR_CENTER_RADIUS

    collision = create_mesh_object(
        "basement_wall_collision-colonly",
        collision_builder,
        [MATERIALS["mortar_aged"]],
        collection,
        parent,
    )
    collision.hide_render = True
    collision.hide_viewport = True
    collision["opening_aware_collision"] = True


def build_floor_discs(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    basement = add_cylinder(
        "basement_floor-col",
        FLOOR_SLAB_RADIUS,
        0.22,
        Vector((0.0, 0.0, BASEMENT_FLOOR_Z - 0.11)),
        MATERIALS["stone_ancient"],
        collection,
        parent,
        vertices=48,
        bevel=0.025,
    )
    basement["walking_height_m"] = BASEMENT_FLOOR_Z
    basement["wall_overlap_m"] = FLOOR_WALL_OVERLAP

    ground = add_cylinder(
        "ground_floor-col",
        FLOOR_SLAB_RADIUS,
        0.22,
        Vector((0.0, 0.0, GROUND_FLOOR_Z - 0.11)),
        MATERIALS["stone_charcoal"],
        collection,
        parent,
        vertices=48,
        bevel=0.02,
    )
    ground["wall_overlap_m"] = FLOOR_WALL_OVERLAP
    bpy.ops.mesh.primitive_cube_add(
        location=(HATCH_CENTER.x, HATCH_CENTER.y, GROUND_FLOOR_Z - 0.1),
        scale=(HATCH_SIZE * 0.5 + 0.02, HATCH_SIZE * 0.5 + 0.02, 0.3),
    )
    cutter = bpy.context.object
    cutter.name = "REFERENCE_hatch_cutter"
    boolean = ground.modifiers.new("hidden_stair_opening", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter
    bpy.context.view_layer.objects.active = ground
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

    stone_materials = [MATERIALS["stone_charcoal"], MATERIALS["stone_ash"]]
    for index, elevation in enumerate(FLOOR_Z[1:3], start=2):
        builder = MeshBuilder()
        segments = 48
        for segment in range(segments):
            angle_a = TAU * segment / segments
            angle_b = TAU * (segment + 1) / segments
            builder.annular_sector(
                elevation - 0.11,
                2.12,
                FLOOR_SLAB_RADIUS,
                angle_a,
                angle_b,
                0.22,
                material_index=segment % 2,
            )
        floor = create_mesh_object(
            f"floor_{index}_slab-col", builder, stone_materials, collection, parent, bevel=0.015
        )
        floor["central_stair_opening_radius_m"] = 2.12
        floor["wall_overlap_m"] = FLOOR_WALL_OVERLAP

    observatory = add_cylinder(
        "observatory_floor-col",
        FLOOR_SLAB_RADIUS,
        0.22,
        Vector((0.0, 0.0, FLOOR_Z[3] - 0.11)),
        MATERIALS["stone_ash"],
        collection,
        parent,
        vertices=48,
        bevel=0.025,
    )
    observatory["outside_access_only"] = True
    observatory["wall_overlap_m"] = FLOOR_WALL_OVERLAP

    cornice_builder = MeshBuilder()
    for elevation in FLOOR_Z[1:] + [ROOF_BASE_Z]:
        for segment in range(24):
            start = TAU * segment / 24
            end = TAU * (segment + 1) / 24
            cornice_builder.annular_sector(elevation - 0.02, 5.54, 6.12, start, end, 0.22)
    create_mesh_object(
        "masonry_cornices", cornice_builder, [MATERIALS["stone_ash"]], collection, parent, bevel=0.025
    )


def build_central_stairs(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    stair_builder = MeshBuilder()
    collision_builder = MeshBuilder()
    steps_per_floor = 22
    tread_angle = TAU / steps_per_floor * 1.12
    for ascent_index, base_z in enumerate(FLOOR_Z[:2]):
        phase = ascent_index * 0.42
        for step_index in range(steps_per_floor):
            progress = step_index / (steps_per_floor - 1)
            angle = phase + progress * TAU
            z_value = base_z + 0.06 + progress * FLOOR_HEIGHT
            stair_builder.annular_sector(
                z_value,
                0.46,
                2.02,
                angle - tread_angle * 0.5,
                angle + tread_angle * 0.5,
                0.16,
                material_index=(step_index + ascent_index) % 2,
            )
        collision_builder.annular_ramp(
            0.46,
            2.02,
            phase - tread_angle * 0.5,
            phase + TAU + tread_angle * 0.5,
            base_z,
            base_z + FLOOR_HEIGHT,
            0.12,
            steps_per_floor * 2,
        )
    create_mesh_object(
        "central_spiral_stair",
        stair_builder,
        [MATERIALS["stone_ash"], MATERIALS["stone_charcoal"]],
        collection,
        parent,
        bevel=0.022,
    )
    collision = create_mesh_object(
        "central_spiral_stair_ramp-colonly",
        collision_builder,
        [MATERIALS["stone_ash"]],
        collection,
        parent,
    )
    collision.hide_render = True
    collision.hide_viewport = True
    add_cylinder(
        "central_stair_newel-col",
        0.39,
        FLOOR_HEIGHT * 2 + 0.2,
        Vector((0.0, 0.0, GROUND_FLOOR_Z + FLOOR_HEIGHT)),
        MATERIALS["stone_ancient"],
        collection,
        parent,
        vertices=12,
        bevel=0.035,
    )

    rail_builder = MeshBuilder()
    for ascent_index, base_z in enumerate(FLOOR_Z[:2]):
        phase = ascent_index * 0.42
        last_top: Vector | None = None
        for post_index in range(12):
            progress = post_index / 11.0
            angle = phase + progress * TAU
            foot = Vector((math.cos(angle) * 1.98, math.sin(angle) * 1.98, base_z + progress * FLOOR_HEIGHT + 0.1))
            top = foot + Vector((0.0, 0.0, 0.92))
            add_beam_between(rail_builder, foot, top, 0.055, 0.055)
            if last_top is not None:
                add_beam_between(rail_builder, last_top, top, 0.065, 0.065)
            last_top = top
    create_mesh_object(
        "central_stair_ironwork", rail_builder, [MATERIALS["iron_old"]], collection, parent, bevel=0.008
    )


def build_hidden_stairs(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    collision_builder = MeshBuilder()
    step_count = 30
    turn_count = 1.25
    tread_angle = TAU * turn_count / step_count * 1.16
    for index in range(step_count):
        progress = index / (step_count - 1)
        angle = progress * TAU * turn_count
        z_value = BASEMENT_FLOOR_Z + 0.08 + (GROUND_FLOOR_Z - BASEMENT_FLOOR_Z) * progress
        builder.annular_sector(
            z_value,
            0.24,
            1.04,
            angle - tread_angle * 0.5,
            angle + tread_angle * 0.5,
            0.15,
            material_index=index % 2,
            center_xy=Vector((HATCH_CENTER.x, HATCH_CENTER.y)),
        )
    collision_builder.annular_ramp(
        0.24,
        1.04,
        -tread_angle * 0.5,
        TAU * turn_count + tread_angle * 0.5,
        BASEMENT_FLOOR_Z,
        GROUND_FLOOR_Z,
        0.12,
        step_count * 2,
        center_xy=Vector((HATCH_CENTER.x, HATCH_CENTER.y)),
    )
    create_mesh_object(
        "hidden_basement_stair",
        builder,
        [MATERIALS["stone_ancient"], MATERIALS["stone_charcoal"]],
        collection,
        parent,
        bevel=0.025,
    )
    collision = create_mesh_object(
        "hidden_basement_stair_ramp-colonly",
        collision_builder,
        [MATERIALS["stone_ancient"]],
        collection,
        parent,
    )
    collision.hide_render = True
    collision.hide_viewport = True
    add_cylinder(
        "hidden_stair_newel-col",
        0.20,
        GROUND_FLOOR_Z - BASEMENT_FLOOR_Z + 0.2,
        Vector((HATCH_CENTER.x, HATCH_CENTER.y, (GROUND_FLOOR_Z + BASEMENT_FLOOR_Z) * 0.5)),
        MATERIALS["iron_old"],
        collection,
        parent,
        vertices=10,
        bevel=0.018,
    )

    closed_builder = MeshBuilder()
    closed_builder.box(
        HATCH_CENTER + Vector((0.0, 0.0, -0.01)),
        Vector((HATCH_SIZE, HATCH_SIZE, 0.19)),
        material_index=0,
    )
    closed = create_mesh_object(
        "secret_hatch_closed", closed_builder, [MATERIALS["stone_ash"]], collection, parent, bevel=0.035
    )
    closed["visible_before_first_death"] = True

    open_builder = MeshBuilder()
    open_center = HATCH_CENTER + Vector((HATCH_SIZE * 0.5 + 0.06, 0.0, HATCH_SIZE * 0.5 + 0.03))
    open_builder.box(open_center, Vector((0.18, HATCH_SIZE, HATCH_SIZE)), material_index=0)
    open_hatch = create_mesh_object(
        "secret_hatch_open", open_builder, [MATERIALS["stone_ash"]], collection, parent, bevel=0.035
    )
    open_hatch.hide_viewport = True
    open_hatch.hide_render = True
    open_hatch["visible_after_first_death"] = True



def build_windows(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    glass_materials = [
        MATERIALS["glass_blood"],
        MATERIALS["glass_amber"],
        MATERIALS["glass_cobalt"],
        MATERIALS["glass_sickly"],
        MATERIALS["iron_old"],
    ]
    windows_by_floor = {
        1: (0, 3, 6, 9),
        2: (3, 6, 9),
        3: (0, 3, 9),
    }
    for level_index, facets in windows_by_floor.items():
        builder = MeshBuilder()
        for facet in facets:
            angle = TAU * facet / 12
            radial = Vector((math.cos(angle), math.sin(angle), 0.0))
            tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
            center = radial * 5.70
            center.z = FLOOR_Z[level_index] + 2.02
            for strip in range(4):
                offset = (strip - 1.5) * 0.34
                pane_center = center + tangent * offset
                builder.box(
                    pane_center,
                    Vector((0.30, 0.08, 1.62)),
                    rotation_z=angle - math.pi * 0.5,
                    material_index=(strip + facet + level_index) % 4,
                )
            for offset in (-0.70, -0.34, 0.0, 0.34, 0.70):
                builder.box(
                    center + tangent * offset,
                    Vector((0.045, 0.13, 1.82)),
                    rotation_z=angle - math.pi * 0.5,
                    material_index=4,
                )
            for height in (-0.88, 0.0, 0.88):
                frame_center = center + Vector((0.0, 0.0, height))
                builder.box(
                    frame_center,
                    Vector((1.52, 0.13, 0.055)),
                    rotation_z=angle - math.pi * 0.5,
                    material_index=4,
                )
        create_mesh_object(
            f"floor_{level_index + 1}_stained_glass-col",
            builder,
            glass_materials,
            collection,
            parent,
            bevel=0.012,
        )


def build_doorways(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    doorway_builder = MeshBuilder()
    entry_angle = TAU * 9 / 12
    entry_radial = Vector((math.cos(entry_angle), math.sin(entry_angle), 0.0))
    entry_tangent = Vector((-math.sin(entry_angle), math.cos(entry_angle), 0.0))
    entry_frame_center = entry_radial * 5.72
    for side in (-1.0, 1.0):
        doorway_builder.box(
            entry_frame_center + entry_tangent * side * 0.87 + Vector((0.0, 0.0, 1.38)),
            Vector((0.27, 0.76, 2.76)),
            rotation_z=entry_angle - math.pi * 0.5,
            material_index=0,
        )
    doorway_builder.box(
        entry_frame_center + Vector((0.0, 0.0, 2.78)),
        Vector((1.95, 0.76, 0.3)),
        rotation_z=entry_angle - math.pi * 0.5,
        material_index=0,
    )
    entry_frame = create_mesh_object(
        "stone_entry_frame-col",
        doorway_builder,
        [MATERIALS["stone_ash"]],
        collection,
        parent,
        bevel=0.055,
    )
    entry_frame["doorway_role"] = "sole_tower_entrance"

    door_builder = MeshBuilder()
    door_width = 1.46
    hinge_point = entry_radial * 6.03 + entry_tangent * 0.73 + Vector((0.0, 0.0, 1.38))
    hinge = bpy.data.objects.new("warded_entry_door_hinge", None)
    collection.objects.link(hinge)
    hinge.parent = parent
    hinge.location = hinge_point
    hinge.rotation_euler.z = entry_angle - math.pi * 0.5
    hinge.empty_display_type = "PLAIN_AXES"
    hinge.empty_display_size = 0.32
    hinge["doorway_role"] = "animated_tower_entrance"
    hinge["hinge_aligned"] = True
    hinge["open_angle_degrees"] = 105.0

    entry_center = Vector((door_width * 0.5, 0.0, 0.0))
    door_builder.box(
        entry_center,
        Vector((door_width, 0.16, 2.58)),
        material_index=0,
    )
    for plank in range(5):
        center = entry_center + Vector((0.0, 0.0, (plank - 2) * 0.48))
        door_builder.box(
            center,
            Vector((door_width + 0.07, 0.20, 0.06)),
            material_index=1,
        )
    door = create_mesh_object(
        "warded_entry_door",
        door_builder,
        [MATERIALS["wood_blackened"], MATERIALS["iron_old"]],
        collection,
        hinge,
        bevel=0.025,
    )
    door["hinge_aligned"] = True
    door["open_angle_degrees"] = 105.0


def build_exterior_stair(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    stair_builder = MeshBuilder()
    collision_builder = MeshBuilder()
    support_builder = MeshBuilder()
    steps = 28
    start_angle = 0.0
    end_angle = math.pi
    start_z = FLOOR_Z[2] + 0.08
    end_z = FLOOR_Z[3] + 0.08
    for index in range(steps):
        progress = index / (steps - 1)
        angle = start_angle + (end_angle - start_angle) * progress
        center = Vector((math.cos(angle) * 6.48, math.sin(angle) * 6.48, start_z + FLOOR_HEIGHT * progress))
        stair_builder.box(
            center,
            Vector((0.52, 1.36, 0.16)),
            rotation_z=angle,
            material_index=index % 2,
        )
        if index % 4 == 0:
            inner_foot = Vector((math.cos(angle) * 5.98, math.sin(angle) * 5.98, center.z - 0.04))
            outer_foot = Vector((math.cos(angle) * 7.02, math.sin(angle) * 7.02, center.z - 0.04))
            outer_top = outer_foot + Vector((0.0, 0.0, 1.02))
            add_beam_between(support_builder, outer_foot, outer_top, 0.075, 0.075, 1)
            add_beam_between(support_builder, outer_foot, inner_foot - Vector((0.0, 0.0, 1.1)), 0.13, 0.13, 0)
            if index + 4 < steps:
                next_progress = (index + 4) / (steps - 1)
                next_angle = start_angle + (end_angle - start_angle) * next_progress
                next_outer_top = Vector(
                    (
                        math.cos(next_angle) * 7.02,
                        math.sin(next_angle) * 7.02,
                        start_z + FLOOR_HEIGHT * next_progress + 0.98,
                    )
                )
                add_beam_between(support_builder, outer_top, next_outer_top, 0.085, 0.085, 1)
    for angle, z_value in ((start_angle, start_z), (end_angle, end_z)):
        landing_center = Vector((math.cos(angle) * 6.35, math.sin(angle) * 6.35, z_value))
        stair_builder.box(landing_center, Vector((1.65, 1.75, 0.18)), rotation_z=angle, material_index=0)
    collision_builder.annular_ramp(
        5.80,
        7.16,
        start_angle,
        end_angle,
        FLOOR_Z[2],
        FLOOR_Z[3],
        0.12,
        steps * 2,
    )
    create_mesh_object(
        "exterior_wooden_stair",
        stair_builder,
        [MATERIALS["wood_weathered"], MATERIALS["wood_blackened"]],
        collection,
        parent,
        bevel=0.024,
    )
    collision = create_mesh_object(
        "exterior_wooden_stair_ramp-colonly",
        collision_builder,
        [MATERIALS["wood_weathered"]],
        collection,
        parent,
    )
    collision.hide_render = True
    collision.hide_viewport = True
    create_mesh_object(
        "exterior_stair_braces",
        support_builder,
        [MATERIALS["wood_blackened"], MATERIALS["iron_old"]],
        collection,
        parent,
        bevel=0.012,
    )


def build_roof(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    bpy.ops.mesh.primitive_cone_add(
        vertices=12,
        radius1=ROOF_EAVE_RADIUS,
        radius2=ROOF_TIP_RADIUS,
        depth=ROOF_TIP_Z - ROOF_BASE_Z,
        location=(0.0, 0.0, (ROOF_BASE_Z + ROOF_TIP_Z) * 0.5),
        rotation=(0.0, 0.0, math.radians(2.2)),
    )
    roof = bpy.context.object
    roof.name = "crooked_pointed_roof"
    for owner in list(roof.users_collection):
        owner.objects.unlink(roof)
    collection.objects.link(roof)
    roof.parent = parent
    roof.data.materials.append(MATERIALS["roof_shingle"])
    roof["pointed_roof"] = True
    roof["height_m"] = ROOF_HEIGHT
    roof["pitch_degrees"] = ROOF_PITCH_DEGREES

    rib_builder = MeshBuilder()
    tip = Vector((0.0, 0.0, ROOF_TIP_Z - 0.1))
    for index in range(12):
        angle = TAU * index / 12 + math.radians(2.2)
        eave = Vector((math.cos(angle) * 6.64, math.sin(angle) * 6.64, ROOF_BASE_Z + 0.05))
        add_beam_between(rib_builder, eave, tip, 0.10, 0.10)
    create_mesh_object("roof_iron_ribs", rib_builder, [MATERIALS["iron_old"]], collection, parent)

    finial_builder = MeshBuilder()
    add_beam_between(
        finial_builder,
        Vector((0.0, 0.0, ROOF_TIP_Z - 0.2)),
        Vector((0.18, -0.08, ROOF_TIP_Z + 1.35)),
        0.085,
        0.085,
    )
    create_mesh_object("crooked_lightning_rod", finial_builder, [MATERIALS["iron_old"]], collection, parent)


def build_observatory(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    center = Vector((0.0, 0.0, FLOOR_Z[3] + 1.42))
    add_cylinder(
        "scrying_pedestal-col",
        0.72,
        1.0,
        Vector((0.0, 0.0, FLOOR_Z[3] + 0.50)),
        MATERIALS["stone_ancient"],
        collection,
        parent,
        vertices=12,
        bevel=0.04,
    )
    add_uv_sphere(
        "scrying_crystal",
        0.68,
        center,
        MATERIALS["crystal_scrying"],
        collection,
        parent,
    )
    add_torus("scrying_gimbal_yaw", 0.94, 0.055, center, (0.0, 0.0, 0.0), MATERIALS["brass_tarnished"], collection, parent)
    add_torus("scrying_gimbal_pitch", 1.03, 0.045, center, (math.pi * 0.5, 0.0, 0.0), MATERIALS["brass_tarnished"], collection, parent)
    add_torus("scrying_gimbal_roll", 1.10, 0.04, center, (0.0, math.pi * 0.5, math.radians(18.0)), MATERIALS["iron_old"], collection, parent)

    machine_builder = MeshBuilder()
    for index in range(8):
        angle = TAU * index / 8 + math.radians(22.5)
        base = Vector((math.cos(angle) * 2.0, math.sin(angle) * 2.0, FLOOR_Z[3] + 0.42))
        machine_builder.box(base, Vector((0.55, 0.72, 0.78)), rotation_z=angle, material_index=index % 2)
        arm_top = center + Vector((math.cos(angle) * 0.88, math.sin(angle) * 0.88, -0.12))
        add_beam_between(machine_builder, base + Vector((0.0, 0.0, 0.35)), arm_top, 0.10, 0.10, 1)
    create_mesh_object(
        "scrying_machinery-col",
        machine_builder,
        [MATERIALS["iron_old"], MATERIALS["brass_tarnished"]],
        collection,
        parent,
        bevel=0.025,
    )

    star_builder = MeshBuilder()
    for ray in range(12):
        angle = TAU * ray / 12
        start = Vector((math.cos(angle) * 0.95, math.sin(angle) * 0.95, FLOOR_Z[3] + 0.018))
        end = Vector((math.cos(angle) * 3.45, math.sin(angle) * 3.45, FLOOR_Z[3] + 0.018))
        add_beam_between(star_builder, start, end, 0.035, 0.02)
    create_mesh_object("observatory_star_map", star_builder, [MATERIALS["brass_tarnished"]], collection, parent)


def build_basement_details(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    basin_center = Vector((-1.65, 0.1, BASEMENT_FLOOR_Z + 0.22))
    add_torus(
        "second_vessel_basin-col",
        1.08,
        0.18,
        basin_center,
        (0.0, 0.0, 0.0),
        MATERIALS["stone_ancient"],
        collection,
        parent,
    )
    add_cylinder(
        "second_vessel_glow",
        0.88,
        0.035,
        basin_center + Vector((0.0, 0.0, -0.02)),
        MATERIALS["resurrection_glow"],
        collection,
        parent,
        vertices=24,
    )
    rune_builder = MeshBuilder()
    for index in range(8):
        angle = TAU * index / 8
        outer = basin_center + Vector((math.cos(angle) * 1.72, math.sin(angle) * 1.72, -0.17))
        inner = basin_center + Vector((math.cos(angle + 0.42) * 1.22, math.sin(angle + 0.42) * 1.22, -0.17))
        add_beam_between(rune_builder, inner, outer, 0.055, 0.025)
    create_mesh_object("second_vessel_runes", rune_builder, [MATERIALS["resurrection_glow"]], collection, parent)

    alcove_builder = MeshBuilder()
    for index in range(4):
        angle = TAU * index / 4 + math.radians(45.0)
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
        center = radial * 5.16 + Vector((0.0, 0.0, BASEMENT_FLOOR_Z + 1.48))
        for side in (-1.0, 1.0):
            alcove_builder.box(center + tangent * side * 0.62, Vector((0.22, 0.42, 2.2)), rotation_z=angle - math.pi * 0.5)
        alcove_builder.box(center + Vector((0.0, 0.0, 1.1)), Vector((1.48, 0.42, 0.24)), rotation_z=angle - math.pi * 0.5)
    create_mesh_object("dormant_fount_alcoves", alcove_builder, [MATERIALS["stone_ash"]], collection, parent, bevel=0.045)


def build_gargoyles(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    for facet in (1, 5, 7, 11):
        angle = TAU * facet / 12
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        center = radial * 6.35 + Vector((0.0, 0.0, ROOF_BASE_Z - 0.3))
        builder.box(center, Vector((0.48, 1.0, 0.45)), rotation_z=angle - math.pi * 0.5)
        snout = radial * 0.7 + center - Vector((0.0, 0.0, 0.08))
        builder.box(snout, Vector((0.35, 0.72, 0.28)), rotation_z=angle - math.pi * 0.5)
    create_mesh_object("gargoyle_spouts", builder, [MATERIALS["stone_ancient"]], collection, parent, bevel=0.06)


def configure_world() -> None:
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.008, 0.01, 0.015)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_previews() -> None:
    scene = bpy.context.scene
    camera_data = bpy.data.cameras.new("preview_camera")
    camera = bpy.data.objects.new("preview_camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 26.0

    key_data = bpy.data.lights.new("preview_moon", "AREA")
    key_data.energy = 1450.0
    key_data.color = (0.26, 0.34, 0.56)
    key_data.shape = "DISK"
    key_data.size = 18.0
    key = bpy.data.objects.new("preview_moon", key_data)
    scene.collection.objects.link(key)
    key.location = (10.0, -14.0, 24.0)
    look_at(key, Vector((0.0, 0.0, 9.0)))

    warm_data = bpy.data.lights.new("preview_window_glow", "AREA")
    warm_data.energy = 900.0
    warm_data.color = (0.58, 0.12, 0.035)
    warm_data.size = 7.0
    warm = bpy.data.objects.new("preview_window_glow", warm_data)
    scene.collection.objects.link(warm)
    warm.location = (-8.0, -7.0, 10.0)
    look_at(warm, Vector((0.0, 0.0, 8.0)))

    camera.location = (24.0, -30.0, 18.0)
    look_at(camera, Vector((0.0, 0.0, 14.5)))
    scene.render.filepath = str(EXTERIOR_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    camera.location = (4.0, -4.0, 13.7)
    camera.data.lens = 34.0
    look_at(camera, Vector((0.0, 0.0, 12.7)))
    scene.render.filepath = str(CUTAWAY_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)
    bpy.data.objects.remove(warm, do_unlink=True)


def main() -> None:
    reset_scene()
    configure_world()
    create_materials()

    architecture_collection = create_collection("TowerArchitecture")
    basement_collection = create_collection("Basement", architecture_collection)
    floor_collections = [create_collection(f"Floor{index + 1}", architecture_collection) for index in range(4)]
    stairs_collection = create_collection("Stairs", architecture_collection)
    roof_collection = create_collection("Roof", architecture_collection)
    observatory_collection = create_collection("Observatory", architecture_collection)
    details_collection = create_collection("Details", architecture_collection)

    root = bpy.data.objects.new("WizardTowerArchitecture", None)
    architecture_collection.objects.link(root)
    root["exterior_radius_m"] = TOWER_RADIUS
    root["above_ground_floor_count"] = 4
    root["has_secret_basement"] = True
    root["observatory_access"] = "exterior_wooden_stair"
    root["masonry_style"] = "irregular_stone_with_aged_mortar"
    root["mortar_center_radius_m"] = MORTAR_CENTER_RADIUS
    root["door_count"] = 1
    root["floor_slab_radius_m"] = FLOOR_SLAB_RADIUS
    root["floor_wall_overlap_m"] = FLOOR_WALL_OVERLAP
    root["wall_collision_inner_radius_m"] = (
        WALL_COLLISION_CENTER_RADIUS - WALL_COLLISION_DEPTH * 0.5
    )
    root["wall_collision_outer_radius_m"] = (
        WALL_COLLISION_CENTER_RADIUS + WALL_COLLISION_DEPTH * 0.5
    )
    root["observatory_windows_fitted"] = True
    root["roof_height_m"] = ROOF_HEIGHT
    root["roof_pitch_degrees"] = ROOF_PITCH_DEGREES
    root["roof_tip_radius_m"] = ROOF_TIP_RADIUS

    build_basement_masonry(basement_collection, root)
    build_floor_discs(details_collection, root)
    for level_index, base_z in enumerate(FLOOR_Z):
        build_mortar_backing(level_index, base_z, floor_collections[level_index], root)
        build_masonry_floor(level_index, base_z, floor_collections[level_index], root)
    build_central_stairs(stairs_collection, root)
    build_hidden_stairs(stairs_collection, root)
    build_windows(details_collection, root)
    build_doorways(details_collection, root)
    build_exterior_stair(stairs_collection, root)
    build_roof(roof_collection, root)
    build_observatory(observatory_collection, root)
    build_basement_details(basement_collection, root)
    build_gargoyles(details_collection, root)

    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        export_apply=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )
    render_previews()
    print(f"Saved editable tower: {BLEND_PATH}")
    print(f"Exported runtime tower: {GLB_PATH}")
    print(f"Rendered exterior preview: {EXTERIOR_PREVIEW_PATH}")
    print(f"Rendered observatory preview: {CUTAWAY_PREVIEW_PATH}")


if __name__ == "__main__":
    main()
