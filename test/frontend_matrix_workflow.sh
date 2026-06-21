#!/usr/bin/env bash
#
# frontend_matrix_workflow.sh — run a single test through ALL FOUR
# SystemVerilog/Verilog frontends and emit one synthesized netlist per frontend.
#
#   verilog : Yosys native      read_verilog            (also the golden ref)
#   uhdm    : this plugin        Surelog -> read_uhdm
#   sv2v    : zachjs/sv2v        sv2v src... -> read_verilog
#   slang   : povik/yosys-slang  read_slang src...
#
# Only the *read* step differs between frontends; the synthesis tail
#   hierarchy -check -auto-top; proc; opt; synth -auto-top; write_verilog -noexpr
# is identical, so the downstream correctness machinery (equiv_pair.sh,
# cosim via test_sim_equivalence.py) can treat every netlist uniformly.
#
# Produces, in the test directory, for each frontend <f> that runs:
#   <name>_from_<f>_nohier.il      RTLIL straight after read (pre-hierarchy)
#   <name>_from_<f>_synth.v        gate-level netlist (post synth)
#   <f>_path.log                   the Yosys log for that frontend
# and a single:
#   frontend_status.txt            one line per frontend: "<f> <STATUS> <gates>"
# where STATUS is one of:
#   OK            read + synth succeeded, >0 logic gates
#   NO_GATES      read + synth succeeded but 0 logic gates (const-only design)
#   SYNTH_FAIL    read succeeded (nohier.il written) but synth/hierarchy failed
#   READ_FAIL     frontend could not read the source
#   CONVERT_FAIL  sv2v failed to transpile the source
#   CRASH         the tool crashed (signal: exit >= 128)
#   TOOL_MISSING  the frontend's tool/plugin is not built
#
# Usage: frontend_matrix_workflow.sh <test_directory>   (relative to test/)

if [ $# -ne 1 ]; then
    echo "Usage: $0 <test_directory>" >&2
    exit 1
fi

# Resolve absolute paths BEFORE cd-ing into the (possibly deeply-nested, e.g.
# run/simple/always01) test directory, so binary/plugin/helper paths stay valid
# regardless of how many levels deep the test lives.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # = test/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_DIR="$1"
if [ ! -d "$TEST_DIR" ]; then
    echo "ERROR: Test directory '$TEST_DIR' does not exist" >&2
    exit 1
fi

cd "$TEST_DIR" || exit 1
MODULE_NAME=$(basename "$(pwd)")

# Absolute paths to tools and plugins.
SURELOG_BIN="$PROJECT_ROOT/build/third_party/Surelog/bin/surelog"
YOSYS_BIN="$PROJECT_ROOT/out/current/bin/yosys"
UHDM_PLUGIN="$PROJECT_ROOT/build/uhdm2rtlil.so"
SLANG_PLUGIN="$PROJECT_ROOT/build/slang.so"
SV2V_BIN="$PROJECT_ROOT/build/frontends/sv2v/bin/sv2v"

# Resolve the file list / language flags the same way every other harness does.
source "$SCRIPT_DIR/project_files.sh"

READ_FLAG="$PROJECT_LANG"          # "-sv" or ""
FORMAL_FLAG=""
[ "$PROJECT_FORMAL" = "1" ] && FORMAL_FLAG="-formal"

STATUS_FILE="frontend_status.txt"
: > "$STATUS_FILE"

# Clean previous matrix artefacts (leave the legacy *_from_uhdm*/*_from_verilog*
# files used by the older harness alone — they share the same names, so we
# regenerate them here anyway).
rm -f *_from_*_synth.v *_from_*_nohier.il \
      verilog_path.log uhdm_path.log sv2v_path.log slang_path.log \
      ${MODULE_NAME}_sv2v.v
rm -rf slpp_all

# Count synthesised logic cells ($_AND_, $_DFF_, …) in a netlist.  (grep -c
# already prints 0 and exits 1 on no match, so no `|| echo 0` — that would emit
# a spurious second 0.)  Empty result (missing file) falls back to 0.
gate_count() { local n; n=$(grep -c -E '\$_' "$1" 2>/dev/null); echo "${n:-0}"; }

# Classify a frontend run from its exit code + produced files, append to status.
#   $1 frontend key   $2 exit code
record_status() {
    local f="$1" rc="$2"
    local synth="${MODULE_NAME}_from_${f}_synth.v"
    local nohier="${MODULE_NAME}_from_${f}_nohier.il"
    local status gates=0
    if [ "$rc" -ge 128 ]; then
        status="CRASH"
    elif [ -f "$synth" ]; then
        gates=$(gate_count "$synth")
        if [ "$gates" -gt 0 ]; then status="OK"; else status="NO_GATES"; fi
    elif [ -f "$nohier" ]; then
        status="SYNTH_FAIL"
    else
        status="READ_FAIL"
    fi
    echo "$f $status $gates" >> "$STATUS_FILE"
    echo "   → $f: $status (${gates} gates)"
}

# Emit the shared synthesis tail for a frontend into its read script.
emit_tail() {
    local f="$1"
    cat <<EOF
write_rtlil ${MODULE_NAME}_from_${f}_nohier.il
hierarchy -check -auto-top
proc
opt
synth -auto-top
write_verilog -noexpr ${MODULE_NAME}_from_${f}_synth.v
EOF
}

echo "=== 4-frontend matrix workflow: $MODULE_NAME ==="
echo "Sources: $PROJECT_SRCS"

# ---------------------------------------------------------------- verilog ----
echo "[1/4] verilog (Yosys native read_verilog)"
{
    echo "read_verilog $READ_FLAG $FORMAL_FLAG $PROJECT_SRCS"
    emit_tail verilog
} > verilog_read.ys
"$YOSYS_BIN" -s verilog_read.ys > verilog_path.log 2>&1
record_status verilog $?

# ------------------------------------------------------------------- uhdm ----
echo "[2/4] uhdm (Surelog -> read_uhdm)"
if [ ! -f "$UHDM_PLUGIN" ]; then
    echo "uhdm TOOL_MISSING 0" >> "$STATUS_FILE"
    echo "   → uhdm: TOOL_MISSING (plugin not built)"
else
    "$SURELOG_BIN" -parse -nobuiltin -nocache -d vpi_ids -d uhdm \
        $PROJECT_LANG $PROJECT_SURELOG_FLAGS $PROJECT_SRCS > surelog_build.log 2>&1 || true
    if [ ! -f slpp_all/surelog.uhdm ]; then
        echo "uhdm READ_FAIL 0" >> "$STATUS_FILE"
        echo "   → uhdm: READ_FAIL (Surelog produced no UHDM; see surelog_build.log)"
    else
        {
            echo "read_uhdm $FORMAL_FLAG slpp_all/surelog.uhdm"
            emit_tail uhdm
        } > uhdm_read.ys
        "$YOSYS_BIN" -m "$UHDM_PLUGIN" -s uhdm_read.ys > uhdm_path.log 2>&1
        record_status uhdm $?
    fi
fi

# ------------------------------------------------------------------- sv2v ----
echo "[3/4] sv2v (sv2v -> read_verilog)"
if [ ! -x "$SV2V_BIN" ]; then
    echo "sv2v TOOL_MISSING 0" >> "$STATUS_FILE"
    echo "   → sv2v: TOOL_MISSING (run build_frontends.sh)"
else
    # sv2v wants every source at once so it can resolve packages/interfaces.
    if "$SV2V_BIN" $PROJECT_SRCS > "${MODULE_NAME}_sv2v.v" 2> sv2v_convert.log; then
        {
            echo "read_verilog $FORMAL_FLAG ${MODULE_NAME}_sv2v.v"
            emit_tail sv2v
        } > sv2v_read.ys
        "$YOSYS_BIN" -s sv2v_read.ys > sv2v_path.log 2>&1
        record_status sv2v $?
    else
        echo "sv2v CONVERT_FAIL 0" >> "$STATUS_FILE"
        echo "   → sv2v: CONVERT_FAIL (transpile error; see sv2v_convert.log)"
    fi
fi

# ------------------------------------------------------------------ slang ----
echo "[4/4] slang (yosys-slang read_slang)"
if [ ! -f "$SLANG_PLUGIN" ]; then
    echo "slang TOOL_MISSING 0" >> "$STATUS_FILE"
    echo "   → slang: TOOL_MISSING (run build_frontends.sh)"
else
    {
        echo "read_slang $PROJECT_SRCS"
        emit_tail slang
    } > slang_read.ys
    "$YOSYS_BIN" -m "$SLANG_PLUGIN" -s slang_read.ys > slang_path.log 2>&1
    record_status slang $?
fi

echo
echo "=== frontend_status.txt ==="
cat "$STATUS_FILE"
exit 0
