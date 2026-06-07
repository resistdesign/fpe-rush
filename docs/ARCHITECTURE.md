# Architecture

## Runtime Shape

`Main` owns two siblings:

- `FoldedPaperEngine`, which loads and clears one authored GLB at a time.
- A `CanvasLayer` gallery shell, which survives FPE level changes.

The shell selects a catalog entry, asks FPE to load its GLB, and dispatches the
entry's activation event through `FPEEventManager`. FPE reads Blender custom
properties from glTF `extras`, applies features, and executes scene commands.

## Asset Pipeline

`tools/blender/build_demo_collection.py` creates one Blender scene and one GLB
per catalog entry. Every FPE property is assigned as a Blender custom property
whose key begins with `fpe_`. Blender exports those dictionaries with
`export_extras=True`.

The generated GLBs are runtime inputs. The `.blend` files are editable source
and evidence of the authoring setup. The generator is the reproducible baseline
for both.

## Design Constraints

- One primary FPE concept per demo.
- Shared low-poly, papercraft-lite visual language.
- Keyboard, mouse, and touch-capable gallery controls.
- Web renderer and assets that fit GitHub Pages hosting.
- No backend, telemetry, or runtime network dependency.

