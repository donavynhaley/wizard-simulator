"""Author the open journal as a worn, inward-curved dark-fantasy book.

Run with:
    blender --background source_assets/blender/props/book.blend \
        --python tools/authoring/bend_book_to_overlay.py
"""

from math import pi
from pathlib import Path

import bmesh
import bpy


OPEN_BOOK_OBJECT = "Cube.001"
ORIGINAL_OPEN_BOOK_OBJECT = "JournalSource_OpenBookOriginal"
DETAIL_PREFIX = "JournalDetail_"
CURVE_VERSION = 5
OVERLAY_HALF_WIDTH_METERS = 0.18
OVERLAY_CENTER_DIP_METERS = 0.012
CURVE_CUTS_PER_EDGE = 7
COVER_TOP_HEIGHT = 0.013


def ensure_original_open_mesh() -> bpy.types.Object:
    existing = bpy.data.objects.get(ORIGINAL_OPEN_BOOK_OBJECT)
    if existing is not None and existing.type == "MESH":
        return existing
    backup_path = Path(bpy.data.filepath).with_suffix(".blend1")
    if not backup_path.exists():
        raise RuntimeError(f"Missing original book backup: {backup_path}")
    with bpy.data.libraries.load(str(backup_path), link=False) as (
        source_data,
        loaded_data,
    ):
        if "Cube.003" not in source_data.meshes:
            raise RuntimeError(f"Missing original open-book mesh in {backup_path}")
        loaded_data.meshes = ["Cube.003"]
    original_mesh = loaded_data.meshes[0]
    if original_mesh is None:
        raise RuntimeError(f"Could not load original open-book mesh from {backup_path}")
    original = bpy.data.objects.new(ORIGINAL_OPEN_BOOK_OBJECT, original_mesh)
    bpy.context.collection.objects.link(original)
    original.hide_render = True
    original.hide_viewport = True
    original.hide_set(True)
    return original


def restore_original_open_mesh(book: bpy.types.Object) -> None:
    original = ensure_original_open_mesh()
    book.data = original.data.copy()


def remove_previous_details() -> None:
    for obj in list(bpy.data.objects):
        if obj.name.startswith(DETAIL_PREFIX):
            bpy.data.objects.remove(obj, do_unlink=True)
    for meshes in (bpy.data.meshes, bpy.data.curves):
        for data in list(meshes):
            if data.users == 0:
                meshes.remove(data)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
    return material


def cover_height(x: float) -> float:
    distance_ratio = min(abs(x) / OVERLAY_HALF_WIDTH_METERS, 1.0)
    return COVER_TOP_HEIGHT - OVERLAY_CENTER_DIP_METERS * (1.0 - distance_ratio) ** 2


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 2) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bevel = obj.modifiers.new("Soft worn edges", "BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)


def create_box(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    material: bpy.types.Material,
    bevel_width: float,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = DETAIL_PREFIX + name
    obj.data.name = DETAIL_PREFIX + name + "Mesh"
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    apply_bevel(obj, bevel_width)
    return obj


def create_curved_rail(
    name: str,
    x_start: float,
    x_end: float,
    y_center: float,
    width: float,
    thickness: float,
    material: bpy.types.Material,
    samples: int = 12,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for index in range(samples + 1):
        ratio = index / samples
        x = x_start + (x_end - x_start) * ratio
        z = cover_height(x) + thickness * 0.5
        vertices.extend([
            (x, y_center - width * 0.5, z - thickness * 0.5),
            (x, y_center + width * 0.5, z - thickness * 0.5),
            (x, y_center - width * 0.5, z + thickness * 0.5),
            (x, y_center + width * 0.5, z + thickness * 0.5),
        ])
    for index in range(samples):
        start = index * 4
        end = (index + 1) * 4
        faces.extend([
            (start, end, end + 1, start + 1),
            (start + 2, start + 3, end + 3, end + 2),
            (start, start + 2, end + 2, end),
            (start + 1, end + 1, end + 3, start + 3),
        ])
    faces.extend([
        (0, 1, 3, 2),
        (samples * 4, samples * 4 + 2, samples * 4 + 3, samples * 4 + 1),
    ])
    mesh = bpy.data.meshes.new(DETAIL_PREFIX + name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(DETAIL_PREFIX + name, mesh)
    bpy.context.collection.objects.link(obj)
    apply_bevel(obj, min(width, thickness) * 0.28)
    return obj


def create_stitched_outline(
    name: str,
    side: int,
    material: bpy.types.Material,
) -> bpy.types.Object:
    outer_x = 0.197 * side
    inner_x = 0.010 * side
    top_y = 0.098
    bottom_y = -0.098
    horizontal_x = [
        inner_x + (outer_x - inner_x) * index / 14.0
        for index in range(15)
    ]
    points = []
    for x in horizontal_x:
        points.append((x, top_y, cover_height(x) + 0.0032))
    for index in range(1, 13):
        y = top_y + (bottom_y - top_y) * index / 13.0
        points.append((outer_x, y, cover_height(outer_x) + 0.0032))
    for x in reversed(horizontal_x):
        points.append((x, bottom_y, cover_height(x) + 0.0032))
    for index in range(1, 13):
        y = bottom_y + (top_y - bottom_y) * index / 13.0
        points.append((inner_x, y, cover_height(inner_x) + 0.0032))
    curve = bpy.data.curves.new(DETAIL_PREFIX + name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = 0.00045
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinates in zip(spline.points, points):
        point.co = (*coordinates, 1.0)
    spline.use_cyclic_u = True
    curve.materials.append(material)
    obj = bpy.data.objects.new(DETAIL_PREFIX + name, curve)
    bpy.context.collection.objects.link(obj)
    return obj


def create_corner_plate(
    name: str,
    side: int,
    vertical_side: int,
    material: bpy.types.Material,
) -> bpy.types.Object:
    outer_x = 0.202 * side
    inner_x = 0.180 * side
    outer_y = 0.102 * vertical_side
    inner_y = 0.080 * vertical_side
    thickness = 0.0022
    triangle = [
        (outer_x, outer_y),
        (inner_x, outer_y),
        (outer_x, inner_y),
    ]
    vertices = []
    for z_offset in (0.0015, 0.0015 + thickness):
        for x, y in triangle:
            vertices.append((x, y, cover_height(x) + z_offset))
    faces = [
        (0, 2, 1),
        (3, 4, 5),
        (0, 1, 4, 3),
        (1, 2, 5, 4),
        (2, 0, 3, 5),
    ]
    mesh = bpy.data.meshes.new(DETAIL_PREFIX + name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(DETAIL_PREFIX + name, mesh)
    bpy.context.collection.objects.link(obj)
    apply_bevel(obj, 0.0008, 3)
    return obj


def create_spine_details(
    leather: bpy.types.Material,
    brass: bpy.types.Material,
) -> list[bpy.types.Object]:
    details = []
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=0.0105,
        depth=0.204,
        location=(0.0, 0.0, -0.009),
        rotation=(pi * 0.5, 0.0, 0.0),
    )
    spine = bpy.context.object
    spine.name = DETAIL_PREFIX + "RoundedSpine"
    spine.data.name = DETAIL_PREFIX + "RoundedSpineMesh"
    spine.data.materials.append(leather)
    apply_bevel(spine, 0.0007, 2)
    details.append(spine)
    for index, y in enumerate((-0.073, 0.0, 0.073)):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.0107,
            minor_radius=0.00135,
            major_segments=24,
            minor_segments=6,
            location=(0.0, y, -0.009),
            rotation=(pi * 0.5, 0.0, 0.0),
        )
        band = bpy.context.object
        band.name = DETAIL_PREFIX + f"SpineBand{index + 1}"
        band.data.name = DETAIL_PREFIX + f"SpineBand{index + 1}Mesh"
        band.data.materials.append(brass)
        details.append(band)
    return details


def smart_uv_generated_details(details: list[bpy.types.Object]) -> None:
    for obj in details:
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def bend_open_book() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    book = bpy.data.objects.get(OPEN_BOOK_OBJECT)
    if book is None or book.type != "MESH":
        raise RuntimeError(f"Missing open-book mesh object: {OPEN_BOOK_OBJECT}")
    ensure_original_open_mesh()

    if int(book.get("overlay_curve_version", 0)) < CURVE_VERSION:
        restore_original_open_mesh(book)
        mesh = book.data
        editable = bmesh.new()
        editable.from_mesh(mesh)
        bmesh.ops.triangulate(editable, faces=list(editable.faces))
        bmesh.ops.subdivide_edges(
            editable,
            edges=list(editable.edges),
            cuts=CURVE_CUTS_PER_EDGE,
            use_grid_fill=True,
        )
        local_half_width = OVERLAY_HALF_WIDTH_METERS / abs(book.scale.x)
        local_center_dip = OVERLAY_CENTER_DIP_METERS / abs(book.scale.z)
        for vertex in editable.verts:
            distance_ratio = min(abs(vertex.co.x) / local_half_width, 1.0)
            vertex.co.z -= local_center_dip * (1.0 - distance_ratio) ** 2
        maximum_face_span = max(
            max(vertex.co.x for vertex in face.verts)
            - min(vertex.co.x for vertex in face.verts)
            for face in editable.faces
        )
        if maximum_face_span * abs(book.scale.x) > 0.055:
            raise RuntimeError(
                f"Curved book still contains a spanning face: {maximum_face_span:.5f}"
            )
        editable.to_mesh(mesh)
        editable.free()
        mesh.update()
        for polygon in mesh.polygons:
            polygon.use_smooth = abs(polygon.normal.z) > 0.7

    remove_previous_details()
    leather = make_material("Leather_Oxblood", (0.065, 0.02, 0.014, 1.0), 0.88)
    parchment = make_material("Parchment_Page_Edges", (0.48, 0.36, 0.22, 1.0), 0.96)
    dark_leather = make_material("Leather_Embossed_Trim", (0.025, 0.006, 0.004, 1.0), 0.82)
    thread = make_material("Thread_Faded_Tan", (0.31, 0.18, 0.075, 1.0), 0.92)
    brass = make_material("Brass_Antique", (0.22, 0.105, 0.028, 1.0), 0.68, 0.72)
    book.data.materials.clear()
    book.data.materials.append(leather)
    book.data.materials.append(parchment)

    details: list[bpy.types.Object] = []
    for side in (-1, 1):
        inner_x = 0.009 * side
        outer_x = 0.198 * side
        for vertical_side in (-1, 1):
            details.append(create_curved_rail(
                f"{'Left' if side < 0 else 'Right'}Rail{'Bottom' if vertical_side < 0 else 'Top'}",
                inner_x,
                outer_x,
                0.099 * vertical_side,
                0.006,
                0.0024,
                dark_leather,
            ))
        for x, label in ((outer_x, "Outer"), (inner_x, "Gutter")):
            details.append(create_box(
                f"{'Left' if side < 0 else 'Right'}{label}Rail",
                (x, 0.0, cover_height(x) + 0.0012),
                (0.006, 0.194, 0.0024),
                dark_leather,
                0.0007,
            ))
        details.append(create_stitched_outline(
            f"{'Left' if side < 0 else 'Right'}Stitching", side, thread))
        for vertical_side in (-1, 1):
            details.append(create_corner_plate(
                f"{'Left' if side < 0 else 'Right'}Corner{'Bottom' if vertical_side < 0 else 'Top'}",
                side,
                vertical_side,
                brass,
            ))
    details.extend(create_spine_details(leather, brass))
    smart_uv_generated_details(details)

    book["overlay_curve_version"] = CURVE_VERSION
    book["overlay_half_width_m"] = OVERLAY_HALF_WIDTH_METERS
    book["overlay_center_dip_m"] = OVERLAY_CENTER_DIP_METERS
    book["realistic_detail_pass"] = True
    if "overlay_center_rise_m" in book:
        del book["overlay_center_rise_m"]
    return book, details


def save_source_and_export(
    book: bpy.types.Object,
    details: list[bpy.types.Object],
) -> Path:
    source_path = Path(bpy.data.filepath).resolve()
    if source_path.name != "book.blend":
        raise RuntimeError(f"Expected book.blend, got {source_path}")
    repository_root = source_path.parents[3]
    export_path = repository_root / "assets" / "models" / "book_open.glb"

    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    bpy.ops.object.select_all(action="DESELECT")
    export_objects = [bpy.data.objects.get(OPEN_BOOK_OBJECT)] + [
        bpy.data.objects.get(obj.name) for obj in details
    ]
    for obj in export_objects:
        if obj is None:
            raise RuntimeError("Open-book detail disappeared before export")
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
    )
    if not export_path.exists() or export_path.stat().st_size < 10_000:
        raise RuntimeError(f"glTF did not contain the detailed open book: {export_path}")
    return export_path


open_book, authored_details = bend_open_book()
output = save_source_and_export(open_book, authored_details)
print(
    "Detailed inward-curved book exported:",
    output,
    "dimensions_m=",
    tuple(round(value, 4) for value in open_book.dimensions),
    "base_vertices=",
    len(open_book.data.vertices),
    "detail_objects=",
    len(authored_details),
)
