#!/usr/bin/env bash
set -euo pipefail

BLENDER_BIN="${BLENDER_BIN:-blender}"

"${BLENDER_BIN}" --background --python tools/blender/build_demo_collection.py

