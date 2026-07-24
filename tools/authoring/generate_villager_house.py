"""Generate the editable villager house source and Godot runtime GLB.

A small stone cottage that carries the same warded door as the wizard tower
(same geometry, materials, and hinge rig) so door-to-door link spells can be
tested between two real doors.

Run from the repository root:
    blender --background --python tools/authoring/generate_villager_house.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BLEND_PATH = PROJECT_ROOT / "source_assets/blender/environments/villager_house.blend"
GLB_PATH = PROJECT_ROOT / "assets/models/environments/villager_house.glb"
EXTERIOR_PREVIEW_PATH = Path("/tmp/villager_house_exterior.png")
DOOR_PREVIEW_PATH = Path("/tmp/villager_house_door.png")

TAU = math.tau
HALF_WIDTH = 2.9  # along the ridge (x)
HALF_DEPTH = 2.35  # front wall sits at y = -HALF_DEPTH
WALL_TOP = 3.1
STONE_COURSES = 5
COURSE_STEP = 0.585
MORTAR_DEPTH = 0.20
WALL_COLLISION_DEPTH = 0.60
GABLE_RISE = 1.6
ROOF_OVERHANG = 0.45
ROOF_PITCH = math.atan2(GABLE_RISE, HALF_DEPTH + ROOF_OVERHANG)

# The warded door, copied from the tower so both doors are the same asset.
DOOR_WIDTH = 1.46
DOOR_MORTAR_HALF_WIDTH = 0.79
DOOR_STONE_HALF_WIDTH = 0.82
DOOR_OPENING_TOP = 2.98

WINDOW_MORTAR_HALF_WIDTH = 0.45
WINDOW_STONE_HALF_WIDTH = 0.48
WINDOW_BOTTOM = 1.12
WINDOW_TOP = 2.30

RNG = random.Random(3571)
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
                (start + 0, start + 1, start + 3, start + 2),
                (start + 4, start + 6, start + 7, start + 5),
                (start + 0, start + 4, start + 5, start + 1),
                (start + 2, start + 3, start + 7, start + 6),
                (start + 0, start + 2, start + 6, start + 4),
                (start + 1, start + 5, start + 7, start + 3),
            )
        )
        self.material_indices.extend([material_index] * 6)


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
    # Values match generate_wizard_tower.py so the cottage sits in the same palette.
    create_material("stone_charcoal", (0.105, 0.115, 0.11, 1.0), 0.96)
    create_material("stone_lichen", (0.145, 0.155, 0.125, 1.0), 0.98)
    create_material("stone_ash", (0.17, 0.165, 0.15, 1.0), 0.94)
    create_material("mortar_aged", (0.12, 0.105, 0.085, 1.0), 1.0)
    create_material("wood_blackened", (0.115, 0.047, 0.018, 1.0), 0.91)
    create_material("wood_weathered", (0.20, 0.095, 0.032, 1.0), 0.94)
    create_material("iron_old", (0.055, 0.06, 0.06, 1.0), 0.72, 0.72)
    create_material("roof_shingle", (0.055, 0.035, 0.05, 1.0), 0.97, double_sided=True)
    create_material(
        "glass_amber",
        (0.30, 0.10, 0.012, 1.0),
        0.5,
        emission=(0.55, 0.15, 0.015, 1.0),
        emission_strength=1.7,
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


class WallOpening:
    def __init__(self, center_t: float, mortar_half_width: float, stone_half_width: float, bottom: float, top: float) -> None:
        self.center_t = center_t
        self.mortar_half_width = mortar_half_width
        self.stone_half_width = stone_half_width
        self.bottom = bottom
        self.top = top


class Wall:
    """A straight wall run described by its outward normal and tangent extent."""

    def __init__(self, origin: Vector, angle: float, half_length: float, openings: list[WallOpening]) -> None:
        self.origin = origin  # centre of the wall line at z = 0
        self.angle = angle  # angle of the outward normal
        self.half_length = half_length
        self.openings = openings

    @property
    def normal(self) -> Vector:
        return Vector((math.cos(self.angle), math.sin(self.angle), 0.0))

    @property
    def tangent(self) -> Vector:
        return Vector((-math.sin(self.angle), math.cos(self.angle), 0.0))


def make_walls() -> list[Wall]:
    door = WallOpening(0.0, DOOR_MORTAR_HALF_WIDTH, DOOR_STONE_HALF_WIDTH, 0.0, DOOR_OPENING_TOP)
    back_window = WallOpening(0.0, WINDOW_MORTAR_HALF_WIDTH, WINDOW_STONE_HALF_WIDTH, WINDOW_BOTTOM, WINDOW_TOP)
    side_window = WallOpening(0.55, WINDOW_MORTAR_HALF_WIDTH, WINDOW_STONE_HALF_WIDTH, WINDOW_BOTTOM, WINDOW_TOP)
    return [
        Wall(Vector((0.0, -HALF_DEPTH, 0.0)), -math.pi * 0.5, HALF_WIDTH, [door]),
        Wall(Vector((0.0, HALF_DEPTH, 0.0)), math.pi * 0.5, HALF_WIDTH, [back_window]),
        Wall(Vector((HALF_WIDTH, 0.0, 0.0)), 0.0, HALF_DEPTH, [side_window]),
        Wall(Vector((-HALF_WIDTH, 0.0, 0.0)), math.pi, HALF_DEPTH, []),
    ]


def spans_minus_openings(
    start: float, end: float, openings: list[tuple[float, float]]
) -> list[tuple[float, float]]:
    spans = [(start, end)]
    for open_start, open_end in openings:
        next_spans: list[tuple[float, float]] = []
        for span_start, span_end in spans:
            if open_end <= span_start or open_start >= span_end:
                next_spans.append((span_start, span_end))
                continue
            if open_start - span_start > 0.05:
                next_spans.append((span_start, open_start))
            if span_end - open_end > 0.05:
                next_spans.append((open_end, span_end))
        spans = next_spans
    return spans


def add_wall_piece(
    builder: MeshBuilder,
    wall: Wall,
    depth: float,
    start: float,
    end: float,
    bottom: float,
    top: float,
) -> None:
    if end - start <= 0.001 or top - bottom <= 0.001:
        return
    center = wall.origin + wall.tangent * ((start + end) * 0.5)
    center.z = (bottom + top) * 0.5
    builder.box(
        center,
        Vector((end - start, depth, top - bottom)),
        rotation_z=wall.angle - math.pi * 0.5,
    )


def build_walls(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    stone_builder = MeshBuilder()
    mortar_builder = MeshBuilder()
    collision_builder = MeshBuilder()
    stone_materials = [MATERIALS["stone_charcoal"], MATERIALS["stone_lichen"], MATERIALS["stone_ash"]]

    for wall in make_walls():
        # Mortar backing and collision: full wall minus each opening's rectangle.
        for builder, depth in (
            (mortar_builder, MORTAR_DEPTH),
            (collision_builder, WALL_COLLISION_DEPTH),
        ):
            horizontal_openings = [
                (opening.center_t - opening.mortar_half_width, opening.center_t + opening.mortar_half_width)
                for opening in wall.openings
            ]
            for span_start, span_end in spans_minus_openings(
                -wall.half_length, wall.half_length, horizontal_openings
            ):
                add_wall_piece(builder, wall, depth, span_start, span_end, 0.0, WALL_TOP)
            for opening in wall.openings:
                left = opening.center_t - opening.mortar_half_width
                right = opening.center_t + opening.mortar_half_width
                add_wall_piece(builder, wall, depth, left, right, 0.0, opening.bottom)
                add_wall_piece(builder, wall, depth, left, right, opening.top, WALL_TOP)

        # Irregular stone facing, course by course.
        for course in range(STONE_COURSES):
            course_z = 0.29 + course * COURSE_STEP
            blocking = [
                (opening.center_t - opening.stone_half_width, opening.center_t + opening.stone_half_width)
                for opening in wall.openings
                if opening.bottom - 0.1 < course_z < opening.top + 0.1
            ]
            for span_start, span_end in spans_minus_openings(
                -wall.half_length, wall.half_length, blocking
            ):
                for slot_start, slot_end in tile_span(span_start, span_end, 0.52, 1.34):
                    width = max(0.38, slot_end - slot_start - RNG.uniform(0.045, 0.075))
                    height = RNG.uniform(0.49, 0.64)
                    depth = RNG.uniform(0.5, 0.62)
                    offset = (slot_start + slot_end) * 0.5 + RNG.uniform(-0.018, 0.018)
                    center = wall.origin + wall.tangent * offset + wall.normal * RNG.uniform(-0.035, 0.035)
                    center.z = course_z + RNG.uniform(-0.018, 0.018)
                    stone_builder.irregular_stone(
                        center,
                        Vector((width, depth, height)),
                        rotation_z=wall.angle - math.pi * 0.5 + RNG.uniform(-0.012, 0.012),
                        material_index=RNG.randrange(len(stone_materials)),
                    )

    masonry = create_mesh_object("house_masonry", stone_builder, stone_materials, collection, parent, bevel=0.035)
    masonry["mortar_backed"] = True
    masonry["stone_shape"] = "irregular_trapezoid"

    create_mesh_object("house_mortar_backing", mortar_builder, [MATERIALS["mortar_aged"]], collection, parent, bevel=0.012)

    collision = create_mesh_object(
        "house_wall_collision-colonly", collision_builder, [MATERIALS["mortar_aged"]], collection, parent
    )
    collision.hide_render = True
    collision.hide_viewport = True
    collision["opening_aware_collision"] = True

    # A blackened wall plate closes the ragged stone top under the eaves.
    plate_builder = MeshBuilder()
    for wall in make_walls():
        add_wall_piece(plate_builder, wall, 0.34, -wall.half_length - 0.17, wall.half_length + 0.17, WALL_TOP, WALL_TOP + 0.16)
    create_mesh_object("house_wall_plate", plate_builder, [MATERIALS["wood_blackened"]], collection, parent, bevel=0.02)


def build_floor(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    builder.box(
        Vector((0.0, 0.0, -0.09)),
        Vector((HALF_WIDTH * 2.0 + 0.5, HALF_DEPTH * 2.0 + 0.5, 0.42)),
        material_index=0,
    )
    floor = create_mesh_object("house_floor-col", builder, [MATERIALS["stone_ash"]], collection, parent, bevel=0.02)
    floor["interior_floor_top_m"] = 0.12

    step_builder = MeshBuilder()
    step_builder.box(
        Vector((0.0, -HALF_DEPTH - 0.62, -0.04)),
        Vector((1.9, 0.9, 0.24)),
        material_index=0,
    )
    create_mesh_object("house_doorstep-col", step_builder, [MATERIALS["stone_charcoal"]], collection, parent, bevel=0.03)


def build_roof(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    slope_length = math.hypot(GABLE_RISE, HALF_DEPTH + ROOF_OVERHANG)
    roof_length = HALF_WIDTH * 2.0 + ROOF_OVERHANG * 2.0
    eave_z = WALL_TOP + 0.16
    ridge_z = eave_z + GABLE_RISE
    for side in (-1.0, 1.0):
        # Local +y must climb toward the ridge on the -y slab and descend on +y.
        basis = Matrix.Rotation(-side * ROOF_PITCH, 4, "X")
        center = Vector((0.0, side * (HALF_DEPTH + ROOF_OVERHANG) * 0.5, (eave_z + ridge_z) * 0.5))
        builder.box(center, Vector((roof_length, slope_length + 0.12, 0.12)), material_index=0, basis=basis)
        # Overlapping shingle courses walk down the slope for silhouette texture.
        courses = 4
        for course in range(courses):
            progress = (course + 0.5) / courses
            course_center = Vector(
                (
                    0.0,
                    side * (HALF_DEPTH + ROOF_OVERHANG) * progress,
                    ridge_z - GABLE_RISE * progress + 0.075 + course * 0.008,
                )
            )
            builder.box(
                course_center,
                Vector((roof_length + 0.06, slope_length / courses + 0.14, 0.05)),
                material_index=0,
                basis=basis,
            )
    # Ridge beam caps the seam.
    builder.box(
        Vector((0.0, 0.0, ridge_z + 0.10)),
        Vector((roof_length + 0.1, 0.34, 0.18)),
        material_index=1,
    )
    create_mesh_object(
        "house_roof-col",
        builder,
        [MATERIALS["roof_shingle"], MATERIALS["wood_blackened"]],
        collection,
        parent,
        bevel=0.015,
    )


def build_gables(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    base_z = WALL_TOP + 0.16
    plank_width = 0.42
    plank_count = int(math.ceil(HALF_DEPTH * 2.0 / plank_width))
    for side_x in (-1.0, 1.0):
        for plank in range(plank_count):
            center_y = -HALF_DEPTH + plank_width * (plank + 0.5)
            rise = GABLE_RISE * max(0.06, 1.0 - abs(center_y) / (HALF_DEPTH + ROOF_OVERHANG))
            builder.box(
                Vector((side_x * (HALF_WIDTH - 0.03), center_y, base_z + rise * 0.5)),
                Vector((0.14, plank_width - 0.035, rise)),
                material_index=plank % 2,
            )
    create_mesh_object(
        "house_gable_planks",
        builder,
        [MATERIALS["wood_weathered"], MATERIALS["wood_blackened"]],
        collection,
        parent,
        bevel=0.012,
    )


def build_chimney(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    top_z = WALL_TOP + GABLE_RISE + 0.9
    course_height = 0.46
    courses = int(math.ceil(top_z / course_height))
    center_x = -HALF_WIDTH - 0.42
    for course in range(courses):
        for offset_y in (-0.24, 0.24):
            builder.irregular_stone(
                Vector(
                    (
                        center_x + RNG.uniform(-0.02, 0.02),
                        offset_y + RNG.uniform(-0.02, 0.02),
                        0.23 + course * course_height,
                    )
                ),
                Vector((0.78, 0.5, RNG.uniform(0.38, 0.46))),
                rotation_z=RNG.uniform(-0.02, 0.02),
                material_index=course % 2,
            )
    # Crown ring and flue mouth.
    builder.box(Vector((center_x, 0.0, top_z + 0.12)), Vector((1.02, 1.24, 0.24)), material_index=1)
    chimney = create_mesh_object(
        "house_chimney-col",
        builder,
        [MATERIALS["stone_charcoal"], MATERIALS["stone_ash"]],
        collection,
        parent,
        bevel=0.03,
    )
    chimney["chimney"] = True


def build_windows(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    builder = MeshBuilder()
    window_center_z = (WINDOW_BOTTOM + WINDOW_TOP) * 0.5
    pane_height = WINDOW_TOP - WINDOW_BOTTOM - 0.14
    for wall in make_walls():
        for opening in wall.openings:
            if opening.bottom <= 0.0:
                continue  # the door opening is not a window
            center = wall.origin + wall.tangent * opening.center_t
            center.z = window_center_z
            rotation = wall.angle - math.pi * 0.5
            for strip in range(2):
                offset = (strip - 0.5) * 0.42
                builder.box(
                    center + wall.tangent * offset,
                    Vector((0.38, 0.08, pane_height)),
                    rotation_z=rotation,
                    material_index=0,
                )
            for offset in (-0.42, 0.0, 0.42):
                builder.box(
                    center + wall.tangent * offset,
                    Vector((0.05, 0.13, pane_height + 0.16)),
                    rotation_z=rotation,
                    material_index=1,
                )
            for height in (-pane_height * 0.5 - 0.04, 0.0, pane_height * 0.5 + 0.04):
                builder.box(
                    center + Vector((0.0, 0.0, height)),
                    Vector((0.95, 0.13, 0.055)),
                    rotation_z=rotation,
                    material_index=1,
                )
    create_mesh_object(
        "house_window_glass-col",
        builder,
        [MATERIALS["glass_amber"], MATERIALS["iron_old"]],
        collection,
        parent,
        bevel=0.012,
    )


def build_doorway(collection: bpy.types.Collection, parent: bpy.types.Object) -> None:
    """The tower's warded entry, verbatim: stone frame, hinge empty, plank door."""
    front_center = Vector((0.0, -HALF_DEPTH, 0.0))
    frame_builder = MeshBuilder()
    for side in (-1.0, 1.0):
        frame_builder.box(
            front_center + Vector((side * 0.87, 0.0, 1.38)),
            Vector((0.27, 0.76, 2.76)),
            material_index=0,
        )
    frame_builder.box(
        front_center + Vector((0.0, 0.0, 2.78)),
        Vector((1.95, 0.76, 0.3)),
        material_index=0,
    )
    entry_frame = create_mesh_object(
        "stone_entry_frame-col",
        frame_builder,
        [MATERIALS["stone_ash"]],
        collection,
        parent,
        bevel=0.055,
    )
    entry_frame["doorway_role"] = "sole_house_entrance"

    door_builder = MeshBuilder()
    hinge_point = front_center + Vector((0.73, -0.31, 1.38))
    hinge = bpy.data.objects.new("house_entry_door_hinge", None)
    collection.objects.link(hinge)
    hinge.parent = parent
    hinge.location = hinge_point
    hinge.rotation_euler.z = math.pi
    hinge.empty_display_type = "PLAIN_AXES"
    hinge.empty_display_size = 0.32
    hinge["doorway_role"] = "animated_house_entrance"
    hinge["hinge_aligned"] = True
    hinge["open_angle_degrees"] = 105.0

    entry_center = Vector((DOOR_WIDTH * 0.5, 0.0, 0.0))
    door_builder.box(
        entry_center,
        Vector((DOOR_WIDTH, 0.16, 2.58)),
        material_index=0,
    )
    for plank in range(5):
        center = entry_center + Vector((0.0, 0.0, (plank - 2) * 0.48))
        door_builder.box(
            center,
            Vector((DOOR_WIDTH + 0.07, 0.20, 0.06)),
            material_index=1,
        )
    door = create_mesh_object(
        "house_entry_door",
        door_builder,
        [MATERIALS["wood_blackened"], MATERIALS["iron_old"]],
        collection,
        hinge,
        bevel=0.025,
    )
    door["hinge_aligned"] = True
    door["open_angle_degrees"] = 105.0


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
    camera.data.lens = 30.0

    key_data = bpy.data.lights.new("preview_moon", "AREA")
    key_data.energy = 1100.0
    key_data.color = (0.26, 0.34, 0.56)
    key_data.shape = "DISK"
    key_data.size = 14.0
    key = bpy.data.objects.new("preview_moon", key_data)
    scene.collection.objects.link(key)
    key.location = (7.0, -12.0, 12.0)
    look_at(key, Vector((0.0, 0.0, 2.0)))

    warm_data = bpy.data.lights.new("preview_window_glow", "AREA")
    warm_data.energy = 420.0
    warm_data.color = (0.58, 0.12, 0.035)
    warm_data.size = 4.0
    warm = bpy.data.objects.new("preview_window_glow", warm_data)
    scene.collection.objects.link(warm)
    warm.location = (-5.0, -6.0, 4.0)
    look_at(warm, Vector((0.0, 0.0, 1.8)))

    camera.location = (9.5, -11.0, 6.0)
    look_at(camera, Vector((0.0, 0.0, 2.4)))
    scene.render.filepath = str(EXTERIOR_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    camera.location = (1.4, -6.4, 1.9)
    camera.data.lens = 38.0
    look_at(camera, Vector((0.0, -2.35, 1.5)))
    scene.render.filepath = str(DOOR_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)
    bpy.data.objects.remove(warm, do_unlink=True)


def main() -> None:
    reset_scene()
    configure_world()
    create_materials()

    house_collection = create_collection("VillagerHouse")
    walls_collection = create_collection("Walls", house_collection)
    roof_collection = create_collection("Roof", house_collection)
    details_collection = create_collection("Details", house_collection)

    root = bpy.data.objects.new("VillagerHouseArchitecture", None)
    house_collection.objects.link(root)
    root["footprint_x_m"] = HALF_WIDTH * 2.0
    root["footprint_y_m"] = HALF_DEPTH * 2.0
    root["wall_top_m"] = WALL_TOP
    root["door_count"] = 1
    root["door_matches_tower_entry"] = True
    root["masonry_style"] = "irregular_stone_with_aged_mortar"

    build_walls(walls_collection, root)
    build_floor(walls_collection, root)
    build_gables(roof_collection, root)
    build_roof(roof_collection, root)
    build_chimney(details_collection, root)
    build_windows(details_collection, root)
    build_doorway(details_collection, root)

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
    print(f"Saved editable house: {BLEND_PATH}")
    print(f"Exported runtime house: {GLB_PATH}")
    print(f"Rendered exterior preview: {EXTERIOR_PREVIEW_PATH}")
    print(f"Rendered door preview: {DOOR_PREVIEW_PATH}")


if __name__ == "__main__":
    main()
