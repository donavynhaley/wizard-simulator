# Source Assets

This directory contains editable source files and complete third-party packs that are not imported by Godot.
Runtime-ready assets belong under `assets/` and should be copied there only when a scene actually uses them.

- `blender/` contains the editable Blender sources for project-authored models.
- `third_party_packs/` preserves complete downloaded packs and their original documentation.

The `.gdignore` file prevents source files and thousands of unused pack variants from slowing editor scans.

See `docs/blender-pipeline.md` before adding or exporting a model.
Project-authored `.blend` files belong here, exported `.glb` files belong under `assets/models/`, and gameplay wrappers belong under the owning `game/<feature>/` folder.
