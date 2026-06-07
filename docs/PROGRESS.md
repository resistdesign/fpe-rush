# Progress

## Current Milestone

Initial production build is published and deployed from `main`.

## Completed

- Confirmed Godot 4.5 and Blender 4.5 toolchain.
- Audited the official FPE runtime and metadata keys.
- Pinned official FPE `v1.0.11`.
- Defined the 16-demo atomic curriculum.
- Established durable planning, validation, and handoff rules.
- Built the LaunchBox-style Godot gallery shell.
- Authored 16 atomic FPE demos plus one sub-scene in Blender and GLB.
- Added real conversation, inventory, audio, water, trigger, animation, camera,
  physics, holdable, group, UI, and scene metadata examples.
- Added deterministic Blender generation and pinned FPE `v1.0.11`.
- Added Godot static validation, direct FPE runtime loading for every demo, and
  a verified local web export.
- Added GitHub Actions deployment modeled on `resistdesign/entailed`.
- Published the public repository at <https://github.com/resistdesign/fpe-rush>.
- Verified GitHub Actions run `27100959933` completed successfully.
- Enabled GitHub Pages from `gh-pages:/`, approved the custom-domain
  certificate, and enforced HTTPS at <https://rush.foldedpaperengine.com/>.
- Confirmed Blender, GLB, and WAV assets are ordinary Git blobs; Git LFS is not
  used.

## Next Action

Run a browser interaction pass across all 16 demos and open focused issues for
any visual or input polish discovered.

## Known Risks

- Browser interaction remains the final production smoke test.
