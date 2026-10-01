#!/usr/bin/env bash
# Runs every offline test against the addon in the repository root.
# Usage: bash tests/run_all.sh   (needs lua 5.1+ and luac on PATH)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="${ROOT}/tests"
LUAC="${LUAC:-luac}"
FAILED=0

run() {
  local name="$1"
  shift
  if "$@" >/tmp/ibt_test_out.txt 2>&1; then
    echo "PASS  ${name}"
  else
    echo "FAIL  ${name}"
    cat /tmp/ibt_test_out.txt
    FAILED=1
  fi
}

for file in Locale.lua Log.lua Model.lua Core.lua; do
  run "syntax ${file}" "${LUAC}" -p "${ROOT}/${file}"
done
run "tooltip parser" lua "${T}/test_parse.lua" "${ROOT}"
run "model" lua "${T}/test_model.lua" "${ROOT}"
run "live erupt reader" lua "${T}/test_live.lua" "${ROOT}" "${T}/frame_stub.lua"
run "locale tables" lua "${T}/test_locale.lua" "${ROOT}"
run "locale keys used" lua "${T}/test_locale_keys.lua" "${ROOT}/Locale.lua" "${ROOT}/Core.lua"
run "layout widths" lua "${T}/test_layout.lua" "${ROOT}"
run "full simulation (readable)" lua "${T}/sim_full.lua" "${ROOT}" plain
run "full simulation (M+ secrets)" lua "${T}/sim_full.lua" "${ROOT}" secret
run "error firewall" lua "${T}/sim_faults.lua" "${ROOT}" plain

if [ "${FAILED}" -ne 0 ]; then
  echo "Some tests failed."
  exit 1
fi
echo "All tests passed."
