# FPE Rush Agent Guide

## Mission

FPE Rush is a small, web-first Godot gallery for learning Folded Paper Engine
(FPE) one concept at a time. Each entry must be a cozy, focused demonstration,
not a broad sample level.

## Source Of Truth

- `docs/DEMO_CATALOG.md` defines the 16-demo curriculum and acceptance checks.
- `docs/PROGRESS.md` records completed work, current risks, and the next task.
- `tools/blender/build_demo_collection.py` owns generated Blender and GLB assets.
- `vendor/fpe/VERSION.md` records the pinned upstream FPE release.
- GitHub issues are for work that outlives the current branch.

## Planning Protocol

Before substantial work:

1. Read this file, `README.md`, `docs/DEMO_CATALOG.md`, and `docs/PROGRESS.md`.
2. Inspect `git status`, recent commits, and active GitHub issues.
3. Write a short task plan with verifiable outcomes.
4. Keep one task in progress at a time.
5. Update `docs/PROGRESS.md` when a milestone or assumption changes.

Plans should state the user-visible result, files likely to change, validation
commands, and deployment impact. Do not call a task complete until its listed
checks pass.

## FPE Rules

- Author FPE gameplay metadata in Blender and export it as glTF `extras`.
- Use the official FPE runtime to load demo GLBs.
- Project GDScript may explain, orchestrate, or extend FPE, but must not fake the
  concept named by a demo.
- Keep every demo atomic. Shared presentation is fine; shared hidden gameplay
  that obscures what FPE is doing is not.
- Preserve the Blender source and generation path for all authored GLBs.
- Pin FPE upgrades deliberately and record the release and migration notes.

## Project Layout

- `addons/folded_paper_engine/`: pinned official Godot addon
- `assets/`: project-owned audio and visual assets
- `blender/`: generated `.blend` source scenes
- `demos/glb/`: generated GLB scenes consumed by FPE
- `docs/`: architecture, curriculum, progress, and deployment notes
- `scripts/`: Godot application and validation code
- `tools/blender/`: reproducible Blender authoring scripts

## Validation

Run these before committing:

```bash
./scripts/ci/check.sh
```

For asset changes, regenerate first:

```bash
./scripts/build_demos.sh
```

The validation script must check Godot parsing/import, all 16 catalog entries,
all expected GLBs, and a web export.

## Git Practice

- Keep commits focused and use imperative subjects.
- Never commit `.godot/`, local editor state, export output, or credentials.
- Do commit `.blend` source, GLBs, import sidecars when needed, and the generator.
- Do not rewrite shared branch history.
- Keep `main` deployable; GitHub Pages deploys only after CI succeeds.

## Session Handoff

Before ending a work session:

1. Run relevant checks.
2. Update `docs/PROGRESS.md` with date, commit/branch, verified behavior, known
   failures, and the exact next action.
3. Commit coherent work or clearly document why it remains uncommitted.
4. Push the branch when network access and permissions allow.

