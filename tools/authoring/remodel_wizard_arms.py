"""Build the base or evil first-person wizard arm variant.

Run from the repository root:
    blender -b assets/external/WRAD_ARMS/arms.blend \
        --python tools/authoring/remodel_wizard_arms.py

Build the preserved evil variant with:
    blender -b assets/external/WRAD_ARMS/arms.blend \
        --python tools/authoring/remodel_wizard_arms.py -- --variant evil

The third-party source remains untouched. The script saves an editable derived
Blend file and exports a glTF binary while preserving the original armature,
bone names, skin mesh, and Godot-authored animation compatibility.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


SOURCE_ARMATURE = "arms"
SOURCE_SKIN = "arms_mesh"
SLEEVE_OBJECT = "WizardRobeSleeves"
NAIL_OBJECT = "WizardPointedNails"
RING_SEGMENTS = 20
UPPER_ARM_RING_COUNT = 7
BASE_VARIANT = "base"
EVIL_VARIANT = "evil"


def requested_variant() -> str:
    script_arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--variant" not in script_arguments:
        return BASE_VARIANT
    variant_index = script_arguments.index("--variant") + 1
    if variant_index >= len(script_arguments):
        raise ValueError("--variant requires either 'base' or 'evil'")
    variant = script_arguments[variant_index]
    if variant not in (BASE_VARIANT, EVIL_VARIANT):
        raise ValueError(f"Unknown wizard arm variant: {variant}")
    return variant


def project_root() -> Path:
    return Path(bpy.data.filepath).resolve().parents[3]


def remove_previous_generated_objects() -> None:
    for name in (SLEEVE_OBJECT, NAIL_OBJECT):
        existing = bpy.data.objects.get(name)
        if existing is not None:
            bpy.data.objects.remove(existing, do_unlink=True)


def trim_skin_to_exposed_hands(skin: bpy.types.Object) -> None:
    """Remove geometry hidden by the robe while preserving the rigged hands.

    The source mesh includes complete bare upper arms and forearms. Keeping
    those surfaces under a skinned sleeve causes them to poke through during
    the extreme journal reach pose. The derived asset retains every wrist and
    finger vertex while deleting vertices whose strongest weight belongs to a
    covered arm bone.
    """
    covered_bones = {
        f"{bone}.{side}"
        for side in ("r", "l")
        for bone in (
            "shoulder",
            "bicep",
            "forearm",
            "forearm.Twist0",
            "forearm.Twist1",
        )
    }
    covered_group_indices = {
        group.index for group in skin.vertex_groups if group.name in covered_bones
    }
    mesh = skin.data
    working_mesh = bmesh.new()
    working_mesh.from_mesh(mesh)
    deform_layer = working_mesh.verts.layers.deform.verify()
    covered_vertices = []
    for vertex in working_mesh.verts:
        weights = vertex[deform_layer]
        if not weights:
            continue
        dominant_group = max(weights.items(), key=lambda item: item[1])[0]
        if dominant_group in covered_group_indices:
            covered_vertices.append(vertex)
    bmesh.ops.delete(working_mesh, geom=covered_vertices, context="VERTS")
    working_mesh.to_mesh(mesh)
    working_mesh.free()
    mesh.update()


def material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
) -> bpy.types.Material:
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = color
    principled = next(
        node for node in result.node_tree.nodes if node.type == "BSDF_PRINCIPLED"
    )
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return result


def armature_modifier(
    mesh_object: bpy.types.Object,
    armature: bpy.types.Object,
) -> None:
    mesh_object.parent = armature
    mesh_object.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = mesh_object.modifiers.new("WizardArmature", "ARMATURE")
    modifier.object = armature
    modifier.use_deform_preserve_volume = True


def transported_frame(
    points: list[Vector],
    index: int,
) -> tuple[Vector, Vector]:
    if index == 0:
        tangent = (points[1] - points[0]).normalized()
    elif index == len(points) - 1:
        tangent = (points[-1] - points[-2]).normalized()
    else:
        tangent = (points[index + 1] - points[index - 1]).normalized()
    reference = Vector((0.0, 0.0, 1.0))
    if abs(tangent.dot(reference)) > 0.9:
        reference = Vector((0.0, 1.0, 0.0))
    side = tangent.cross(reference).normalized()
    up = side.cross(tangent).normalized()
    return side, up


def sleeve_points(
    armature: bpy.types.Object,
    side: str,
) -> list[Vector]:
    bones = armature.data.bones
    bicep = bones[f"bicep.{side}"]
    forearm = bones[f"forearm.{side}"]
    upper_start = bicep.head_local
    elbow = bicep.tail_local
    wrist = forearm.tail_local
    upper_arm_points = [
        upper_start.lerp(elbow, amount)
        for amount in (0.0, 0.16, 0.32, 0.5, 0.68, 0.84, 1.0)
    ]
    forearm_points = [
        elbow.lerp(wrist, amount)
        for amount in (0.14, 0.28, 0.42, 0.56, 0.7, 0.82, 0.9, 0.96)
    ]
    return upper_arm_points + forearm_points


def create_sleeves(
    armature: bpy.types.Object,
    robe_material: bpy.types.Material,
    variant: str,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    uvs: list[tuple[float, float]] = []
    weights: dict[str, list[tuple[int, float]]] = {}
    # Keep the first-person silhouette close to the original forearms. The
    # profile gets a little fuller at the shoulder, narrows through the elbow,
    # and ends in a restrained bell cuff instead of a broad rigid tube.
    side_radii = (
        0.46, 0.47, 0.47, 0.45, 0.42, 0.4, 0.38,
        0.38, 0.38, 0.39, 0.4, 0.42, 0.45, 0.48, 0.53,
    )
    up_radii = (
        0.42, 0.43, 0.43, 0.41, 0.39, 0.37, 0.35,
        0.35, 0.35, 0.36, 0.37, 0.39, 0.41, 0.44, 0.47,
    )
    wrinkle_amount = 0.025
    drape_amount = 0.035
    if variant == BASE_VARIANT:
        side_radii = side_radii[:-2] + (0.46, 0.48)
        up_radii = up_radii[:-2] + (0.42, 0.43)
        wrinkle_amount = 0.012
        drape_amount = 0.025

    for side_index, side in enumerate(("r", "l")):
        points = sleeve_points(armature, side)
        side_vertex_start = len(vertices)
        for ring_index, center in enumerate(points):
            side_axis, up_axis = transported_frame(points, ring_index)
            longitudinal = ring_index / (len(points) - 1)
            for segment in range(RING_SEGMENTS):
                u = segment / RING_SEGMENTS
                angle = math.tau * u
                wrinkle = 1.0 + wrinkle_amount * math.sin(
                    angle * 4.0 + longitudinal * 8.0 + side_index * 1.7
                )
                drape = drape_amount * longitudinal * longitudinal * (
                    0.35 + 0.65 * math.sin(angle) ** 2
                )
                radial = (
                    side_axis
                    * math.cos(angle)
                    * side_radii[ring_index]
                    * wrinkle
                    + up_axis
                    * math.sin(angle)
                    * up_radii[ring_index]
                    * wrinkle
                )
                position = center + radial + Vector((0.0, 0.0, -drape))
                vertex_index = len(vertices)
                vertices.append(tuple(position))
                uvs.append((u, longitudinal))

                bicep_name = f"bicep.{side}"
                forearm_name = f"forearm.{side}"
                wrist_name = f"wrist.{side}"
                twist0_name = f"forearm.Twist0.{side}"
                twist1_name = f"forearm.Twist1.{side}"
                if ring_index < UPPER_ARM_RING_COUNT:
                    upper_amount = ring_index / (UPPER_ARM_RING_COUNT - 1)
                    forearm_weight = max(0.0, (upper_amount - 0.72) / 0.56)
                    weights.setdefault(bicep_name, []).append(
                        (vertex_index, 1.0 - forearm_weight)
                    )
                    if forearm_weight > 0.0:
                        weights.setdefault(forearm_name, []).append(
                            (vertex_index, forearm_weight)
                        )
                else:
                    forearm_amounts = (0.14, 0.28, 0.42, 0.56, 0.7, 0.82, 0.9, 0.96)
                    forearm_amount = forearm_amounts[
                        ring_index - UPPER_ARM_RING_COUNT
                    ]
                    if forearm_amount <= 0.42:
                        twist_weight = forearm_amount / 0.6
                        weights.setdefault(forearm_name, []).append(
                            (vertex_index, 1.0 - twist_weight)
                        )
                        weights.setdefault(twist0_name, []).append(
                            (vertex_index, twist_weight)
                        )
                    elif forearm_amount <= 0.82:
                        twist1_weight = (forearm_amount - 0.42) / 0.4
                        weights.setdefault(twist0_name, []).append(
                            (vertex_index, 1.0 - twist1_weight)
                        )
                        weights.setdefault(twist1_name, []).append(
                            (vertex_index, twist1_weight)
                        )
                    else:
                        wrist_weight = (forearm_amount - 0.82) / 0.35
                        weights.setdefault(twist1_name, []).append(
                            (vertex_index, 1.0 - wrist_weight)
                        )
                        weights.setdefault(wrist_name, []).append(
                            (vertex_index, wrist_weight)
                        )

        for ring_index in range(len(points) - 1):
            for segment in range(RING_SEGMENTS):
                next_segment = (segment + 1) % RING_SEGMENTS
                current = side_vertex_start + ring_index * RING_SEGMENTS + segment
                adjacent = (
                    side_vertex_start + ring_index * RING_SEGMENTS + next_segment
                )
                forward = current + RING_SEGMENTS
                forward_adjacent = adjacent + RING_SEGMENTS
                faces.append((current, adjacent, forward_adjacent, forward))

    mesh = bpy.data.meshes.new(SLEEVE_OBJECT)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="RobeUV")
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        for loop_index in polygon.loop_indices:
            uv_layer.data[loop_index].uv = uvs[mesh.loops[loop_index].vertex_index]
    mesh.materials.append(robe_material)
    sleeve_object = bpy.data.objects.new(SLEEVE_OBJECT, mesh)
    bpy.context.collection.objects.link(sleeve_object)
    for bone_name, entries in weights.items():
        group = sleeve_object.vertex_groups.new(name=bone_name)
        for vertex_index, weight in entries:
            group.add([vertex_index], max(0.0, min(1.0, weight)), "REPLACE")
    armature_modifier(sleeve_object, armature)
    return sleeve_object


def nail_frame(direction: Vector) -> tuple[Vector, Vector]:
    reference = Vector((0.0, 0.0, 1.0))
    if abs(direction.dot(reference)) > 0.9:
        reference = Vector((0.0, 1.0, 0.0))
    width_axis = direction.cross(reference).normalized()
    height_axis = width_axis.cross(direction).normalized()
    return width_axis, height_axis


def create_pointed_nails(
    armature: bpy.types.Object,
    nail_material: bpy.types.Material,
    variant: str,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    vertex_bones: list[str] = []
    fingers = ("pinky", "ring", "middle", "index", "thumb")
    for side in ("r", "l"):
        for finger in fingers:
            bone_name = f"finger_{finger}3.{side}"
            bone = armature.data.bones[bone_name]
            direction = (bone.tail_local - bone.head_local).normalized()
            width_axis, height_axis = nail_frame(direction)
            if variant == EVIL_VARIANT:
                length = 0.34 if finger != "thumb" else 0.29
                width = 0.105 if finger in ("middle", "ring") else 0.09
            else:
                length = 0.16 if finger != "thumb" else 0.13
                width = 0.09 if finger in ("middle", "ring") else 0.078
            height = width * 0.28
            base_center = bone.tail_local - direction * 0.1 + height_axis * 0.035
            mid_center = bone.tail_local + direction * length * 0.48
            tip = bone.tail_local + direction * length + height_axis * 0.015
            base_index = len(vertices)
            ring_points = (
                base_center + width_axis * width + height_axis * height,
                base_center - width_axis * width + height_axis * height,
                base_center - width_axis * width - height_axis * height,
                base_center + width_axis * width - height_axis * height,
                mid_center + width_axis * width * 0.62 + height_axis * height * 0.7,
                mid_center - width_axis * width * 0.62 + height_axis * height * 0.7,
                mid_center - width_axis * width * 0.62 - height_axis * height * 0.7,
                mid_center + width_axis * width * 0.62 - height_axis * height * 0.7,
                tip,
            )
            vertices.extend(tuple(point) for point in ring_points)
            vertex_bones.extend([bone_name] * len(ring_points))
            faces.extend(
                [
                    (base_index, base_index + 1, base_index + 2, base_index + 3),
                    (base_index, base_index + 4, base_index + 5, base_index + 1),
                    (base_index + 1, base_index + 5, base_index + 6, base_index + 2),
                    (base_index + 2, base_index + 6, base_index + 7, base_index + 3),
                    (base_index + 3, base_index + 7, base_index + 4, base_index),
                    (base_index + 4, base_index + 8, base_index + 5),
                    (base_index + 5, base_index + 8, base_index + 6),
                    (base_index + 6, base_index + 8, base_index + 7),
                    (base_index + 7, base_index + 8, base_index + 4),
                ]
            )

    mesh = bpy.data.meshes.new(NAIL_OBJECT)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(nail_material)
    nail_object = bpy.data.objects.new(NAIL_OBJECT, mesh)
    bpy.context.collection.objects.link(nail_object)
    groups: dict[str, bpy.types.VertexGroup] = {}
    for vertex_index, bone_name in enumerate(vertex_bones):
        group = groups.get(bone_name)
        if group is None:
            group = nail_object.vertex_groups.new(name=bone_name)
            groups[bone_name] = group
        group.add([vertex_index], 1.0, "REPLACE")
    armature_modifier(nail_object, armature)
    return nail_object


def pack_source_images() -> None:
    for image in bpy.data.images:
        if image.source != "FILE" or image.packed_file is not None:
            continue
        path = Path(bpy.path.abspath(image.filepath))
        if path.is_file():
            image.filepath = str(path)
            image.pack()


def export_asset(
    root: Path,
    armature: bpy.types.Object,
    objects: list[bpy.types.Object],
    variant: str,
) -> None:
    asset_suffix = "_evil" if variant == EVIL_VARIANT else ""
    source_path = root / f"source_assets/blender/player/wizard_arms{asset_suffix}.blend"
    export_path = root / f"assets/models/player/wizard_arms{asset_suffix}.glb"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    export_path.parent.mkdir(parents=True, exist_ok=True)
    pack_source_images()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for item in objects:
        item.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_morph=False,
        export_materials="EXPORT",
        export_yup=True,
        export_apply=False,
    )
    print(f"Saved editable source: {source_path}")
    print(f"Exported runtime model: {export_path}")


def main() -> None:
    root = project_root()
    variant = requested_variant()
    armature = bpy.data.objects[SOURCE_ARMATURE]
    skin = bpy.data.objects[SOURCE_SKIN]
    remove_previous_generated_objects()
    trim_skin_to_exposed_hands(skin)
    if variant == EVIL_VARIANT:
        robe = material("Wizard_Robe_Oxblood", (0.12, 0.018, 0.028, 1.0), 0.94)
        nails = material("Wizard_Nail_Claw", (0.32, 0.22, 0.16, 1.0), 0.38)
    else:
        robe = material("Wizard_Robe_Midnight", (0.11, 0.16, 0.24, 1.0), 0.91)
        nails = material("Wizard_Nail_Natural", (0.46, 0.34, 0.25, 1.0), 0.52)
    sleeves = create_sleeves(armature, robe, variant)
    pointed_nails = create_pointed_nails(armature, nails, variant)
    export_asset(root, armature, [skin, sleeves, pointed_nails], variant)


main()
