#!/usr/bin/env bash
set -euo pipefail

run_godot_checked() {
  local log_file
  log_file="$(mktemp)"
  if ! godot "$@" 2>&1 | tee "${log_file}"; then
    rm -f "${log_file}"
    return 1
  fi
  if grep -E 'SCRIPT ERROR:|^ERROR:' "${log_file}" \
    | grep -v 'Pages in use exist at exit in PagedAllocator' \
    | grep -v "RID allocations of type .* were leaked at exit" \
    | grep -v 'resources still in use at exit' \
    | grep -q .; then
    rm -f "${log_file}"
    return 1
  fi
  rm -f "${log_file}"
}

run_godot_checked --headless --import --quit
run_godot_checked --headless --script scripts/validate_project.gd

if [[ "${SKIP_WEB_EXPORT:-0}" != "1" ]]; then
  rm -rf build/web
  mkdir -p build/web
  touch build/.gdignore
  run_godot_checked --headless --export-release Web build/web/index.html
  touch build/web/.nojekyll
  printf '%s\n' 'rush.foldedpaperengine.com' > build/web/CNAME
fi
