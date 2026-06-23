#!/usr/bin/env bash
#
# materialize_yosys_tests.sh — copy the upstream Yosys test sources
# (third_party/yosys/tests/**/*.{v,sv}) into self-contained per-test dirs under
# test/run/<rel>/ so the 4-frontend matrix can read each one like an internal
# test.  Pure file staging — no synthesis, no equivalence (run_frontend_matrix.py
# does that).  Mirrors the staging logic of run_all_tests.sh's setup_yosys_test
# (dut copy + module-stub rewrite + sibling-file pickup) without its
# formal/cosim config, keeping run_all_tests.sh untouched.
#
# Each materialized dir gets:
#   dut.<ext>                 the test source (module `(...)` stubs rewritten)
#   <sibling>.v/.sv           any extra sources a co-located .ys reads with it
#   project.f                 lists dut + siblings (so project_files.sh picks all)
#
# Usage: materialize_yosys_tests.sh [pattern]
#   pattern : optional substring filter on the relative test path
# Prints one materialized dir (relative to test/) per line on stdout.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YOSYS_TESTS_DIR="$PROJECT_ROOT/third_party/yosys/tests"
RUN_DIR="$SCRIPT_DIR/run"
PATTERN="${1:-}"

# Shared DUT/sibling staging — same logic make test-all uses (no private copy).
source "$SCRIPT_DIR/lib_yosys_staging.sh"

mkdir -p "$RUN_DIR"

find "$YOSYS_TESTS_DIR" -type f \( -name '*.v' -o -name '*.sv' \) | sort | while read -r test_file; do
    rel_path="${test_file#$YOSYS_TESTS_DIR/}"
    [ -n "$PATTERN" ] && [[ "$rel_path" != *"$PATTERN"* ]] && continue
    dir_name="$(dirname "$rel_path")"
    test_name="$(basename "$test_file")"; test_name="${test_name%.*}"
    rel="${dir_name}/${test_name}"
    abs_dir="$RUN_DIR/${rel}"
    rm -rf "$abs_dir"; mkdir -p "$abs_dir"

    # Stage DUT + multi-file siblings via the shared helper.
    stage_yosys_sources "$test_file" "$abs_dir"

    # project.f so project_files.sh feeds dut + siblings to every frontend.
    {
        echo "dut.${STAGE_DUT_EXT}"
        for s in $STAGE_SIBLINGS; do echo "$s"; done
    } > "$abs_dir/project.f"

    echo "run/${rel}"
done
