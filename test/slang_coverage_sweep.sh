#!/bin/bash
# slang_coverage_sweep.sh -- can read_slang read each regression test at all?
#
# The suite's slang column is the 200-odd tests with a test_slang_equiv.ys;
# nothing measured the rest.  This sweep feeds every INTERNAL test (test/*/)
# and every UPSTREAM yosys test (test/run/**) to `read_slang` with the source
# list the regression itself uses, and records one line per test:
#
#   <dir> TAB OK|FAIL|TIMEOUT|NOFILES TAB <first diagnostic>
#
# What the regression's other frontends get, read_slang gets too:
#   * internal tests: the source list and `# surelog:` flags project_files.sh
#     composes (dut.sv, or a project.f filelist), with its -I / -D
#   * upstream tests: the files of the generated test_verilog_read.ys, their
#     `read_verilog -lib <cells>` as `-v <cells>`, and every OTHER yosys test
#     in the same directory as a `-v` library file too -- yosys's own tests
#     are read file by file (a testbench in one file instantiates the module
#     another test file defines, `counter_tb` -> `counter`), and a library
#     file is only pulled in when something references it, so this resolves
#     them the way the upstream .ys scripts do.  sv-elab has no blackbox
#     option any more (`--ignore-unknown-modules` is "no longer supported"),
#     so a module no sibling defines stays an "unknown module" row.
#
# Usage: ./slang_coverage_sweep.sh [-j N] [out.tsv]      (from test/; ~3 min)
#        ./slang_coverage_sweep.sh --one <dir>            print the command for ONE
#                                                          test, run it, show all diagnostics
# Then:  python3 slang_report.py --tests out.tsv ...     (see slang_report.py)
set -u
JOBS=8
ONE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -j) JOBS="$2"; shift 2;;
        --one) ONE="$2"; shift 2;;
        *) break;;
    esac
done
OUT="${1:-slang_coverage.tsv}"
cd "$(dirname "$0")" || exit 2
TEST_ROOT="$(pwd)"
YOSYS="$(cd .. && pwd)/out/current/bin/yosys"
export TEST_ROOT YOSYS

# Print the read_slang command line for test dir $1 (relative to test/), as
# "<flags and files>" -- or nothing when the test has no sources.
slang_args() {
    local d="$1" files="" flags=""
    case "$d" in
    run/*)
        [ -f test_verilog_read.ys ] || return 1
        files=$(grep -E '^read_verilog ' test_verilog_read.ys | grep -v -- ' -lib ' \
                | sed -E 's/^read_verilog//; s/ -sv//g; s/ -formal//g; s/ -icells//g; s/ -defer//g; s/ -noassert//g; s/ -nolatches//g' | tr '\n' ' ')
        for f in $(grep -hoE '(^|[[:space:]])-[ID][^[:space:]]+' test_verilog_read.ys | tr -d ' ' | sort -u); do flags="$flags $f"; done
        files=$(echo "$files" | sed -E 's/ -[ID][^ ]+//g')
        for l in $(grep -E '^read_verilog .* -lib ' test_verilog_read.ys | sed -E 's/^read_verilog//; s/ -lib//; s/ -sv//g; s/ -defer//g'); do flags="$flags -v $l"; done
        # Sibling yosys tests that DEFINE a module this one instantiates, as
        # library files (resolved in run_one below: a blanket `-v ../*/dut.v`
        # parses every sibling, and one testbench's `\`outfile` macro then
        # poisons the whole directory).
        ;;
    *)
        # the regression's own composition (dut.sv / dut.v, or project.f)
        local PROJECT_SRCS="" PROJECT_SURELOG_FLAGS="" PROJECT_LANG=""
        if [ -f ../project_files.sh ]; then
            # shellcheck disable=SC1091
            source ../project_files.sh 2>/dev/null
        fi
        files="$PROJECT_SRCS"
        for f in $(echo "$PROJECT_SURELOG_FLAGS" | grep -oE '(^|[[:space:]])-[ID][^[:space:]]+' | tr -d ' ' | sort -u); do flags="$flags $f"; done
        [ -z "$files" ] && { for c in dut.sv dut.v; do [ -f $c ] && files=$c; done; }
        ;;
    esac
    [ -z "$(echo $files)" ] && return 1
    echo "$flags $files"
}

# Run read_slang on $1 (a test dir, cwd already there) with args $2; for an
# upstream test, resolve "unknown module 'X'" by adding the sibling test file
# that defines X as a `-v` library and retrying (up to 4 rounds).  Sets
# RUN_OUT / RUN_ERR / RUN_RC / RUN_ARGS.
run_one() {
    local d="$1" args="$2" round=0
    while :; do
        RUN_OUT=$(timeout 120 "$YOSYS" -p "read_slang $args" 2>/tmp/slang_sweep_err_$$); RUN_RC=$?
        RUN_ERR=$(cat /tmp/slang_sweep_err_$$; rm -f /tmp/slang_sweep_err_$$)
        RUN_ARGS="$args"
        case "$d" in run/*) ;; *) return;; esac
        [ $RUN_RC -ne 0 ] && [ $round -lt 4 ] || return
        local missing added=0 m sib
        missing=$(echo "$RUN_OUT" | grep -oE "unknown module '[^']+'" | sed -E "s/unknown module '([^']+)'/\\1/" | sort -u)
        [ -z "$missing" ] && return
        for m in $missing; do
            sib=$(grep -lE "^\\s*module\\s+$m\\b" ../*/dut.v ../*/dut.sv 2>/dev/null | grep -v "^../$(basename "$d")/" | head -1)
            [ -n "$sib" ] || continue
            case " $args " in *" -v $sib "*) continue;; esac
            args="$args -v $sib"; added=1
        done
        [ $added -eq 1 ] || return
        round=$((round + 1))
    done
}

one() {
    local d="$1"
    cd "$TEST_ROOT/$d" 2>/dev/null || { printf '%s\tNODIR\t\n' "$d"; return; }
    local args; args=$(slang_args "$d") || { printf '%s\tNOFILES\tno sources found (run the regression first for run/** tests)\n' "$d"; return; }
    local out err rc
    run_one "$d" "$args"; out="$RUN_OUT"; err="$RUN_ERR"; rc=$RUN_RC
    if [ $rc -eq 0 ]; then printf '%s\tOK\t\n' "$d"
    elif [ $rc -eq 124 ]; then printf '%s\tTIMEOUT\t\n' "$d"
    else
        # slang's own diagnostic is on stdout (`file:line:col: error: ...`); the
        # yosys summary ("Design elaboration failed") on stderr is the fallback.
        local diag
        diag=$( (echo "$out" | grep -E ': error: |^error: '; echo "$err" | grep -E '^ERROR:') | head -1 \
                | sed -E 's#^(\.\./)*[^ :]*/([^/ :]+):([0-9]+):([0-9]+): #\2:\3:\4: #' | cut -c1-220)
        printf '%s\tFAIL\t%s\n' "$d" "$diag"
    fi
}
export -f one slang_args run_one

if [ -n "$ONE" ]; then
    cd "$TEST_ROOT/$ONE" || exit 2
    args=$(slang_args "$ONE") || { echo "no sources for $ONE"; exit 2; }
    run_one "$ONE" "$args"
    echo "cd test/$ONE && ../../out/current/bin/yosys -p 'read_slang$RUN_ARGS'"
    echo "---- exit $RUN_RC"
    (echo "$RUN_OUT"; echo "$RUN_ERR") | grep -E "error:|ERROR:|warning:|Build failed" | head -40
    exit 0
fi

{
    for d in */; do d=${d%/}; case "$d" in run|parallel_results|ext_ip|cva6_equiv|cva6_chip|pavona_*|caliptra_chip|ibex|rp32|opentitan_equiv) continue;; esac
        [ -f "$d/test_verilog_read.ys" ] || [ -f "$d/dut.sv" ] || [ -f "$d/dut.v" ] || [ -f "$d/project.f" ] || continue; echo "$d"; done
    find run -name test_verilog_read.ys -printf '%h\n' | sort
} | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {} | sort > "$OUT"
awk -F'\t' '{c[$2]++} END {for (k in c) printf "%s %d\n", k, c[k]}' "$OUT" | sort
echo "-> $OUT"
