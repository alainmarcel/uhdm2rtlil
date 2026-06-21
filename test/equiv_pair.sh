#!/usr/bin/env bash
#
# equiv_pair.sh — formal equivalence of two arbitrary gate-level netlists.
#
# This is the netlist-pair core of test_equivalence.sh, generalized to take two
# *_synth.v files on the command line instead of the hardcoded UHDM-vs-Verilog
# pair, so the 4-frontend matrix can equivalence-check each frontend's netlist
# against the Yosys-verilog golden.  test_equivalence.sh itself is left
# untouched (it is CI-critical); this is a sibling.
#
# Flow (identical semantics to test_equivalence.sh):
#   1. const-only designs (0 logic gates): compare constant assign values
#   2. otherwise: equiv_make -> equiv_simple -> equiv_induct
#   3. fallback: miter -equiv -flatten + sat -prove-asserts -seq 32 from reset
#
# Usage: equiv_pair.sh <gold_synth.v> <gate_synth.v> [--formal] [--log-prefix P]
# Exit:  0 = EQUIVALENT, 1 = NON-EQUIVALENT, 2 = INCONCLUSIVE (could not decide)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YOSYS_BIN="$PROJECT_ROOT/out/current/bin/yosys"
CHTYPE_FILE="$SCRIPT_DIR/equiv_chtype.ys"

GOLD="" GATE="" FORMAL=0 LOG_PREFIX=""
while [ $# -gt 0 ]; do
    case "$1" in
        --formal) FORMAL=1 ;;
        --log-prefix) shift; LOG_PREFIX="$1" ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *)  if [ -z "$GOLD" ]; then GOLD="$1"; elif [ -z "$GATE" ]; then GATE="$1"; fi ;;
    esac
    shift
done

if [ -z "$GOLD" ] || [ -z "$GATE" ]; then
    echo "Usage: $0 <gold_synth.v> <gate_synth.v> [--formal] [--log-prefix P]" >&2
    exit 2
fi
if [ ! -f "$GOLD" ] || [ ! -f "$GATE" ]; then
    echo "❌ INCONCLUSIVE: missing netlist (gold=$GOLD gate=$GATE)" >&2
    exit 2
fi
if [ ! -x "$YOSYS_BIN" ]; then
    echo "❌ INCONCLUSIVE: yosys not found at $YOSYS_BIN" >&2
    exit 2
fi

# Where to drop generated scripts / logs.  Default: alongside the GATE netlist.
[ -n "$LOG_PREFIX" ] || LOG_PREFIX="$(dirname "$GATE")/$(basename "$GATE" .v)_equiv"
EQUIV_SCRIPT="${LOG_PREFIX}.ys"
EQUIV_LOG="${LOG_PREFIX}.log"
SAT_SCRIPT="${LOG_PREFIX}_sat.ys"
SAT_LOG="${LOG_PREFIX}_sat.log"

GOLD_GATES=$(grep -c -E '\$_' "$GOLD" 2>/dev/null || echo 0)
GATE_GATES=$(grep -c -E '\$_' "$GATE" 2>/dev/null || echo 0)

# ---- const-only designs: compare constant assign values module-by-module ----
if [ "$GOLD_GATES" -eq 0 ] && [ "$GATE_GATES" -eq 0 ]; then
    AWK_RESULT=$(awk '
    FNR == NR {
        if (match($0, /^[[:space:]]*module[[:space:]]+([^[:space:](;]+)/, m)) cur_mod = m[1]
        if (match($0, /^[[:space:]]*assign[[:space:]]+([^[:space:]=]+)[[:space:]]*=[[:space:]]*(.*);[[:space:]]*$/, a)) {
            val = a[2]; gsub(/ /, "", val); gsub(/\?/, "x", val); gate[cur_mod ":" a[1]] = val
        }
        next
    }
    {
        if (match($0, /^[[:space:]]*module[[:space:]]+([^[:space:](;]+)/, m)) cur_mod = m[1]
        if (match($0, /^[[:space:]]*assign[[:space:]]+([^[:space:]=]+)[[:space:]]*=[[:space:]]*(.*);[[:space:]]*$/, a)) {
            gold_val = a[2]; gsub(/ /, "", gold_val); gsub(/\?/, "x", gold_val)
            if (gold_val ~ /[xXzZ]/) next
            key = cur_mod ":" a[1]
            if (!(key in gate)) next
            checked++
            if (gold_val != gate[key]) print "FAIL:" cur_mod "." a[1] ":gold=" gold_val ":gate=" gate[key]
        }
    }
    END { print "CHECKED=" checked+0 }
    ' "$GATE" "$GOLD")
    CHECKED=$(echo "$AWK_RESULT" | sed -n 's/^CHECKED=//p')
    if echo "$AWK_RESULT" | grep -q '^FAIL:'; then
        echo "❌ NON-EQUIVALENT: constant value mismatch"
        echo "$AWK_RESULT" | grep '^FAIL:'
        exit 1
    fi
    if [ "${CHECKED:-0}" -eq 0 ]; then
        echo "ℹ️  INCONCLUSIVE: no common constant assignments to compare"
        exit 2
    fi
    echo "✅ EQUIVALENT: all $CHECKED constant assignments match"
    exit 0
fi

# One side has gates, the other doesn't → not equivalent (a frontend dropped logic).
if [ "$GOLD_GATES" -eq 0 ] || [ "$GATE_GATES" -eq 0 ]; then
    echo "❌ NON-EQUIVALENT: gate counts gold=$GOLD_GATES gate=$GATE_GATES (one side empty)"
    exit 1
fi

# ---- gate-level: equiv_make -> equiv_simple -> equiv_induct ------------------
FORMAL_PREP=""
[ "$FORMAL" -eq 1 ] && FORMAL_PREP=$'async2sync\nchformal -lower\ndelete t:$check\ndelete t:$print\nopt_clean'

{
cat <<EOF
read_verilog -lib +/simcells.v
read_verilog -sv $GOLD
hierarchy -auto-top
proc
flatten
opt -purge
design -stash gold_flat

design -reset
read_verilog -lib +/simcells.v
read_verilog -sv $GATE
hierarchy -auto-top
proc
flatten
opt -purge
design -stash gate_flat

design -copy-from gold_flat -as gold *
design -copy-from gate_flat -as gate *

equiv_make gold gate equiv
EOF
cat "$CHTYPE_FILE"
echo "$FORMAL_PREP"
cat <<EOF
equiv_simple
equiv_induct
equiv_status -assert
EOF
} > "$EQUIV_SCRIPT"

if "$YOSYS_BIN" -s "$EQUIV_SCRIPT" > "$EQUIV_LOG" 2>&1; then
    echo "✅ EQUIVALENT (equiv_induct)"
    exit 0
fi

# ---- SAT-from-reset fallback ------------------------------------------------
# equiv_induct fails on unreachable register states where ABC made different
# but semantically equivalent mapping choices.  A bounded SAT proof from the
# all-zero reset state is what real hardware does and is what we actually care
# about.
{
cat <<EOF
read_verilog -lib +/simcells.v
read_verilog -sv $GOLD
hierarchy -auto-top
proc
flatten
opt -purge
EOF
cat "$CHTYPE_FILE"
cat <<EOF
rename -top gold
design -stash gold

design -reset
read_verilog -lib +/simcells.v
read_verilog -sv $GATE
hierarchy -auto-top
proc
flatten
opt -purge
EOF
cat "$CHTYPE_FILE"
cat <<EOF
rename -top gate
design -stash gate

design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert -make_outputs gold gate miter
sat -prove-asserts -seq 32 -set-init-zero miter
EOF
} > "$SAT_SCRIPT"

"$YOSYS_BIN" -s "$SAT_SCRIPT" > "$SAT_LOG" 2>&1
if grep -q "SAT proof finished - no model found: SUCCESS!" "$SAT_LOG"; then
    echo "✅ EQUIVALENT (SAT, 32 cycles from reset)"
    exit 0
fi
if grep -qE "SAT proof finished - model found: FAIL!|Assert .* failed" "$SAT_LOG"; then
    echo "❌ NON-EQUIVALENT (SAT found a counterexample)"
    echo "   see $EQUIV_LOG and $SAT_LOG"
    exit 1
fi

echo "❓ INCONCLUSIVE (equiv_induct failed; SAT neither proved nor refuted)"
echo "   see $EQUIV_LOG and $SAT_LOG"
exit 2
