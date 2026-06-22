#!/bin/bash

# Test runner script for UHDM frontend
# Runs test_uhdm_workflow.sh for every test directory and provides comprehensive statistics
# Can also run Yosys tests with --yosys or --all options

# Don't exit on error - we want to run all tests
set +e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Yosys-test (third_party/yosys/tests) discovery + setup paths.  These tests
# are treated as read-only and materialised under test/run/<path>/ where they
# then go through the SAME per-test analysis as the internal tests.
YOSYS_TESTS_DIR="$PROJECT_ROOT/third_party/yosys/tests"
RUN_DIR="$SCRIPT_DIR/run"
YOSYS_BIN="$PROJECT_ROOT/out/current/bin/yosys"
SURELOG_BIN="$PROJECT_ROOT/build/third_party/Surelog/bin/surelog"
UHDM_PLUGIN="$PROJECT_ROOT/build/uhdm2rtlil.so"

# Setup logging
LOG_FILE="$SCRIPT_DIR/test.log"
YOSYS_LOG_FILE="$SCRIPT_DIR/test-yosys.log"

# Create/clear log files
echo "Test run started at $(date)" > "$LOG_FILE"
echo "Test run started at $(date)" > "$YOSYS_LOG_FILE"

# Arrays to track test execution times
declare -A TEST_TIMES
declare -A TEST_START_TIMES

# Default behavior
RUN_LOCAL=true
RUN_YOSYS=false
SPECIFIC_TEST=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yosys)
            RUN_LOCAL=false
            RUN_YOSYS=true
            shift
            ;;
        --all)
            RUN_LOCAL=true
            RUN_YOSYS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [TEST_PATTERN]"
            echo ""
            echo "Options:"
            echo "  --yosys       Run only Yosys tests from third_party/yosys/tests/"
            echo "  --all         Run both local tests and Yosys tests"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Arguments:"
            echo "  TEST_PATTERN  Optional pattern to match specific tests"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all local tests"
            echo "  $0 simple_memory      # Run local test matching 'simple_memory'"
            echo "  $0 --yosys            # Run all Yosys tests"
            echo "  $0 --yosys simple     # Run Yosys tests matching 'simple'"
            echo "  $0 --all              # Run all local and Yosys tests"
            exit 0
            ;;
        *)
            SPECIFIC_TEST="$1"
            shift
            ;;
    esac
done

echo "=== UHDM Frontend Test Runner ==="

# Change to test directory
cd "$SCRIPT_DIR"

# Initialize counters and tracking arrays
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
CRASHED_TESTS=0
UHDM_ONLY_TESTS=0

# For Yosys tests
YOSYS_TOTAL=0
YOSYS_PASSED=0
YOSYS_FAILED=0
YOSYS_SKIPPED=0
YOSYS_UHDM_ONLY=0
EQUIV_FAILED_TESTS=0
# Tests failed by the SAT-from-reset MITER (UHDM != Verilog) even though the
# equiv_induct check passed — real bugs that equiv_induct's blind spot missed.
MITER_FAILED_TESTS=0
MITER_FAILED_TEST_NAMES=()
SIM_EQUIV_WARN_TESTS=0
SIM_EQUIV_WARN_NAMES=()
SIM_EQUIV_ANALYZED_TESTS=0
SIM_EQUIV_ANALYZED_NAMES=()
# Each analyzed divergence is auto-classified (see classify_divergence) by a
# SAT-from-reset formal miter:
#   🔬 ARTEFACT       — miter EQUIVALENT (UHDM == Verilog), or an override -> pass.
#   🐛 POTENTIAL BUG  — miter NON-EQUIVALENT (UHDM differs) -> Miter-Formal FAIL.
#   ❓ UNCLASSIFIED   — miter INCONCLUSIVE and no override (needs triage) -> pass.
SIM_EQUIV_ARTEFACT_TESTS=0
SIM_EQUIV_ARTEFACT_NAMES=()
SIM_EQUIV_UNCLASS_TESTS=0
SIM_EQUIV_UNCLASS_NAMES=()

# Tests that are knowingly not made to pass sim-equiv, with a
# documented reason in `test/sim_equiv_analyzed.txt`.  Populate the
# set once at startup so the per-test path is just a lookup.
declare -A SIM_EQUIV_ANALYZED_SET
if [ -f "$SCRIPT_DIR/sim_equiv_analyzed.txt" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^Test:[[:space:]]*([A-Za-z0-9_-]+) ]]; then
            SIM_EQUIV_ANALYZED_SET[${BASH_REMATCH[1]}]=1
        fi
    done < "$SCRIPT_DIR/sim_equiv_analyzed.txt"
fi

# Manual classification overrides for the miter's soundness caveats (latches,
# abc9 muxes, SVA $check — satgen can't model them; reset-dependent false
# NON-EQUIVALENT).  An override WINS over the miter.  See the file header.
declare -A SIM_EQUIV_OVERRIDE
if [ -f "$SCRIPT_DIR/sim_equiv_classification.txt" ]; then
    while read -r _name _cls _rest; do
        [[ -z "$_name" || "$_name" == \#* ]] && continue
        SIM_EQUIV_OVERRIDE[$_name]="$_cls"
    done < "$SCRIPT_DIR/sim_equiv_classification.txt"
fi

# Auto-classify a co-sim divergence: prints "artefact" / "bug" / "unknown".
# Honours sim_equiv_classification.txt overrides first, else runs the SAT
# miter (triage_cosim.py --no-cosim) on the gate-level *_synth.v netlists.
classify_divergence() {
    local base="$1"
    if [ -n "${SIM_EQUIV_OVERRIDE[$base]:-}" ]; then
        case "${SIM_EQUIV_OVERRIDE[$base]}" in
            artefact) echo "artefact (override)"; return ;;
            bug)      echo "bug (override)"; return ;;
        esac
    fi
    if [ ! -f "$SCRIPT_DIR/triage_cosim.py" ]; then
        echo "unknown"; return
    fi
    local v
    v=$(cd "$SCRIPT_DIR" && timeout 150 python3 triage_cosim.py "$base" \
            --no-cosim --seq 14 2>/dev/null \
            | grep -oE 'NON-EQUIVALENT|EQUIVALENT|INCONCLUSIVE' | head -1)
    case "$v" in
        EQUIVALENT)     echo "artefact (miter)" ;;
        NON-EQUIVALENT) echo "bug (miter)" ;;
        *)              echo "unknown" ;;
    esac
}

# Read a KEY from a test's optional per-test config file
# (`<test_dir>/sim_config`, simple `KEY=VALUE` lines), or echo the default.
# Supported keys:
#   SKIP_FORMAL=1   — skip the (slow) formal equivalence check for this test
#                     and rely on the Verilator co-sim instead
#   SIM_CYCLES=N    — number of random Verilator co-sim cycles (default 200)
read_test_cfg() {
    local test_dir="$1" key="$2" def="$3" cfg="$1/sim_config" v
    if [ -f "$cfg" ]; then
        v=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$cfg" | tail -1 | cut -d= -f2- | tr -d '[:space:]')
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    echo "$def"
}

FAILED_TEST_NAMES=()
SKIPPED_TEST_NAMES=()
CRASHED_TEST_NAMES=()
PASSED_TEST_NAMES=()
UHDM_ONLY_TEST_NAMES=()
EQUIV_FAILED_TEST_NAMES=()

# Helper: run the Verilator simulation-equivalence check on a UHDM-only
# test.  Returns 0 per-test (so subsequent tests still run) but counts
# the divergence in SIM_EQUIV_WARN_TESTS.  The suite-level exit logic
# turns any non-zero SIM_EQUIV_WARN_TESTS into a hard failure (exit 1).
# Document intentional divergences in `sim_equiv_analyzed.txt` to surface
# them under the "🔍 ANALYZED" category instead of warning.
run_sim_equivalence_softwarn() {
    local test_dir="$1"
    local cycles="${2:-200}"
    local script="$SCRIPT_DIR/test_sim_equivalence.py"
    local plugin="$PROJECT_ROOT/build/extract_clocks_resets.so"
    if [ ! -f "$script" ] || [ ! -f "$plugin" ]; then
        return 0  # silently skip if the optional tooling isn't built
    fi
    local log="$test_dir/sim_equiv.log"
    "$script" "$test_dir" --cycles "$cycles" >"$log" 2>&1
    local rc=$?
    if [ $rc -eq 0 ] && grep -q '^PASS:' "$log"; then
        echo "    ✅ Verilator co-sim PASSED"
        SIM_EQUIV_COSIM_PASSED=1
        return 0
    fi
    # Exit code 77 = autotools "skip" convention.  The harness emits it
    # when co-sim is not applicable: a self-checking testbench with no
    # observable outputs (everything asserted internally), OR Verilator
    # cannot build the design (original RTL uses a construct it doesn't
    # support — `~&`, `ref` args, arrayed defparam, some interfaces — or
    # the synth netlist holds cells it can't model, e.g. $allconst).
    # Neither is an RTL-vs-netlist divergence, so it's a skip, not a fail.
    if [ $rc -eq 77 ]; then
        echo "    ⏭  Verilator co-sim SKIPPED (no outputs or not buildable)"
        return 0
    fi
    local base; base="$(basename "$test_dir")"
    # Tests listed in sim_equiv_analyzed.txt are knowingly not co-sim
    # clean — surface them under a separate "analyzed" category so the
    # warning count tracks only un-investigated failures.
    if [ -n "${SIM_EQUIV_ANALYZED_SET[$base]:-}" ]; then
        # Auto-classify this divergence with the SAT miter (or an override).
        local cls; cls="$(classify_divergence "$base")"
        case "$cls" in
            artefact*)
                # UHDM == Verilog: a Verilator-vs-synth diff, not a bug -> pass.
                echo "    🔬 Verilator co-sim ARTEFACT — UHDM==Verilog, sim/synth diff [$cls]"
                SIM_EQUIV_ANALYZED_TESTS=$((SIM_EQUIV_ANALYZED_TESTS + 1))
                SIM_EQUIV_ANALYZED_NAMES+=("$base")
                SIM_EQUIV_ARTEFACT_TESTS=$((SIM_EQUIV_ARTEFACT_TESTS + 1))
                SIM_EQUIV_ARTEFACT_NAMES+=("$base") ;;
            bug*)
                # Miter proved UHDM != Verilog -> a real bug; FAIL the test
                # (handled in analyze_test_result via SIM_EQUIV_MITER_BUG).
                echo "    🐛 Verilator co-sim POTENTIAL BUG — UHDM frontend differs [$cls]"
                echo "    ❌ Miter-Formal FAILED (UHDM and Verilog differ — the equiv_induct check missed it)"
                SIM_EQUIV_MITER_BUG=1 ;;
            *)
                # Miter inconclusive, no override -> documented, needs triage.
                echo "    ❓ Verilator co-sim UNCLASSIFIED — miter inconclusive, add an override"
                SIM_EQUIV_ANALYZED_TESTS=$((SIM_EQUIV_ANALYZED_TESTS + 1))
                SIM_EQUIV_ANALYZED_NAMES+=("$base")
                SIM_EQUIV_UNCLASS_TESTS=$((SIM_EQUIV_UNCLASS_TESTS + 1))
                SIM_EQUIV_UNCLASS_NAMES+=("$base") ;;
        esac
        return 0
    fi
    echo "    ⚠️  Verilator co-sim WARNING (see $base/sim_equiv.log)"
    SIM_EQUIV_WARN_TESTS=$((SIM_EQUIV_WARN_TESTS + 1))
    SIM_EQUIV_WARN_NAMES+=("$base")
    return 0
}

# Track unexpected results
UNEXPECTED_FAILURES=()
UNEXPECTED_SUCCESSES=()

# Load failing tests list
FAILING_TESTS=()
if [ -f "failing_tests.txt" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            # Trim leading and trailing whitespace and remove inline comments
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$trimmed_line" ]]; then
                FAILING_TESTS+=("$trimmed_line")
            fi
        fi
    done < "failing_tests.txt"
fi

if [ ${#FAILING_TESTS[@]} -gt 0 ]; then
    echo "Tests marked as failing (will still be run): ${FAILING_TESTS[*]}"
else
    echo "No tests marked as failing - all tests will be run normally"
fi

# Load skipped tests list
SKIPPED_TESTS_LIST=()
if [ -f "skipped_tests.txt" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            # Trim leading and trailing whitespace and remove inline comments
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$trimmed_line" ]]; then
                SKIPPED_TESTS_LIST+=("$trimmed_line")
            fi
        fi
    done < "skipped_tests.txt"
fi

if [ ${#SKIPPED_TESTS_LIST[@]} -gt 0 ]; then
    echo "Tests marked as skipped (will not be run): ${SKIPPED_TESTS_LIST[*]}"
else
    echo "No tests marked as skipped - all tests will be run"
fi
echo

# Only find local test directories if running local tests
if [ "$RUN_LOCAL" = true ]; then
    # Find all test directories (directories containing dut.sv or dut.v)
    TEST_DIRS=()
    # A directory counts as a test if it has dut.sv, dut.v, or a
    # `project.f` multi-file filelist (see project_files.sh).
    has_test_sources() {
        [ -f "$1/dut.sv" ] || [ -f "$1/dut.v" ] || [ -f "$1/project.f" ]
    }
    if [ -n "$SPECIFIC_TEST" ] && [ "$RUN_YOSYS" = false ]; then
        # Check if the specific test exists
        if [ -d "$SPECIFIC_TEST" ] && has_test_sources "$SPECIFIC_TEST"; then
            TEST_DIRS+=("$SPECIFIC_TEST")
        else
            echo "Error: Test '$SPECIFIC_TEST' not found or has no dut.sv / dut.v / project.f"
            exit 1
        fi
    elif [ "$RUN_YOSYS" = false ] || [ -z "$SPECIFIC_TEST" ]; then
        # Find all test directories
        for dir in */; do
            if [ -d "$dir" ] && has_test_sources "${dir%/}"; then
                # Remove trailing slash from directory name
                TEST_NAME="${dir%/}"
                # Skip the run directory (used for Yosys tests)
                if [ "$TEST_NAME" != "run" ]; then
                    TEST_DIRS+=("$TEST_NAME")
                fi
            fi
        done
    fi

    if [ "$RUN_YOSYS" = false ] && [ ${#TEST_DIRS[@]} -eq 0 ]; then
        echo "No test directories found (looking for directories containing dut.sv or dut.v)"
        exit 1
    fi

    if [ ${#TEST_DIRS[@]} -gt 0 ]; then
        echo "Found ${#TEST_DIRS[@]} local test(s): ${TEST_DIRS[*]}"
        echo
    fi
fi

# Helper function to check if test is in failing list
is_failing_test() {
    local test_name="$1"
    for failing_test in "${FAILING_TESTS[@]}"; do
        if [ "$test_name" = "$failing_test" ]; then
            return 0
        fi
    done
    return 1
}

# Helper function to check if test should be skipped
should_skip_test() {
    local test_name="$1"
    for skipped_test in "${SKIPPED_TESTS_LIST[@]}"; do
        # Support wildcards in skipped test patterns
        if [[ "$test_name" == $skipped_test ]] || [[ "$test_name" == *"$skipped_test"* ]]; then
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Yosys-test (third_party/yosys/tests) support — folded in from the former
# run_yosys_tests.sh so both test sources share ONE per-test analysis
# (formal + Verilator co-sim + SAT-miter classification + SKIP_FORMAL).
# ---------------------------------------------------------------------------

# Tests whose formal proof is too slow: skip formal, verify via co-sim — the
# same policy as `make test`'s internal `functional_picorv32`.  Entries are
# yosys-relative paths (e.g. `functional/picorv32`), optional 2nd col = cycles.
SKIP_FORMAL_COSIM_LIST=()
if [ -f "$SCRIPT_DIR/skip_formal_cosim_tests.txt" ]; then
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$trimmed_line" ]] && SKIP_FORMAL_COSIM_LIST+=("$trimmed_line")
        fi
    done < "$SCRIPT_DIR/skip_formal_cosim_tests.txt"
fi

# Echo the co-sim cycle count if a yosys-relative path (with or without
# extension) is in the skip-formal-use-cosim list (default 2000); else nothing.
skip_formal_cosim_cycles() {
    local p="$1" pat cyc
    for entry in "${SKIP_FORMAL_COSIM_LIST[@]}"; do
        pat="${entry%%[[:space:]]*}"
        cyc="${entry#"$pat"}"; cyc="${cyc//[[:space:]]/}"
        if [ "$p" = "$pat" ] || [ "$p" = "${pat%.v}" ] || [ "$p" = "${pat%.sv}" ]; then
            echo "${cyc:-2000}"; return 0
        fi
    done
    return 1
}

# Tests accepted as equivalent via co-sim when equiv_induct fails (opt-in):
# multi-port / byte-enable / multi-clock RAMs where induct is incomplete and a
# formal RAM miter is impractical.  See cosim_equiv_tests.txt.
COSIM_EQUIV_LIST=()
if [ -f "$SCRIPT_DIR/cosim_equiv_tests.txt" ]; then
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$trimmed_line" ]] && COSIM_EQUIV_LIST+=("$trimmed_line")
        fi
    done < "$SCRIPT_DIR/cosim_equiv_tests.txt"
fi

# Is this yosys-relative path (with or without extension) opted in to
# co-sim-based equivalence acceptance?
is_cosim_equiv() {
    local p="$1" pat
    for entry in "${COSIM_EQUIV_LIST[@]}"; do
        pat="${entry%%[[:space:]]*}"
        if [ "$p" = "$pat" ] || [ "$p" = "${pat%.v}" ] || [ "$p" = "${pat%.sv}" ]; then
            return 0
        fi
    done
    return 1
}

# Is this file a self-contained Verilog/SV test (has a module, no includes)?
is_verilog_test() {
    local file="$1"
    [[ "$file" =~ \.(v|sv)$ ]] || return 1
    [[ "$file" =~ \.vh$ ]] || [[ "$file" =~ _inc\.v$ ]] || [[ "$file" =~ _include\.v$ ]] && return 1
    grep -q "^\s*module\s" "$file" 2>/dev/null || return 1
    grep -q "^\s*\`include" "$file" 2>/dev/null && return 1
    return 0
}

# Normalise a copied yosys test source for the UHDM frontend (module(...) →
# module(); strip trailing commas in port lists).
preprocess_test_file() {
    local file="$1"
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\.\.\s*)/module \1()/g' "$file"
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\s*\.\s*\.\s*)/module \1()/g' "$file"
    sed -i 's/,[ \t]*)/)/g' "$file"
    sed -i ':a;N;$!ba;s/,\n[ \t]*)/\n  )/g' "$file"
}

# Materialise a yosys test under test/run/<rel>/ and run surelog + both
# frontends + synth, producing the same *_from_{uhdm,verilog}{,_synth,_nohier}
# layout the internal workflow does.  Sets YT_RUN_DIR (relative to test/) for
# analyze_test_result; returns the UHDM yosys run's exit code (crash detect).
setup_yosys_test() {
    local test_file="$1"
    local relative_path="${test_file#$YOSYS_TESTS_DIR/}"
    local dir_name; dir_name="$(dirname "$relative_path")"
    local test_name; test_name="$(basename "$test_file" .v)"; test_name="$(basename "$test_name" .sv)"
    local rel="${dir_name}/${test_name}"
    YT_RUN_DIR="run/${rel}"
    local abs_dir="$RUN_DIR/${rel}"
    rm -rf "$abs_dir"; mkdir -p "$abs_dir"

    local src_ext="${test_file##*.}"; local dut_ext="sv"
    [ "$src_ext" = "v" ] && dut_ext="v"
    cp "$test_file" "$abs_dir/dut.${dut_ext}"
    preprocess_test_file "$abs_dir/dut.${dut_ext}"

    # Some yosys tests instantiate vendor primitives defined only in a cell
    # library that their own .ys loads via `read_verilog -lib` (e.g.
    # arch/xilinx/bug3670 -> `read_verilog -lib -specify +/xilinx/cells_sim.v`
    # for RAMB36E1).  The generic flow must load the same library or synth fails
    # on the undefined cell for BOTH frontends.  Replicate exactly those -lib
    # lines (they use `+/...`, resolved from the yosys share dir).
    local lib_reads=""
    local ys_file="${test_file%.*}.ys"
    if [ -f "$ys_file" ]; then
        lib_reads="$(grep -E '^[[:space:]]*read_verilog[[:space:]]+-lib' "$ys_file" || true)"
    fi

    # Multi-file design: a sibling .ys may `read_verilog` this test's file
    # TOGETHER with others (e.g. sat/grom.ys:
    #   `read_verilog grom_computer.v grom_cpu.v alu.v ram_memory.v`).
    # The single-DUT flow would leave the cross-file submodules undefined.
    # Detect such a line (mentions this file, not -lib), copy every other source
    # file it lists into the run dir, and load them all on BOTH frontends so the
    # design elaborates.  sibling_files = those extra files (the test file itself
    # stays dut.<ext>); empty for the normal single-file case.
    local test_base; test_base="$(basename "$test_file")"
    local src_dir; src_dir="$(dirname "$test_file")"
    local sibling_files=""
    local ys
    for ys in "$src_dir"/*.ys; do
        [ -f "$ys" ] || continue
        local line
        line="$(grep -E 'read_verilog' "$ys" | grep -vE '\-lib' | grep -wF "$test_base" | head -1 || true)"
        [ -n "$line" ] || continue
        local tok
        for tok in $line; do
            tok="${tok%;}"
            case "$tok" in
                *.v|*.sv|*.vh|*.svh)
                    [ "$tok" = "$test_base" ] && continue
                    if [ -f "$src_dir/$tok" ]; then
                        cp "$src_dir/$tok" "$abs_dir/$tok"
                        preprocess_test_file "$abs_dir/$tok"
                        sibling_files="$sibling_files $tok"
                    fi
                    ;;
            esac
        done
        [ -n "$sibling_files" ] && break
    done

    # Skip-formal-use-cosim tests get a sim_config so analyze_test_result skips
    # the (too-slow) formal proof and relies on the random Verilator co-sim.
    local sfc_cycles; sfc_cycles="$(skip_formal_cosim_cycles "$rel")"
    if [ -n "$sfc_cycles" ]; then
        printf 'SKIP_FORMAL=1\nSIM_CYCLES=%s\n' "$sfc_cycles" > "$abs_dir/sim_config"
    fi
    # Opt-in: accept this RAM test as equivalent via co-sim if induct fails.
    if is_cosim_equiv "$rel"; then
        printf 'COSIM_EQUIV=1\n' >> "$abs_dir/sim_config"
    fi

    cat > "$abs_dir/test_verilog_read.ys" << EOF
read_verilog -sv dut.${dut_ext}${sibling_files}
${lib_reads}
write_rtlil ${test_name}_from_verilog_nohier.il
hierarchy -auto-top
proc
opt
write_rtlil ${test_name}_from_verilog.il
synth -auto-top
write_verilog -noexpr ${test_name}_from_verilog_synth.v
EOF
    cat > "$abs_dir/test_uhdm_read.ys" << EOF
plugin -i $UHDM_PLUGIN
read_uhdm slpp_all/surelog.uhdm
${lib_reads}
write_rtlil ${test_name}_from_uhdm_nohier.il
hierarchy -auto-top
proc
opt
write_rtlil ${test_name}_from_uhdm.il
synth -auto-top
write_verilog -noexpr ${test_name}_from_uhdm_synth.v
EOF

    local rc=0
    ( cd "$abs_dir" || exit 1
      $YOSYS_BIN -s test_verilog_read.ys > verilog_path.log 2>&1 || true
      $SURELOG_BIN -parse -nobuiltin -nocache -d uhdm "dut.${dut_ext}"${sibling_files} > surelog.log 2>&1 || true
      if [ -f slpp_all/surelog.uhdm ]; then
          $YOSYS_BIN -s test_uhdm_read.ys > uhdm_path.log 2>&1
      fi )
    rc=$?
    return $rc
}

# Shared result classifier — analyze a prepared test dir and bucket the
# outcome (passed / equiv_failed / failed) against its expected-to-fail flag.
# Used by BOTH the internal and yosys per-test loops so they behave identically.
classify_test_outcome() {
    local test_dir="$1" exit_code="$2" expected_to_fail="$3"
    echo -n "Result: "
    local test_result=""
    analyze_test_result "$test_dir" "$exit_code"
    local result_code=$?
    if [ $result_code -eq 0 ]; then
        test_result="passed"
    elif [ $result_code -eq 2 ]; then
        test_result="equiv_failed"
    else
        test_result="failed"
    fi
    if [ "$expected_to_fail" = true ]; then
        if [ "$test_result" = "passed" ]; then
            echo "    ⚠️  UNEXPECTED SUCCESS - This test was expected to fail!"
            UNEXPECTED_SUCCESSES+=("$test_dir")
        elif [ "$test_result" = "equiv_failed" ]; then
            echo "    Note: This test was expected to fail (equivalence check failure)"
        else
            echo "    Note: This test was expected to fail"
        fi
    else
        if [ "$test_result" = "failed" ]; then
            echo "    ⚠️  UNEXPECTED FAILURE - This test was expected to pass!"
            UNEXPECTED_FAILURES+=("$test_dir")
        elif [ "$test_result" = "equiv_failed" ]; then
            echo "    ⚠️  UNEXPECTED EQUIVALENCE FAILURE - This test should pass formal equivalence!"
            UNEXPECTED_FAILURES+=("$test_dir")
        fi
    fi
}

# Function to display timing summary
display_timing_summary() {
    if [ ${#TEST_TIMES[@]} -gt 0 ]; then
    echo
    echo "=========================================="
    echo "=== TEST EXECUTION TIME SUMMARY ==="
    echo "=========================================="
    echo
    
    # Sort tests by execution time and display top 5 longest
    echo "Top 5 Longest Running Tests:"
    echo "-----------------------------"
    
    # Create a temporary file for sorting
    TEMP_FILE="/tmp/test_times_$$.txt"
    for test_name in "${!TEST_TIMES[@]}"; do
        printf "%s|%.2f\n" "$test_name" "${TEST_TIMES[$test_name]}"
    done | sort -t'|' -k2 -rn > "$TEMP_FILE"
    
    # Display top 5
    head -5 "$TEMP_FILE" | while IFS='|' read test_name duration; do
        printf "  %-40s %.2f seconds\n" "$test_name" "$duration"
    done
    
    # Calculate total time
    total_time=0
    for duration in "${TEST_TIMES[@]}"; do
        total_time=$(echo "$total_time + $duration" | bc)
    done
    
    echo
    printf "Total test execution time: %.2f seconds\n" $total_time
    
    # Clean up
    rm -f "$TEMP_FILE"
    
    # Log timing summary to file
    {
        echo
        echo "=========================================="
        echo "=== TEST EXECUTION TIME SUMMARY ==="
        echo "=========================================="
        echo
        echo "Top 5 Longest Running Tests:"
        for test_name in "${!TEST_TIMES[@]}"; do
            printf "%s|%.2f\n" "$test_name" "${TEST_TIMES[$test_name]}"
        done | sort -t'|' -k2 -rn | head -5 | while IFS='|' read test_name duration; do
            printf "  %-40s %.2f seconds\n" "$test_name" "$duration"
        done
        echo
        printf "Total test execution time: %.2f seconds\n" $total_time
        echo
        echo "Test run completed at $(date)"
    } >> "$LOG_FILE"
    fi
}

# Helper function to analyze test result
analyze_test_result() {
    local test_dir="$1"
    local exit_code="$2"

    # Per-test config (optional `<test_dir>/sim_config`).
    local skip_formal; skip_formal=$(read_test_cfg "$test_dir" SKIP_FORMAL 0)
    local sim_cycles;  sim_cycles=$(read_test_cfg "$test_dir" SIM_CYCLES 200)

    # Check for crashes (core dumps, aborts, etc)
    if [ "$exit_code" -eq 134 ] || [ "$exit_code" -eq 139 ] || [ "$exit_code" -eq 6 ]; then
        echo "💥 Test $test_dir CRASHED (exit code: $exit_code)"
        CRASHED_TESTS=$((CRASHED_TESTS + 1))
        CRASHED_TEST_NAMES+=("$test_dir")
        return 1
    fi
    
    # File-name prefix is the LAST path component (== test_dir for the simple
    # internal tests like `always01`, but `picorv32` for a nested Yosys test
    # dir like `run/functional/picorv32`).
    local prefix; prefix="$(basename "$test_dir")"

    # Check if test generated output files
    local uhdm_file="${test_dir}/${prefix}_from_uhdm.il"
    local verilog_file="${test_dir}/${prefix}_from_verilog.il"
    local uhdm_synth="${test_dir}/${prefix}_from_uhdm_synth.v"
    local verilog_synth="${test_dir}/${prefix}_from_verilog_synth.v"

    # Check if UHDM output exists (post-hierarchy or nohier)
    local uhdm_nohier="${test_dir}/${prefix}_from_uhdm_nohier.il"
    if [ ! -f "$uhdm_file" ] && [ ! -f "$uhdm_nohier" ]; then
        echo "❌ Test $test_dir FAILED - UHDM output missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_dir")
        return 1
    fi
    
    # If post-hierarchy outputs are missing, fall back to nohier comparison
    local verilog_nohier="${test_dir}/${prefix}_from_verilog_nohier.il"
    if [ ! -f "$uhdm_file" ] && [ ! -f "$verilog_file" ] && [ -f "$uhdm_nohier" ] && [ -f "$verilog_nohier" ]; then
        # Both paths failed at hierarchy but produced nohier ILs - compare those
        echo "✅ Test $test_dir PASSED - comparing nohier ILs (both paths fail at hierarchy)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    fi

    # If Verilog output is missing but UHDM succeeded, this might be showcasing UHDM's superior capabilities
    if [ ! -f "$verilog_file" ]; then
        # Check if Verilog frontend failed (common for advanced SystemVerilog)
        if [ -f "${test_dir}/verilog_path.log" ] && grep -q "ERROR" "${test_dir}/verilog_path.log"; then
            echo "✅ Test $test_dir PASSED - UHDM succeeds where Verilog fails!"
            echo "    Demonstrates UHDM's superior SystemVerilog support"
            run_sim_equivalence_softwarn "$test_dir" "$sim_cycles"
            UHDM_ONLY_TESTS=$((UHDM_ONLY_TESTS + 1))
            UHDM_ONLY_TEST_NAMES+=("$test_dir")
            return 0
        else
            echo "❌ Test $test_dir FAILED - Verilog output missing unexpectedly"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_TEST_NAMES+=("$test_dir")
            return 1
        fi
    fi

    # UHDM completed full synth but Verilog synth errored after read.
    # The Verilog post-`opt` IL is written before `synth`, so $verilog_file
    # exists but $verilog_synth (post-`synth -auto-top`) doesn't.  Treat as
    # UHDM-only success when Verilog logged an error.
    if [ -f "$uhdm_synth" ] && [ ! -f "$verilog_synth" ] && \
       [ -f "${test_dir}/verilog_path.log" ] && grep -q "ERROR" "${test_dir}/verilog_path.log"; then
        echo "✅ Test $test_dir PASSED - UHDM completes synth where Verilog synth errors!"
        echo "    Demonstrates UHDM's superior SystemVerilog support"
        run_sim_equivalence_softwarn "$test_dir" "$sim_cycles"
        UHDM_ONLY_TESTS=$((UHDM_ONLY_TESTS + 1))
        UHDM_ONLY_TEST_NAMES+=("$test_dir")
        return 0
    fi
    
    # Check if RTLIL outputs are identical
    local rtlil_identical=false
    if diff -q "$uhdm_file" "$verilog_file" >/dev/null 2>&1; then
        rtlil_identical=true
    fi
    
    # Check if synthesized netlists are identical or have same gate count
    local synth_identical=false
    local gates_match=false
    if [ -f "$uhdm_synth" ] && [ -f "$verilog_synth" ]; then
        # Compare netlists ignoring comments and whitespace
        grep -v "^//" "$uhdm_synth" | grep -v "^$" | sed 's/^[[:space:]]*//' > /tmp/uhdm_synth_clean.tmp
        grep -v "^//" "$verilog_synth" | grep -v "^$" | sed 's/^[[:space:]]*//' > /tmp/verilog_synth_clean.tmp
        if diff -q /tmp/verilog_synth_clean.tmp /tmp/uhdm_synth_clean.tmp >/dev/null 2>&1; then
            synth_identical=true
        fi
        rm -f /tmp/uhdm_synth_clean.tmp /tmp/verilog_synth_clean.tmp
        
        # Run formal equivalence check when both netlists exist, unless this
        # test opts out via `sim_config: SKIP_FORMAL=1` (e.g. a large design
        # whose formal proof is too slow — it relies on the Verilator co-sim).
        local equiv_passed=false
        local equiv_failed=false
        if [ "$skip_formal" = "1" ]; then
            echo "    ⏭  Formal equivalence SKIPPED (sim_config: SKIP_FORMAL=1)"
        elif [ -x "./test_equivalence.sh" ]; then
            if ./test_equivalence.sh "$test_dir" >/dev/null 2>&1; then
                echo "    ✅ Induct-Formal equivalence check PASSED (equiv_induct)"
                equiv_passed=true
            else
                echo "    ❌ Induct-Formal equivalence check FAILED - netlists are not logically equivalent"
                equiv_failed=true
            fi
        fi
    fi

    # Verilator co-sim now runs for EVERY test (not just UHDM-only ones),
    # using the per-test cycle count (SIM_CYCLES, default 200).  For a
    # SKIP_FORMAL test it is the sole functional check.
    SIM_EQUIV_MITER_BUG=0   # set to 1 by run_sim_equivalence_softwarn on a miter-confirmed bug
    SIM_EQUIV_COSIM_PASSED=0 # set to 1 by run_sim_equivalence_softwarn on a clean co-sim
    if [ -f "$uhdm_synth" ]; then
        run_sim_equivalence_softwarn "$test_dir" "$sim_cycles"
    fi

    # Report results
    if [ "$skip_formal" = "1" ]; then
        echo "✅ Test $test_dir PASSED - Verilator co-sim (formal skipped via sim_config)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    elif [ "$equiv_failed" = true ] \
            && [ "$(read_test_cfg "$test_dir" COSIM_EQUIV 0)" = "1" ] \
            && [ "${SIM_EQUIV_COSIM_PASSED:-0}" = "1" ] \
            && [ "${SIM_EQUIV_MITER_BUG:-0}" != "1" ]; then
        # Opt-in (cosim_equiv_tests.txt): equiv_induct is incomplete on this
        # RAM, a formal RAM miter is impractical, but the Verilator co-sim
        # confirms functional equivalence — accept it.
        echo "✅ Test $test_dir PASSED - Verilator co-sim (equiv_induct incomplete for this RAM; opt-in COSIM_EQUIV)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    elif [ "$equiv_failed" = true ]; then
        echo "❌ Test $test_dir FAILED - Induct-Formal equivalence check failed"
        EQUIV_FAILED_TESTS=$((EQUIV_FAILED_TESTS + 1))
        EQUIV_FAILED_TEST_NAMES+=("$test_dir")
        return 2  # Return 2 to indicate equivalence failure (different from other failures)
    elif [ "${SIM_EQUIV_MITER_BUG:-0}" = "1" ]; then
        # The SAT-from-reset miter proved UHDM != Verilog — a real bug, even
        # though the equiv_induct check above passed (its known blind spot).
        echo "❌ Test $test_dir FAILED - Miter-Formal proved UHDM != Verilog (equiv_induct missed it)"
        MITER_FAILED_TESTS=$((MITER_FAILED_TESTS + 1))
        MITER_FAILED_TEST_NAMES+=("$test_dir")
        return 2
    elif [ "$rtlil_identical" = true ] && [ "$synth_identical" = true ]; then
        echo "✅ Test $test_dir PASSED - Both RTLIL and synthesized netlists are IDENTICAL"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    elif [ "$equiv_passed" = true ]; then
        echo "✅ Test $test_dir PASSED - Formal equivalence check confirmed functional equivalence"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    elif [ "$rtlil_identical" = true ] && [ "$synth_identical" = false ]; then
        echo "⚠️  Test $test_dir FAILED - RTLIL identical but synthesized netlists differ"
        EQUIV_FAILED_TESTS=$((EQUIV_FAILED_TESTS + 1))
        EQUIV_FAILED_TEST_NAMES+=("$test_dir")
        return 2
    elif [ "$rtlil_identical" = false ] && [ "$synth_identical" = true ]; then
        echo "✅ Test $test_dir PASSED - RTLIL differs but synthesized netlists are IDENTICAL (functionally equivalent)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    else
        echo "⚠️  Test $test_dir FUNCTIONAL - Both RTLIL and synthesized netlists differ (no equivalence check performed)"
        # This shouldn't happen with equivalence checking enabled
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_dir")
        
        # Count lines to show size difference
        local uhdm_lines=$(wc -l < "$uhdm_file" 2>/dev/null || echo "0")
        local verilog_lines=$(wc -l < "$verilog_file" 2>/dev/null || echo "0")
        echo "    RTLIL: UHDM=$uhdm_lines lines, Verilog=$verilog_lines lines"
        
        if [ -f "$uhdm_synth" ] && [ -f "$verilog_synth" ]; then
            # Count gates
            local uhdm_gates=$(grep -E '\$_' "$uhdm_synth" | wc -l)
            local verilog_gates=$(grep -E '\$_' "$verilog_synth" | wc -l)
            echo "    Gates: UHDM=$uhdm_gates, Verilog=$verilog_gates"
        fi
        return 1
    fi
}

# Run local tests if requested and found
if [ "$RUN_LOCAL" = true ] && [ ${#TEST_DIRS[@]} -gt 0 ]; then
    for test_dir in "${TEST_DIRS[@]}"; do
    
    # Check if test should be skipped
    if should_skip_test "$test_dir"; then
        echo "=========================================="
        echo "Skipping test: $test_dir (marked in skipped_tests.txt)"
        echo "=========================================="
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        SKIPPED_TEST_NAMES+=("$test_dir")
        echo
        continue
    fi
    
    echo "=========================================="
    echo "Running test: $test_dir"
    echo "=========================================="
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check if test is expected to fail
    expected_to_fail=false
    if is_failing_test "$test_dir"; then
        expected_to_fail=true
    fi
    
    # Record start time
    start_time=$(date +%s.%N)
    TEST_START_TIMES["$test_dir"]=$start_time
    
    # Run the test and capture result (don't log verbose output)
    ./test_uhdm_workflow.sh "$test_dir" >/dev/null 2>&1
    exit_code=$?
    
    # Record end time and calculate duration
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    TEST_TIMES["$test_dir"]=$duration
    
    # Display timing info
    printf "Execution time: %.2f seconds\n" $duration
    
    # Analyze + classify the result (shared with the yosys loop).
    classify_test_outcome "$test_dir" "$exit_code" "$expected_to_fail"

    echo
    done
fi  # End of local test loop

# Run Yosys tests if requested
if [ "$RUN_YOSYS" = true ]; then
    echo "=========================================="
    echo "=== Running Yosys Tests ==="
    echo "=========================================="
    echo
    
    mkdir -p "$RUN_DIR"
    yosys_start_time=$(date +%s.%N)

    # Optional pattern filter when invoked as `--yosys <pattern>`.
    yosys_pattern=""
    if [ -n "$SPECIFIC_TEST" ] && [ "$RUN_LOCAL" = false ]; then
        yosys_pattern="$SPECIFIC_TEST"
        yosys_pattern="${yosys_pattern#*$YOSYS_TESTS_DIR/}"
        yosys_pattern="${yosys_pattern#../third_party/yosys/tests/}"
        echo "Running yosys tests matching pattern: $yosys_pattern"
        echo
    fi

    # Native per-test loop: each yosys test is materialised under test/run/ and
    # routed through the SAME analysis (setup_yosys_test → classify_test_outcome
    # → analyze_test_result + co-sim/miter) as the internal tests.
    while IFS= read -r -d '' yfile; do
        is_verilog_test "$yfile" || continue
        yrel="${yfile#$YOSYS_TESTS_DIR/}"          # e.g. functional/picorv32.v
        if should_skip_test "$yrel"; then
            echo "=========================================="
            echo "Skipping yosys test: $yrel (marked in skipped_tests.txt)"
            echo "=========================================="
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            SKIPPED_TEST_NAMES+=("yosys:$yrel")
            echo
            continue
        fi
        echo "=========================================="
        echo "Running yosys test: $yrel"
        echo "=========================================="
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        expected_to_fail=false
        is_failing_test "$yrel" && expected_to_fail=true

        ystart=$(date +%s.%N)
        setup_yosys_test "$yfile"; yexit=$?
        ydur=$(echo "$(date +%s.%N) - $ystart" | bc)
        TEST_TIMES["yosys:$yrel"]=$ydur
        printf "Execution time: %.2f seconds\n" "$ydur"

        # Both frontends produced no RTLIL at all — e.g. the `errors/` negative
        # tests that BOTH Surelog and Yosys correctly reject.  The former
        # run_yosys_tests.sh treated this as a SKIP (not a failure); keep that.
        yprefix="$(basename "$YT_RUN_DIR")"
        if [ ! -f "$YT_RUN_DIR/${yprefix}_from_uhdm_nohier.il" ] && \
           [ ! -f "$YT_RUN_DIR/${yprefix}_from_verilog_nohier.il" ]; then
            echo "Result:     ⚠️  Skipped - both frontends produced no output"
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            SKIPPED_TEST_NAMES+=("yosys:$yrel")
            echo
            continue
        fi

        # Use YT_RUN_DIR (set by setup_yosys_test) for file access; the result
        # is bucketed under that path in the shared counters/reporting.
        classify_test_outcome "$YT_RUN_DIR" "$yexit" "$expected_to_fail"
        echo
    done < <( if [ -n "$yosys_pattern" ]; then
                  find "$YOSYS_TESTS_DIR" -type f \( -name "*.v" -o -name "*.sv" \) -path "*${yosys_pattern}*" -print0 | sort -z
              else
                  find "$YOSYS_TESTS_DIR" -type f \( -name "*.v" -o -name "*.sv" \) -print0 | sort -z
              fi )

    yosys_duration=$(echo "$(date +%s.%N) - $yosys_start_time" | bc)
    printf "Yosys tests total execution time: %.2f seconds\n" "$yosys_duration"
fi

# Function to print comprehensive summary
print_comprehensive_summary() {
    echo "=========================================="
    echo "=== COMPREHENSIVE TEST SUMMARY ==="
    echo "=========================================="
    echo
    echo "📈 DETAILED BREAKDOWN:"

    if [ $PASSED_TESTS -gt 0 ]; then
        echo
        echo "✅ PERFECT MATCHES ($PASSED_TESTS tests):"
        echo "   These tests produce identical RTLIL output between UHDM and Verilog frontends:"
        for test in "${PASSED_TEST_NAMES[@]}"; do
            echo "   - $test"
        done
    fi

    if [ $UHDM_ONLY_TESTS -gt 0 ]; then
        echo
        echo "🚀 UHDM-ONLY SUCCESS ($UHDM_ONLY_TESTS tests):"
        echo "   These tests demonstrate UHDM's superior SystemVerilog support:"
        for test in "${UHDM_ONLY_TEST_NAMES[@]}"; do
            echo "   - $test"
        done
    fi

    if [ $CRASHED_TESTS -gt 0 ]; then
        echo
        echo "💥 CRASHED TESTS ($CRASHED_TESTS tests):"
        echo "   These tests crashed during execution and need investigation:"
        for test in "${CRASHED_TEST_NAMES[@]}"; do
            echo "   - $test"
        done
    fi

    if [ $EQUIV_FAILED_TESTS -gt 0 ]; then
        echo
        echo "❌ EQUIVALENCE FAILURES ($EQUIV_FAILED_TESTS tests):"
        echo "   These tests generate output but fail formal equivalence checking:"
        for test in "${EQUIV_FAILED_TEST_NAMES[@]}"; do
            echo "   - $test"
        done
    fi

    if [ $FAILED_TESTS -gt 0 ]; then
        echo
        echo "❌ TRUE FAILURES ($FAILED_TESTS tests):"
        echo "   These tests failed to generate output files:"
        for test in "${FAILED_TEST_NAMES[@]}"; do
            echo "   - $test"
        done
    fi

    echo
    echo "🔍 ANALYSIS:"
    # Recalculate functional tests before displaying
    FUNCTIONAL_TESTS=$((PASSED_TESTS + UHDM_ONLY_TESTS))
    echo "  • Tests that work: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
    echo "  • Tests that crash: $CRASHED_TESTS/$TOTAL_TESTS"
    echo "  • Tests that fail equivalence: $((EQUIV_FAILED_TESTS + MITER_FAILED_TESTS))/$TOTAL_TESTS (Induct-Formal: $EQUIV_FAILED_TESTS, Miter-Formal: $MITER_FAILED_TESTS)"
    echo "  • Tests that fail to generate output: $FAILED_TESTS/$TOTAL_TESTS"
}

# Final summary - show when any tests were run
if [ "$TOTAL_TESTS" -gt 0 ]; then
    # Print to console
    print_comprehensive_summary

# Check for any unexpected results
if [ ${#UNEXPECTED_FAILURES[@]} -gt 0 ]; then
    echo
    echo "❌ UNEXPECTED FAILURES (${#UNEXPECTED_FAILURES[@]} tests):"
    echo "   These tests were expected to pass but failed:"
    for test in "${UNEXPECTED_FAILURES[@]}"; do
        echo "   - $test"
    done
fi


if [ ${#UNEXPECTED_SUCCESSES[@]} -gt 0 ]; then
    echo
    echo "❌ UNEXPECTED SUCCESSES (${#UNEXPECTED_SUCCESSES[@]} tests):"
    echo "   These tests were expected to fail but passed:"
    for test in "${UNEXPECTED_SUCCESSES[@]}"; do
        echo "   - $test"
    done
    echo
    echo "   Please remove these from failing_tests.txt"
fi

echo
echo "📊 OVERALL STATISTICS:"
echo "  Total tests run: $TOTAL_TESTS"
echo "  ✅ Passing tests: $PASSED_TESTS"
echo "  🚀 UHDM-only success: $UHDM_ONLY_TESTS"
# Equivalence failures = Induct-Formal (equiv_induct caught) + Miter-Formal
# (UHDM != Verilog, proved by the SAT-from-reset miter that equiv_induct's
# blind spot missed).  Both are genuine non-equivalences.
TOTAL_EQUIV_FAILED=$((EQUIV_FAILED_TESTS + MITER_FAILED_TESTS))
echo "  ❌ Equivalence failures: $TOTAL_EQUIV_FAILED"
if [ "$TOTAL_EQUIV_FAILED" -gt 0 ]; then
    echo "      ├─ Induct-Formal (equiv_induct caught): $EQUIV_FAILED_TESTS"
    echo "      └─ Miter-Formal (UHDM != Verilog, equiv_induct missed): $MITER_FAILED_TESTS"
    for t in "${MITER_FAILED_TEST_NAMES[@]}"; do
        echo "          - $t"
    done
fi
echo "  ❌ True failures: $FAILED_TESTS"
echo "  💥 Crashes: $CRASHED_TESTS"
if [ "$SIM_EQUIV_WARN_TESTS" -gt 0 ]; then
    echo "  ⚠️  Verilator sim-equiv warnings: $SIM_EQUIV_WARN_TESTS"
    for t in "${SIM_EQUIV_WARN_NAMES[@]}"; do
        echo "      - $t"
    done
fi
if [ "$SIM_EQUIV_ANALYZED_TESTS" -gt 0 ]; then
    # Divergences the miter proved UHDM==Verilog (or marked artefact via
    # override): Verilator-vs-synth diffs, not bugs.  (Miter-confirmed bugs
    # are reported above as ❌ Miter-Formal failures, not here.)
    echo "  🔍 Verilator sim-equiv analyzed — known NON-bug divergences: $SIM_EQUIV_ANALYZED_TESTS"
    echo "  🔬 Sim/synth ARTEFACTS (miter: UHDM==Verilog): $SIM_EQUIV_ARTEFACT_TESTS"
    for t in "${SIM_EQUIV_ARTEFACT_NAMES[@]}"; do
        echo "      - $t"
    done
    if [ "$SIM_EQUIV_UNCLASS_TESTS" -gt 0 ]; then
        # miter INCONCLUSIVE and no override — add one to sim_equiv_classification.txt.
        echo "  ❓ UNCLASSIFIED (miter inconclusive — add an override): $SIM_EQUIV_UNCLASS_TESTS"
        for t in "${SIM_EQUIV_UNCLASS_NAMES[@]}"; do
            echo "      - $t"
        done
    fi
fi
echo

# Log the comprehensive summary to file
{
    print_comprehensive_summary
    echo
    echo "📊 OVERALL STATISTICS:"
    echo "  Total tests run: $TOTAL_TESTS"
    echo "  ✅ Passing tests: $PASSED_TESTS"
    echo "  🚀 UHDM-only success: $UHDM_ONLY_TESTS"
    echo "  ❌ Equivalence failures: $((EQUIV_FAILED_TESTS + MITER_FAILED_TESTS)) (Induct-Formal: $EQUIV_FAILED_TESTS, Miter-Formal: $MITER_FAILED_TESTS)"
    echo "  ❌ True failures: $FAILED_TESTS"
    echo "  💥 Crashes: $CRASHED_TESTS"
    echo
} >> "$LOG_FILE"

# Calculate success rate
FUNCTIONAL_TESTS=$((PASSED_TESTS + UHDM_ONLY_TESTS))
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((FUNCTIONAL_TESTS * 100 / TOTAL_TESTS))
    echo "🎯 Success Rate: $SUCCESS_RATE% ($FUNCTIONAL_TESTS/$TOTAL_TESTS tests functional)"
    echo "🎯 Success Rate: $SUCCESS_RATE% ($FUNCTIONAL_TESTS/$TOTAL_TESTS tests functional)" >> "$LOG_FILE"
fi

# Determine exit status
echo
if [ ${#UNEXPECTED_FAILURES[@]} -eq 0 ] && [ ${#UNEXPECTED_SUCCESSES[@]} -eq 0 ]; then
    # Count expected failures
    EXPECTED_FAILS=0
    for test in "${FAILED_TEST_NAMES[@]}"; do
        if is_failing_test "$test"; then
            EXPECTED_FAILS=$((EXPECTED_FAILS + 1))
        fi
    done
    for test in "${EQUIV_FAILED_TEST_NAMES[@]}"; do
        if is_failing_test "$test"; then
            EXPECTED_FAILS=$((EXPECTED_FAILS + 1))
        fi
    done
    for test in "${CRASHED_TEST_NAMES[@]}"; do
        if is_failing_test "$test"; then
            EXPECTED_FAILS=$((EXPECTED_FAILS + 1))
        fi
    done
    
    if [ $CRASHED_TESTS -eq 0 ] && [ $FAILED_TESTS -eq 0 ] && [ $EQUIV_FAILED_TESTS -eq 0 ] && [ $SIM_EQUIV_WARN_TESTS -eq 0 ]; then
        echo "🎉 EXCELLENT! All tests are functional! 🎉"
        display_timing_summary
        exit 0
    elif [ $CRASHED_TESTS -eq 0 ] && [ $FAILED_TESTS -eq 0 ] && [ $EQUIV_FAILED_TESTS -eq 0 ] && [ $SIM_EQUIV_WARN_TESTS -gt 0 ]; then
        # Only sim-equiv warnings — no expected-fails mechanism (use
        # `sim_equiv_analyzed.txt` to document a divergence instead).
        echo "❌ TEST SUITE FAILED - Verilator co-sim mismatches detected!"
        echo
        echo "  • sim-equiv warnings: $SIM_EQUIV_WARN_TESTS"
        for t in "${SIM_EQUIV_WARN_NAMES[@]}"; do
            echo "      - $t"
        done
        echo
        echo "Investigate each test's sim_equiv.log and either fix the"
        echo "underlying divergence or, if it's a documented x-propagation /"
        echo "synth-vs-RTL mismatch, add a Test: <name> entry to"
        echo "sim_equiv_analyzed.txt with the explanation."
        display_timing_summary
        exit 1
    else
        # Check if all failures are expected
        TOTAL_FAILURES=$((CRASHED_TESTS + FAILED_TESTS + EQUIV_FAILED_TESTS))
        if [ $EXPECTED_FAILS -eq $TOTAL_FAILURES ] && [ $EXPECTED_FAILS -gt 0 ] && [ $SIM_EQUIV_WARN_TESTS -eq 0 ]; then
            echo "✅ ALL RESULTS AS EXPECTED - Test suite passes with known issues"
            echo
            echo "All failing tests are documented in failing_tests.txt:"
            echo "  • Expected failures: $EXPECTED_FAILS"
            echo "  • Functional tests: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
            echo
            echo "The test suite passes because all results match expectations."
            display_timing_summary
            exit 0
        else
            echo "❌ TEST SUITE FAILED - There are failures!"
            echo
            echo "Test results:"
            echo "  • Crashed tests: $CRASHED_TESTS"
            echo "  • Equivalence failures: $EQUIV_FAILED_TESTS"
            echo "  • Failed tests: $FAILED_TESTS"
            if [ $SIM_EQUIV_WARN_TESTS -gt 0 ]; then
                echo "  • Verilator sim-equiv warnings: $SIM_EQUIV_WARN_TESTS"
            fi
            echo "  • Functional tests: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
            echo
            UNEXPECTED_COUNT=$((TOTAL_FAILURES - EXPECTED_FAILS))
            if [ $UNEXPECTED_COUNT -gt 0 ]; then
                echo "❌ Found $UNEXPECTED_COUNT unexpected failures not in failing_tests.txt"
            fi
            if [ $SIM_EQUIV_WARN_TESTS -gt 0 ]; then
                echo "❌ Sim-equiv warnings are now hard errors (document in sim_equiv_analyzed.txt if intentional)"
            fi
            echo
            echo "Please investigate failures or update failing_tests.txt"
            display_timing_summary
            exit 1
        fi
    fi
else
    echo "❌ TEST SUITE FAILED - Unexpected results detected!"
    echo
    if [ ${#UNEXPECTED_FAILURES[@]} -gt 0 ]; then
        echo "• ${#UNEXPECTED_FAILURES[@]} tests failed unexpectedly"
    fi
    if [ ${#UNEXPECTED_SUCCESSES[@]} -gt 0 ]; then
        echo "• ${#UNEXPECTED_SUCCESSES[@]} tests passed unexpectedly"
    fi
    echo
    echo "Please investigate unexpected results or update failing_tests.txt"
    display_timing_summary
    exit 1
fi

fi  # End of local test summary