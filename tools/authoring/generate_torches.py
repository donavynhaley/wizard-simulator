"""Generate the three torch props (standing, wall sconce, door lantern).

Chunky 80s dark-fantasy low poly, matching the wizard tower palette.
Saves the editable blend and exports one runtime GLB per torch.

Run from the repository root:
    blender --background --python tools/authoring/generate_torches.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BLEND_PATH = PROJECT_ROOT / "source_assets/blender/props/torches.blend"
GLB_DIR = PROJECT_ROOT / "assets/models"
PREVIEW_PATH = Path("/tmp/torches_preview.png")

TAU = math.tau
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

    def prism(
        self,
        base_center: Vector,
        radius_bottom: float,
        radius_top: float,
        height: float,
        segments: int = 6,
        material_index: int = 0,
        basis: Matrix | None = None,
        start_angle: float = 0.0,
        cap_bottom: bool = True,
        cap_top: bool = True,
    ) -> None:
        """Faceted low-poly cylinder/cone with local +Z axis from base_center."""
        if basis is None:
            basis = Matrix.Identity(4)
        start = len(self.vertices)
        for radius, z in ((radius_bottom, 0.0), (radius_top, height)):
            for index in range(segments):
                angle = start_angle + TAU * index / segments
                local = Vector((math.cos(angle) * radius, math.sin(angle) * radius, z))
                self.vertices.append(tuple(basis @ local + base_center))
        bottom = list(range(start, start + segments))
        top = list(range(start + segments, start + segments * 2))
        for index in range(segments):
            next_index = (index + 1) % segments
            self.faces.append((bottom[index], top[index], top[next_index], bottom[next_index]))
            self.material_indices.append(material_index)
        if cap_top:
            self.faces.append(tuple(top))
            self.material_indices.append(material_index)
        if cap_bottom:
            self.faces.append(tuple(reversed(bottom)))
            self.material_indices.append(material_index)

    def link_frame(
        self,
        center: Vector,
        width: float,
        height: float,
        thickness: float,
        depth: float,
        basis: Matrix,
        material_index: int = 0,
    ) -> None:
        """Rectangular chain link built from four thin bars."""
        offsets = (
            (Vector(((width - thickness) * 0.5, 0.0, 0.0)), Vector((thickness, depth, height))),
            (Vector((-(width - thickness) * 0.5, 0.0, 0.0)), Vector((thickness, depth, height))),
            (Vector((0.0, 0.0, (height - thickness) * 0.5)), Vector((width, depth, thickness))),
            (Vector((0.0, 0.0, -(height - thickness) * 0.5)), Vector((width, depth, thickness))),
        )
        for offset, dimensions in offsets:
            self.box(center + basis @ offset, dimensions, material_index=material_index, basis=basis)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.objects,
        bpy.data.collections,
        bpy.data.lights,
        bpy.data.cameras,
        bpy.data.worlds,
    ):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def configure_world() -> None:
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.color = (0.008, 0.01, 0.015)


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
    # Palette mirrors tools/authoring/generate_wizard_tower.py so props sit in the same world.
    create_material("stone_ash", (0.17, 0.165, 0.15, 1.0), 0.94)
    create_material("wood_blackened", (0.115, 0.047, 0.018, 1.0), 0.91)
    create_material("wood_weathered", (0.20, 0.095, 0.032, 1.0), 0.94)
    create_material("iron_old", (0.055, 0.06, 0.06, 1.0), 0.72, 0.72)
    create_material("brass_tarnished", (0.31, 0.19, 0.055, 1.0), 0.58, 0.76)
    create_material("rag_pitch", (0.075, 0.05, 0.032, 1.0), 1.0)
    create_material(
        "ember_coal",
        (0.16, 0.05, 0.012, 1.0),
        0.9,
        emission=(1.0, 0.32, 0.05, 1.0),
        emission_strength=1.9,
    )
    create_material(
        "glass_amber",
        (0.30, 0.10, 0.012, 1.0),
        0.5,
        emission=(0.55, 0.15, 0.015, 1.0),
        emission_strength=1.7,
    )
    create_material("candle_wax", (0.68, 0.6, 0.46, 1.0), 0.62)


def create_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def create_root(name: str, collection: bpy.types.Collection) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.2
    collection.objects.link(root)
    return root


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


def godot_point(blender_point: Vector) -> Vector:
    """Blender Z-up -> Godot Y-up (matches the glTF exporter's axis conversion)."""
    return Vector((blender_point.x, blender_point.z, -blender_point.y))


def build_standing_torch(collection: bpy.types.Collection) -> tuple[bpy.types.Object, Vector]:
    """Floor torch: hex stone base, iron socket with claw feet, banded pole, ember cup.

    Origin at ground level under the pole.
    """
    root = create_root("StandingTorch", collection)

    stone = MeshBuilder()
    stone.prism(Vector((0.0, 0.0, 0.0)), 0.27, 0.21, 0.09, segments=6, start_angle=TAU / 12)
    create_mesh_object("standing_base_stone", stone, [MATERIALS["stone_ash"]], collection, root, bevel=0.02)

    iron = MeshBuilder()
    iron.prism(Vector((0.0, 0.0, 0.09)), 0.105, 0.07, 0.14, segments=6)
    for index in range(3):
        angle = TAU * index / 3
        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        claw_basis = Matrix.Rotation(angle, 4, "Z") @ Matrix.Rotation(math.radians(38.0), 4, "Y")
        iron.box(radial * 0.14 + Vector((0.0, 0.0, 0.10)), Vector((0.16, 0.045, 0.04)), basis=claw_basis)
    iron.prism(Vector((0.0, 0.0, 0.34)), 0.058, 0.058, 0.05, segments=6)
    iron.prism(Vector((0.0, 0.0, 1.02)), 0.052, 0.052, 0.05, segments=6)
    iron.prism(Vector((0.0, 0.0, 1.22)), 0.055, 0.115, 0.17, segments=6)
    create_mesh_object("standing_ironwork", iron, [MATERIALS["iron_old"]], collection, root, bevel=0.008)

    brass = MeshBuilder()
    brass.prism(Vector((0.0, 0.0, 1.385)), 0.122, 0.122, 0.03, segments=6)
    create_mesh_object("standing_brass_rim", brass, [MATERIALS["brass_tarnished"]], collection, root, bevel=0.005)

    pole = MeshBuilder()
    pole.prism(Vector((0.0, 0.0, 0.16)), 0.048, 0.037, 1.1, segments=6, start_angle=TAU / 12)
    create_mesh_object("standing_pole", pole, [MATERIALS["wood_blackened"]], collection, root, bevel=0.008)

    head = MeshBuilder()
    head.prism(Vector((0.0, 0.0, 1.36)), 0.072, 0.086, 0.19, segments=6)
    create_mesh_object("standing_head", head, [MATERIALS["rag_pitch"]], collection, root, bevel=0.012)

    ember = MeshBuilder()
    ember.prism(Vector((0.0, 0.0, 1.55)), 0.068, 0.032, 0.055, segments=6)
    create_mesh_object("standing_embers", ember, [MATERIALS["ember_coal"]], collection, root, bevel=0.008)

    return root, godot_point(Vector((0.0, 0.0, 1.58)))


def build_wall_torch(collection: bpy.types.Collection) -> tuple[bpy.types.Object, Vector]:
    """Wall sconce: diamond back plate, bracket arm, tilted torch in an iron collar.

    Origin at the wall plate center; wall plane is XZ, torch leans out along +Y
    (Godot -Z, so the node's -Z axis points into the room).
    """
    root = create_root("WallTorch", collection)
    tilt = Matrix.Rotation(math.radians(-22.0), 4, "X")
    axis = tilt @ Vector((0.0, 0.0, 1.0))
    stub_base = Vector((0.0, 0.30, -0.10))

    iron = MeshBuilder()
    iron.box(Vector((0.0, 0.02, 0.0)), Vector((0.24, 0.04, 0.24)), basis=Matrix.Rotation(math.radians(45.0), 4, "Y"))
    iron.box(Vector((0.0, 0.015, 0.0)), Vector((0.15, 0.03, 0.34)))
    iron.box(Vector((0.0, 0.16, 0.0)), Vector((0.05, 0.28, 0.05)))
    strut_basis = Matrix.Rotation(math.radians(-42.0), 4, "X")
    iron.box(Vector((0.0, 0.14, -0.10)), Vector((0.04, 0.04, 0.30)), basis=strut_basis)
    iron.prism(stub_base + axis * 0.10, 0.082, 0.082, 0.075, segments=6, basis=tilt)
    create_mesh_object("wall_bracket", iron, [MATERIALS["iron_old"]], collection, root, bevel=0.008)

    torch_wood = MeshBuilder()
    torch_wood.prism(stub_base, 0.036, 0.05, 0.42, segments=6, basis=tilt, start_angle=TAU / 12)
    create_mesh_object("wall_torch_pole", torch_wood, [MATERIALS["wood_weathered"]], collection, root, bevel=0.008)

    head = MeshBuilder()
    head.prism(stub_base + axis * 0.42, 0.058, 0.07, 0.16, segments=6, basis=tilt)
    create_mesh_object("wall_torch_head", head, [MATERIALS["rag_pitch"]], collection, root, bevel=0.012)

    ember = MeshBuilder()
    ember.prism(stub_base + axis * 0.58, 0.055, 0.026, 0.05, segments=6, basis=tilt)
    create_mesh_object("wall_torch_embers", ember, [MATERIALS["ember_coal"]], collection, root, bevel=0.008)

    return root, godot_point(stub_base + axis * 0.62)


def build_door_lantern(collection: bpy.types.Collection) -> tuple[bpy.types.Object, Vector]:
    """Hanging lantern on a wrought bracket: chain, iron cage, amber glass, brass cap.

    Origin at the wall attachment; bracket arm extends +Y (Godot -Z), the
    lantern hangs from the arm tip.
    """
    root = create_root("DoorLantern", collection)
    hang = Vector((0.0, 0.62, 0.0))

    iron = MeshBuilder()
    iron.box(Vector((0.0, 0.015, 0.0)), Vector((0.20, 0.03, 0.30)))
    iron.box(Vector((0.055, 0.035, 0.11)), Vector((0.035, 0.02, 0.035)))
    iron.box(Vector((-0.055, 0.035, -0.11)), Vector((0.035, 0.02, 0.035)))
    iron.box(Vector((0.0, 0.33, 0.02)), Vector((0.05, 0.66, 0.06)))
    iron.box(Vector((0.0, 0.615, -0.015)), Vector((0.06, 0.07, 0.13)))
    strut_basis = Matrix.Rotation(math.radians(-52.0), 4, "X")
    iron.box(Vector((0.0, 0.22, -0.155)), Vector((0.04, 0.04, 0.56)), basis=strut_basis)
    iron.box(Vector((0.0, 0.045, -0.28)), Vector((0.06, 0.09, 0.05)))
    create_mesh_object("lantern_bracket", iron, [MATERIALS["iron_old"]], collection, root, bevel=0.008)

    chain = MeshBuilder()
    for index in range(4):
        link_basis = Matrix.Rotation(math.radians(90.0 * (index % 2)), 4, "Z")
        center = hang + Vector((0.0, 0.0, -0.10 - 0.082 * index))
        chain.link_frame(center, 0.058, 0.098, 0.015, 0.015, link_basis)
    create_mesh_object("lantern_chain", chain, [MATERIALS["iron_old"]], collection, root)

    cage_top = hang.z - 0.46
    cage = MeshBuilder()
    for side in range(4):
        angle = TAU * side / 4
        rim_basis = Matrix.Rotation(angle, 4, "Z")
        cage.box(hang + rim_basis @ Vector((0.0, 0.115, cage_top - hang.z + 0.005)), Vector((0.27, 0.04, 0.045)), basis=rim_basis)
        cage.box(hang + rim_basis @ Vector((0.0, 0.105, cage_top - hang.z - 0.175)), Vector((0.23, 0.022, 0.024)), basis=rim_basis)
    for corner_x, corner_y in ((0.115, 0.115), (-0.115, 0.115), (0.115, -0.115), (-0.115, -0.115)):
        cage.box(hang + Vector((corner_x, corner_y, cage_top - hang.z - 0.17)), Vector((0.032, 0.032, 0.35)))
    cage.box(hang + Vector((0.0, 0.0, cage_top - hang.z - 0.365)), Vector((0.28, 0.28, 0.045)))
    create_mesh_object("lantern_cage", cage, [MATERIALS["iron_old"]], collection, root, bevel=0.006)

    glass = MeshBuilder()
    for side in range(4):
        angle = TAU * side / 4
        pane_basis = Matrix.Rotation(angle, 4, "Z")
        glass.box(hang + pane_basis @ Vector((0.0, 0.1, cage_top - hang.z - 0.17)), Vector((0.2, 0.012, 0.3)), basis=pane_basis)
    create_mesh_object("lantern_glass", glass, [MATERIALS["glass_amber"]], collection, root)

    brass = MeshBuilder()
    brass.prism(hang + Vector((0.0, 0.0, cage_top - hang.z + 0.025)), 0.185, 0.03, 0.14, segments=4, start_angle=TAU / 8)
    brass.prism(hang + Vector((0.0, 0.0, cage_top - hang.z + 0.165)), 0.028, 0.028, 0.05, segments=6)
    brass.prism(hang + Vector((0.0, 0.0, cage_top - hang.z - 0.45)), 0.05, 0.012, 0.085, segments=4, start_angle=TAU / 8)
    create_mesh_object("lantern_brass", brass, [MATERIALS["brass_tarnished"]], collection, root, bevel=0.005)

    candle = MeshBuilder()
    candle.prism(hang + Vector((0.0, 0.0, cage_top - hang.z - 0.34)), 0.034, 0.03, 0.09, segments=6)
    create_mesh_object("lantern_candle", candle, [MATERIALS["candle_wax"]], collection, root)
    candle_tip = hang + Vector((0.0, 0.0, cage_top - hang.z - 0.25))

    return root, godot_point(candle_tip)


def export_torch(root: bpy.types.Object, glb_name: str) -> None:
    for obj in bpy.data.objects:
        obj.select_set(False)
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_DIR / glb_name),
        export_format="GLB",
        export_apply=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
        use_selection=True,
    )
    for obj in bpy.data.objects:
        obj.select_set(False)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def build_preview_set(preview_collection: bpy.types.Collection) -> None:
    """Ground plane and wall segments so mounted props read in the preview."""
    builder = MeshBuilder()
    builder.box(Vector((0.0, 0.35, -0.05)), Vector((5.2, 3.2, 0.1)))
    builder.box(Vector((0.1, 0.87, 1.5)), Vector((1.3, 0.14, 3.0)))
    builder.box(Vector((1.45, 0.87, 1.7)), Vector((1.3, 0.14, 3.4)))
    root = bpy.data.objects.new("preview_set", None)
    preview_collection.objects.link(root)
    create_mesh_object("preview_backdrop", builder, [MATERIALS["stone_ash"]], preview_collection, root)


def render_preview() -> None:
    scene = bpy.context.scene
    camera_data = bpy.data.cameras.new("preview_camera")
    camera = bpy.data.objects.new("preview_camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 40.0

    key_data = bpy.data.lights.new("preview_moon", "AREA")
    key_data.energy = 320.0
    key_data.color = (0.30, 0.38, 0.58)
    key_data.shape = "DISK"
    key_data.size = 6.0
    key = bpy.data.objects.new("preview_moon", key_data)
    scene.collection.objects.link(key)
    key.location = (3.2, -4.4, 4.6)
    look_at(key, Vector((0.0, 0.0, 1.2)))

    warm_data = bpy.data.lights.new("preview_fire_glow", "AREA")
    warm_data.energy = 140.0
    warm_data.color = (0.85, 0.42, 0.12)
    warm_data.size = 3.2
    warm = bpy.data.objects.new("preview_fire_glow", warm_data)
    scene.collection.objects.link(warm)
    warm.location = (-2.6, -2.4, 2.4)
    look_at(warm, Vector((0.0, 0.0, 1.3)))

    camera.location = (0.25, -4.9, 1.75)
    look_at(camera, Vector((0.25, 0.0, 1.25)))
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)
    bpy.data.objects.remove(warm, do_unlink=True)


def main() -> None:
    reset_scene()
    configure_world()
    create_materials()

    standing_collection = create_collection("StandingTorch")
    wall_collection = create_collection("WallTorch")
    lantern_collection = create_collection("DoorLantern")
    preview_collection = create_collection("PreviewOnly")

    standing_root, standing_anchor = build_standing_torch(standing_collection)
    wall_root, wall_anchor = build_wall_torch(wall_collection)
    lantern_root, lantern_anchor = build_door_lantern(lantern_collection)

    GLB_DIR.mkdir(parents=True, exist_ok=True)
    export_torch(standing_root, "standing_torch.glb")
    export_torch(wall_root, "wall_torch.glb")
    export_torch(lantern_root, "door_lantern.glb")

    # Arrange for the preview render (after export so every GLB stays at origin).
    standing_root.location = Vector((-1.35, 0.3, 0.0))
    wall_root.location = Vector((0.1, 0.8, 1.55))
    wall_root.rotation_euler = (0.0, 0.0, math.pi)
    lantern_root.location = Vector((1.45, 0.8, 2.75))
    lantern_root.rotation_euler = (0.0, 0.0, math.pi)
    build_preview_set(preview_collection)

    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    render_preview()

    print(f"Saved editable torches: {BLEND_PATH}")
    for name, anchor in (
        ("standing_torch", standing_anchor),
        ("wall_torch", wall_anchor),
        ("door_lantern", lantern_anchor),
    ):
        print(
            f"Exported {name}.glb  flame anchor (Godot): "
            f"({anchor.x:.3f}, {anchor.y:.3f}, {anchor.z:.3f})"
        )


main()
