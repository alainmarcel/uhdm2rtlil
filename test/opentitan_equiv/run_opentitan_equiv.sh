#!/usr/bin/env bash
# Upstream lowRISC OpenTitan per-module equivalence: read_uhdm vs the built-in
# read_slang reference, SAT-mitered.
#
#   ./run_opentitan_equiv.sh [module...]   # default: every manifest module
#
# Self-contained: vendored sources under rtl/ (see vendor_opentitan.sh), its own
# manifest, nothing shared with test/pavona_equiv -- pavona is a hard fork whose
# RTL has diverged, so its results do not transfer to upstream.
#
# Each module elaborates standalone, then
#     miter -equiv;  sat -verify -prove-asserts -seq <seq> -set-init-zero
# and the observed verdict is compared against opentitan_modules.txt:
#     proven | cex | timeout | error | elabfail | dead
# Shrink-only ratchet: a module regressing from its recorded verdict fails.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
YOSYS="$ROOT/out/current/bin/yosys"
PLUGIN="$ROOT/build/uhdm2rtlil.so"
SURELOG="$ROOT/build/third_party/Surelog/bin/surelog"
JOBS=${JOBS:-$(( $(nproc 2>/dev/null || echo 4) / 2 ))}
[ "$JOBS" -lt 1 ] && JOBS=1

OTBN="$HERE/rtl/otbn"
PRIM="$HERE/rtl/prim"
TLUL="$HERE/rtl/tlul"
PKG="$HERE/rtl/pkg"

# Package order matters: the cross-IP packages first (they are leaves), then
# the prim packages, then tlul, then otbn's own packages, then the modules.
srcs() {
  # Macro definitions FIRST.  OpenTitan relies on compilation-unit scope for
  # its assertion / flop macros -- otbn_kmac_if.sv uses `ASSERT and
  # `PRIM_FLOP_SPARSE_FSM without any `include of its own -- so both frontends
  # need these files ahead of every consumer or the macros are unknown.
  echo "$PRIM/prim_assert.sv"
  echo "$PRIM/prim_flop_macros.sv"
  for p in prim_util_pkg prim_secded_pkg prim_mubi_pkg prim_cipher_pkg \
           prim_trivium_pkg prim_count_pkg prim_ram_1p_pkg prim_pkg \
           prim_sparse_fsm_pkg prim_alert_pkg prim_esc_pkg prim_otp_pkg \
           prim_subreg_pkg; do
    [ -f "$PRIM/$p.sv" ] && echo "$PRIM/$p.sv"
  done
  echo "$PKG/top_pkg.sv"
  for p in lc_ctrl_reg_pkg lc_ctrl_state_pkg lc_ctrl_pkg entropy_src_pkg \
           csrng_reg_pkg csrng_pkg edn_pkg otp_ctrl_pkg sha3_pkg kmac_pkg \
           keymgr_reg_pkg keymgr_pkg keymgr_dpe_pkg; do
    [ -f "$PKG/$p.sv" ] && echo "$PKG/$p.sv"
  done
  ls "$TLUL"/*_pkg.sv 2>/dev/null
  echo "$OTBN/otbn_reg_pkg.sv"
  echo "$OTBN/otbn_pkg.sv"
  ls "$PRIM"/prim_*.sv | grep -vE "_pkg\.sv|prim_assert\.sv|prim_flop_macros\.sv"
  ls "$TLUL"/*.sv | grep -vE "_pkg\.sv"
  ls "$OTBN"/otbn_*.sv | grep -vE "_pkg\.sv"
}

# Plain strings, not arrays: bash cannot export an array to the xargs
# subshells the parallel driver below uses.
INCS="-I$PRIM -I$TLUL -I$OTBN -I$PKG"
SINCS="-I $PRIM -I $TLUL -I $OTBN -I $PKG"

run_one() {
  local mod="$1" seq="$2" tmo="$3" want="$4"
  local work="$HERE/work/$mod"
  mkdir -p "$work"

  if [ ! -f "$work/slpp_all/surelog.uhdm" ] \
     || [ "$SURELOG" -nt "$work/slpp_all/surelog.uhdm" ]; then
    (cd "$work" && "$SURELOG" -parse -d uhdm $INCS -DSYNTHESIS \
        -top "$mod" $(srcs) > surelog.log 2>&1)
  fi
  if [ ! -f "$work/slpp_all/surelog.uhdm" ]; then
    echo "  💥 $mod — surelog produced no UHDM (want=$want)"
    [ "$want" = "elabfail" ] && return 0 || return 1
  fi

  cat > "$work/miter.ys" <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $mod
flatten; proc; delete t:\$check t:\$assert t:\$assume t:\$print
opt; memory; async2sync; techmap; opt
rename $mod gold
design -stash gold
read_slang --single-unit --ignore-assertions -DSYNTHESIS $SINCS $(srcs | tr '\n' ' ') --top $mod
hierarchy -check -top $mod
flatten; proc; delete t:\$check t:\$assert t:\$assume t:\$print
opt; memory; async2sync; techmap; opt
rename $mod gate
design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq $seq -set-init-zero miter
EOF
  local out rc got
  out="$(cd "$work" && timeout "$tmo" "$YOSYS" -m "$PLUGIN" miter.ys 2>&1)"
  rc=$?
  echo "$out" > "$work/miter.log"
  if echo "$out" | grep -q "SAT proof finished - no model found: SUCCESS"; then
    got=proven
  elif echo "$out" | grep -q "model found: FAIL"; then
    got=cex
  elif [ $rc -eq 124 ]; then
    got=timeout
  elif echo "$out" | grep -qE "^ERROR: Design elaboration failed"; then
    got=elabfail
  else
    got=error
  fi
  local icon="❌"
  [ "$got" = "$want" ] && icon="✅"
  # Shrink-only ratchet: proving a module recorded as anything else is progress.
  [ "$got" = "proven" ] && icon="✅"
  echo "  $icon $mod  $got (want=$want)"
  { [ "$got" = "$want" ] || [ "$got" = "proven" ]; }
}
export -f run_one srcs
export HERE ROOT YOSYS PLUGIN SURELOG OTBN PRIM TLUL PKG INCS SINCS

mods=()
if [ $# -gt 0 ]; then
  for m in "$@"; do
    line="$(grep -E "^$m\s" "$HERE/opentitan_modules.txt" || true)"
    [ -n "$line" ] && mods+=("$line") || mods+=("$m 2 600 proven")
  done
else
  while read -r l; do
    [ -z "$l" ] && continue
    case "$l" in \#*) continue;; esac
    mods+=("$l")
  done < "$HERE/opentitan_modules.txt"
fi

# Parallel like the pavona runner: 32 modules each re-elaborating ~120 vendored
# files is far too slow serially for a nightly.
run_line() {
  read -r mod seq tmo want <<< "$1"
  if [ "$want" = "dead" ]; then
    echo "  ⏭  $mod — dead (DV collateral)"
    return 0
  fi
  run_one "$mod" "${seq:-2}" "${tmo:-600}" "${want:-proven}" \
    || echo "  REGRESSION $mod"
}
export -f run_line

printf '%s\n' "${mods[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_line "{}"' \
  | tee "$HERE/last_run.log"
fails=$(grep -c "REGRESSION" "$HERE/last_run.log" || true)
proven=$(grep -cE "✅ .* proven" "$HERE/last_run.log" || true)
total=${#mods[@]}
echo "OpenTitan module equivalence: $proven/$total proven, $fails regressions (jobs=$JOBS)"
[ "$fails" -eq 0 ]
