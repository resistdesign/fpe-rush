# FPE Rush

FPE Rush is a cozy, LaunchBox-inspired collection of 16 atomic demos for
[Folded Paper Engine](https://fpe.papercraft.games/). Each small scene isolates
one Blender-to-Godot concept and exposes the FPE metadata that powers it.

## Run Locally

Requirements:

- Godot 4.5+
- Blender 4.4+ only when regenerating demo assets

```bash
godot --editor project.godot
```

Regenerate the Blender and GLB collection:

```bash
./scripts/build_demos.sh
```

Validate the project and web export:

```bash
./scripts/ci/check.sh
```

## Production

GitHub Actions exports the Godot web build and deploys it to GitHub Pages.
The production hostname is <https://rush.foldedpaperengine.com>.

FPE is an MIT-licensed project by Papercraft Games. FPE Rush is an independent
learning gallery built with the official runtime.

