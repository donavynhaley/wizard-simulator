# Physical Book System

## Goals

- Books remain physical world props while closed, held, read, and placed on a work surface.
- Book interaction and content do not depend on a particular imported model or model hierarchy.
- Held and table reading use the same open model and the same page renderer.
- Text and rune templates remain readable in first-person and scribing views.
- Designers can replace a page font by assigning a Theme resource to `BookData`.
- Page navigation has a physical leaf-turn animation.

## Scene tree

```text
Book (RigidBody3D)
├── CollisionShape3D
├── Visual (BookVisual scene instance)
│   ├── VisualRoot
│   │   ├── ClosedVisual
│   │   └── OpenVisual
│   │       ├── Imported open model
│   │       ├── PageSurface
│   │       └── PageTurnPivot
│   ├── WorldPose
│   ├── HeldPose
│   ├── ReadingPose
│   ├── TablePose
│   └── AnimationPlayer
└── PageRenderer (BookPageRenderer scene instance)
    └── SpreadRoot
        └── Page layout and RuneTemplateView instances
```

## Responsibilities

| Scene or resource | Responsibility |
| --- | --- |
| `Book` | Interaction state, physics state, page index, and input routing. |
| `BookVisual` | Model adaptation, editor-authored poses, physical page surface, and page-turn motion. |
| `BookPageRenderer` | Typography, page layout, rune visualization, and viewport rendering. |
| `BookData` | Authored title, spreads, and optional page Theme. |
| `BookSpreadData` | One left and right page pair. |
| `BookPageData` | Text and optional rune template for one page. |

## Signal map

| Signal | Source | Consumer | Purpose |
| --- | --- | --- | --- |
| `page_turn_midpoint_reached` | `BookVisual` | `Book` | Commit the target spread while the animated leaf hides the swap. |
| `page_turn_finished` | `BookVisual` | `Book` | Unlock input and restart rune stroke playback. |
| `book_placed` | `OpenBookPlacement` | `RuneScribingStation` | Track the physical table reference. |
| `book_taken` | `OpenBookPlacement` | `RuneScribingStation` | Clear the physical table reference. |

## Model replacement contract

A replacement model is wrapped in a new `BookVisual` scene.
The wrapper assigns its model nodes, page sprites, pose markers, and animation player through exported node paths.
No `Book` script changes are required.
