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

# Rewrite empty `module foo(...)` stubs and trailing-comma port lists that some
# yosys tests use (identical to run_all_tests.sh:preprocess_test_file).
preprocess_test_file() {
    local file="$1"
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\.\.\s*)/module \1()/g' "$file"
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\s*\.\s*\.\s*)/module \1()/g' "$file"
    sed -i 's/,[ \t]*)/)/g' "$file"
    sed -i ':a;N;$!ba;s/,\n[ \t]*)/\n  )/g' "$file"
}

mkdir -p "$RUN_DIR"

find "$YOSYS_TESTS_DIR" -type f \( -name '*.v' -o -name '*.sv' \) | sort | while read -r test_file; do
    rel_path="${test_file#$YOSYS_TESTS_DIR/}"
    [ -n "$PATTERN" ] && [[ "$rel_path" != *"$PATTERN"* ]] && continue
    dir_name="$(dirname "$rel_path")"
    test_name="$(basename "$test_file")"; test_name="${test_name%.*}"
    rel="${dir_name}/${test_name}"
    abs_dir="$RUN_DIR/${rel}"
    rm -rf "$abs_dir"; mkdir -p "$abs_dir"

    src_ext="${test_file##*.}"; dut_ext="sv"; [ "$src_ext" = "v" ] && dut_ext="v"
    cp "$test_file" "$abs_dir/dut.${dut_ext}"
    preprocess_test_file "$abs_dir/dut.${dut_ext}"

    # Multi-file design: a co-located .ys may read this file together with
    # others; copy those siblings so the design elaborates for every frontend.
    test_base="$(basename "$test_file")"
    src_dir="$(dirname "$test_file")"
    siblings=""
    for ys in "$src_dir"/*.ys; do
        [ -f "$ys" ] || continue
        line="$(grep -E 'read_verilog' "$ys" | grep -vE '\-lib' | grep -wF "$test_base" | head -1 || true)"
        [ -n "$line" ] || continue
        for tok in $line; do
            tok="${tok%;}"
            case "$tok" in
                *.v|*.sv|*.vh|*.svh)
                    [ "$tok" = "$test_base" ] && continue
                    if [ -f "$src_dir/$tok" ]; then
                        cp "$src_dir/$tok" "$abs_dir/$tok"
                        preprocess_test_file "$abs_dir/$tok"
                        siblings="$siblings $tok"
                    fi ;;
            esac
        done
        [ -n "$siblings" ] && break
    done

    # project.f so project_files.sh feeds dut + siblings to every frontend.
    {
        echo "dut.${dut_ext}"
        for s in $siblings; do echo "$s"; done
    } > "$abs_dir/project.f"

    echo "run/${rel}"
done
