# lib_yosys_staging.sh — shared staging for upstream Yosys tests.
#
# Single source of truth for turning a third_party/yosys/tests/**/*.{v,sv}
# source into a self-contained per-test dir, used by BOTH:
#   * run_all_tests.sh   (setup_yosys_test)  — the `make test-all` harness
#   * materialize_yosys_tests.sh              — the 4-frontend matrix staging
# so the two never drift (they used to keep private copies of this logic).
#
# `source` this file, then call:
#   stage_yosys_sources <test_file> <abs_dir>
# It copies the DUT (+ any sibling sources its .ys reads) into <abs_dir>,
# preprocesses them, and sets:
#   STAGE_DUT_EXT    sv | v
#   STAGE_SIBLINGS   space-separated sibling filenames (excludes the DUT)
#   STAGE_LIB_READS  the `read_verilog -lib ...` lines from the .ys (verbatim)

# Rewrite empty `module foo(...)` stubs and trailing-comma port lists that some
# yosys tests use.
preprocess_test_file() {
    local file="$1"
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\.\.\s*)/module \1()/g' "$file"
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\s*\.\s*\.\s*)/module \1()/g' "$file"
    sed -i 's/,[ \t]*)/)/g' "$file"
    sed -i ':a;N;$!ba;s/,\n[ \t]*)/\n  )/g' "$file"
}

stage_yosys_sources() {
    local test_file="$1" abs_dir="$2"
    local test_base; test_base="$(basename "$test_file")"
    local src_dir; src_dir="$(dirname "$test_file")"

    local src_ext="${test_file##*.}"
    STAGE_DUT_EXT="sv"; [ "$src_ext" = "v" ] && STAGE_DUT_EXT="v"
    cp "$test_file" "$abs_dir/dut.${STAGE_DUT_EXT}"
    preprocess_test_file "$abs_dir/dut.${STAGE_DUT_EXT}"

    STAGE_SIBLINGS=""
    STAGE_LIB_READS=""

    # A co-located .ys may build a MULTI-FILE design that includes this test
    # file — either all on one `read_verilog` line (sat/grom.ys:
    #   `read_verilog grom_computer.v grom_cpu.v alu.v ram_memory.v`)
    # OR across several lines (verilog/package_import_separate.ys:
    #   `read_verilog -sv package_import_separate.sv`
    #   `read_verilog -sv package_import_separate_module.sv`).
    # Pick the first .ys whose non-lib read_verilog reads our file, then copy
    # EVERY other source listed across ALL its non-lib read_verilog lines, and
    # capture its -lib library reads.  Without this the cross-file submodules /
    # packages stay undefined and synth fails for every frontend.
    local ys line tok
    for ys in "$src_dir"/*.ys; do
        [ -f "$ys" ] || continue
        grep -E 'read_verilog' "$ys" | grep -vE '\-lib' | grep -qwF "$test_base" || continue
        while IFS= read -r line; do
            for tok in $line; do
                tok="${tok%;}"
                case "$tok" in
                    *.v|*.sv|*.vh|*.svh)
                        [ "$tok" = "$test_base" ] && continue
                        [ -f "$src_dir/$tok" ] || continue
                        cp "$src_dir/$tok" "$abs_dir/$tok"
                        preprocess_test_file "$abs_dir/$tok"
                        case " $STAGE_SIBLINGS " in
                            *" $tok "*) ;;                       # dedupe
                            *) STAGE_SIBLINGS="$STAGE_SIBLINGS $tok" ;;
                        esac
                        ;;
                esac
            done
        done < <(grep -E 'read_verilog' "$ys" | grep -vE '\-lib')
        STAGE_LIB_READS="$(grep -E '^[[:space:]]*read_verilog[[:space:]]+-lib' "$ys" || true)"
        break
    done
}
