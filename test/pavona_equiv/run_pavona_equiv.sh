#!/usr/bin/env bash
# Pavona (Ibex @ the OpenTitan-style hardened config) per-module equivalence:
# read_uhdm vs the built-in read_slang reference, SAT-mitered.
#
#   ./run_pavona_equiv.sh [module...]     # default: every manifest module
#
# Mirrors test/cva6_equiv/run_cva6_equiv.sh: each module elaborates standalone
# with the PAVONA parameter overrides (wrappers/params_<mod>.txt — the same
# numeric values feed surelog -P and read_slang -G), then
#     miter -equiv;  sat -verify -prove-asserts -seq <seq> -set-init-zero
# and the observed verdict is compared against pavona_modules.txt:
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

IBEX="$HERE/rtl/ibex"
PRIM="$HERE/rtl/prim"

# Package files first (both tools), then prims, then the ibex modules
# (tracer excluded — DV collateral).
srcs() {
  echo "$IBEX/ibex_pkg.sv"
  for p in prim_pkg prim_util_pkg prim_count_pkg prim_mubi_pkg \
           prim_secded_pkg prim_cipher_pkg prim_ram_1p_pkg; do
    [ -f "$PRIM/$p.sv" ] && echo "$PRIM/$p.sv"
  done
  ls "$PRIM"/prim_*.sv | grep -vE "_pkg\.sv|_macros\.sv"
  ls "$IBEX"/ibex_*.sv | grep -vE "_pkg\.sv|tracer|top_tracing"
}

run_one() {
  local mod="$1" seq="$2" tmo="$3" want="$4"
  local work="$HERE/work/$mod"
  mkdir -p "$work"
  local pfile="$HERE/wrappers/params_$mod.txt"
  local sl_p=() sg_p=()
  if [ -f "$pfile" ]; then
    while read -r name nval gval; do
      [ -n "$name" ] || continue
      sl_p+=("-P$name=$nval")
      sg_p+=("-G$name=$gval")
    done < "$pfile"
  fi

  # Optional flat-port shim (wrappers/flat_<mod>.sv, top <mod>_flat): modules
  # with unpacked-array PORTS cannot be mitered directly — the two frontends
  # flatten such ports with OPPOSITE element orders (read_uhdm packs element
  # 0 at the LSBs, read_slang at the MSBs), so the miter feeds swapped
  # elements and reports convention-only counterexamples (ibex_alu's
  # imd_val_q_i).  The shim maps the array to an explicit flat bus by
  # part-select; both sides read it, killing the ambiguity.  The shim
  # forwards the module parameters under the same names, so -P/-G apply
  # unchanged.
  local flat="$HERE/wrappers/flat_$mod.sv"
  local top="$mod" extra_src=""
  if [ -f "$flat" ]; then
    top="${mod}_flat"
    extra_src="$flat"
  fi

  # 1. surelog elaboration (re-run when inputs or surelog are newer).
  if [ ! -f "$work/slpp_all/surelog.uhdm" ] \
     || [ "$SURELOG" -nt "$work/slpp_all/surelog.uhdm" ] \
     || [ "$pfile" -nt "$work/slpp_all/surelog.uhdm" ] \
     || { [ -n "$extra_src" ] && [ "$flat" -nt "$work/slpp_all/surelog.uhdm" ]; }; then
    (cd "$work" && "$SURELOG" -parse -d uhdm -I"$PRIM" -I"$IBEX" -DSYNTHESIS \
        "${sl_p[@]}" -top "$top" $(srcs) $extra_src > surelog.log 2>&1)
  fi
  if [ ! -f "$work/slpp_all/surelog.uhdm" ]; then
    echo "  💥 $mod — surelog produced no UHDM (want=$want)"
    [ "$want" = "elabfail" ] && return 0 || return 1
  fi

  # 2. miter.
  cat > "$work/miter.ys" <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $top
flatten; proc; delete t:\$check t:\$assert t:\$assume t:\$print
opt; memory; async2sync; techmap; opt
rename $top gold
design -stash gold
read_slang --ignore-assertions -DSYNTHESIS -I $PRIM -I $IBEX ${sg_p[@]} $(srcs | tr '\n' ' ') $extra_src --top $top
hierarchy -check -top $top
flatten; proc; delete t:\$check t:\$assert t:\$assume t:\$print
opt; memory; async2sync; techmap; opt
rename $top gate
design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq $seq -set-init-zero miter
EOF
  local out rc
  out="$(cd "$work" && timeout "$tmo" "$YOSYS" -m "$PLUGIN" miter.ys 2>&1)"
  rc=$?
  local got
  if echo "$out" | grep -q "SAT proof finished - no model found: SUCCESS"; then
    got=proven
  elif echo "$out" | grep -q "model found: FAIL"; then
    got=cex
  elif [ $rc -eq 124 ]; then
    got=timeout
  elif echo "$out" | grep -qi "elaboration failed\|ERROR"; then
    got=error
  else
    got=error
  fi
  echo "$out" > "$work/miter.log"

  if [ "$got" = "$want" ]; then
    echo "  ✅ $mod $got (seq=$seq)"
  elif [ "$got" = proven ]; then
    echo "  🎉 $mod NEWLY PROVEN (manifest says $want) — promote it"
  elif [ "$got" = timeout ] && [ "$want" != proven ]; then
    echo "  ⚠  $mod timeout (want=$want) — inconclusive"
  else
    echo "  ❌ $mod $got (want=$want) — REGRESSION"
    return 1
  fi
  return 0
}

export -f run_one srcs
export HERE ROOT YOSYS PLUGIN SURELOG IBEX PRIM

fails=0
mods=()
while read -r mod seq tmo want _; do
  [ -z "$mod" ] || [ "${mod:0:1}" = "#" ] && continue
  [ "$want" = "dead" ] && continue
  if [ $# -gt 0 ]; then
    case " $* " in *" $mod "*) ;; *) continue ;; esac
  fi
  mods+=("$mod $seq $tmo $want")
done < "$HERE/pavona_modules.txt"

printf '%s\n' "${mods[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one {}' \
  | tee "$HERE/last_run.log"
fails=$(grep -c "REGRESSION" "$HERE/last_run.log" || true)
proven=$(grep -cE "✅ .* proven|NEWLY PROVEN" "$HERE/last_run.log" || true)
total=${#mods[@]}
echo "Pavona module equivalence: $proven/$total proven, $fails regressions (jobs=$JOBS)"
[ "$fails" -eq 0 ]
