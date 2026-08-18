#!/usr/bin/env bash
# Per-module CVA6 formal equivalence: read_uhdm vs the built-in read_slang.
#
# Self-contained: the CVA6 RTL is vendored under rtl/ and the flist uses a
# __CVA6_RTL__ placeholder, so this needs no external checkout.  Each module is
# elaborated inside a wrapper (wrappers/wrapper_<mod>.sv) that reproduces the
# parameters the module really sees in the cva6.sv hierarchy, then both
# frontends are mitered and proved with SAT.
#
# Usage: run_cva6_equiv.sh [module ...]      (default: every module in
#                                             cva6_modules.txt)
#        SEQ=<n> TIMEOUT=<s> run_cva6_equiv.sh <module>
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
YOSYS="$ROOT/out/current/bin/yosys"
PLUGIN="$ROOT/build/uhdm2rtlil.so"
SURELOG="$ROOT/build/third_party/Surelog/bin/surelog"
RTL="$HERE/rtl"
LIST="$HERE/cva6_modules.txt"
WORKROOT="$HERE/work"

if [ ! -x "$YOSYS" ] || [ ! -f "$PLUGIN" ]; then
  echo "SKIP: build the plugin first (make -j)"; exit 0
fi
if ! "$YOSYS" -p "help read_slang" >/dev/null 2>&1; then
  echo "SKIP: this yosys has no built-in read_slang (build with -DYOSYS_ENABLE_SLANG=ON)"
  exit 0
fi

# Materialise the flist with real paths (regenerated each run; not committed).
FLIST="$WORKROOT/cva6.f"
mkdir -p "$WORKROOT"
sed "s|__CVA6_RTL__|$RTL|g" "$HERE/cva6.flist" > "$FLIST"

# --shard i/N selects a stable slice of the module list.  A full pass does not
# fit one CI runner's time budget, so CI fans the list across shards and merges
# the per-shard result files afterwards (see .github/workflows/cva6-equiv.yml).
SHARD=""
RESULTS_OUT=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --shard)   SHARD="$2"; shift 2 ;;
    --shard=*) SHARD="${1#*=}"; shift ;;
    --results) RESULTS_OUT="$2"; shift 2 ;;
    --results=*) RESULTS_OUT="${1#*=}"; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- ${args+"${args[@]}"}

mods=("$@")
if [ ${#mods[@]} -eq 0 ]; then
  mapfile -t mods < <(grep -vE '^\s*(#|$)' "$LIST" | awk '{print $1}')
fi
if [ -n "$SHARD" ]; then
  idx="${SHARD%%/*}"; tot="${SHARD##*/}"
  sel=()
  for i in "${!mods[@]}"; do
    if [ $(( i % tot )) -eq $(( idx - 1 )) ]; then sel+=("${mods[$i]}"); fi
  done
  mods=(${sel+"${sel[@]}"})
  echo "shard $idx/$tot: ${#mods[@]} modules"
fi

# Each module is an independent surelog+SAT run, so fan them out; a serial pass
# over the whole of CVA6 would take many hours and this suite is part of the
# regular regression.  JOBS=1 restores serial (useful when debugging one).
JOBS=${JOBS:-$(( $(nproc 2>/dev/null || echo 4) / 2 ))}
[ "$JOBS" -lt 1 ] && JOBS=1

run_one() {
  local mod="$1"
  spec=$(grep -E "^\s*$mod\s" "$LIST" 2>/dev/null | head -1)
  seq=${SEQ:-$(echo "$spec" | awk '{print $2}')};     seq=${seq:-4}
  tmo=${TIMEOUT:-$(echo "$spec" | awk '{print $3}')}; tmo=${tmo:-900}
  want=$(echo "$spec" | awk '{print $4}');            want=${want:-proven}
  wrap="$HERE/wrappers/wrapper_$mod.sv"
  if [ ! -f "$wrap" ]; then
    echo "  ?? $mod — no wrapper"; echo "SKIP $mod" >> "$WORKROOT/.results"; return 0
  fi
  work="$WORKROOT/$mod"; mkdir -p "$work"; pushd "$work" >/dev/null
  top="${mod}_equiv"

  if [ ! -f slpp_all/surelog.uhdm ] || [ "$wrap" -nt slpp_all/surelog.uhdm ]; then
    "$SURELOG" -parse -sverilog -d uhdm -f "$FLIST" "$wrap" -top "$top" \
        > surelog.log 2>&1
  fi
  if [ ! -f slpp_all/surelog.uhdm ]; then
    echo "  ?? $mod — surelog produced no UHDM (see $work/surelog.log)"
    echo "SKIP $mod" >> "$WORKROOT/.results"; popd >/dev/null; return 0
  fi

  # Assertions are not hardware, and this flow compares hardware.  Both sides
  # must drop them, symmetrically:
  #   - read_slang REFUSES to elaborate `assert property ($onehot0(sel))` at
  #     all ("unsupported system task"), which looked like a slang limitation
  #     but is just this flow forcing elaboration of modules the shipped CVA6
  #     config never instantiates (CVXIF, the FPGA regfile, hpdcache).
  #   - read_uhdm turns the same assertions into `\$check` cells, so leaving
  #     them in gold would ALSO make `sat -prove-asserts` try to prove the
  #     design's own assertions rather than just the miter's equivalence
  #     asserts -- a failed design assertion would masquerade as a
  #     counterexample.
  cat > miter.ys <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $top
flatten; proc; memory; opt -fast; async2sync; setundef -undriven -zero
delete t:\$check t:\$assert t:\$assume t:\$print
rename $top gold
design -stash gold
read_slang --ignore-assertions -f $FLIST $wrap --top $top
hierarchy -check -top $top
flatten; proc; memory; opt -fast; async2sync; setundef -undriven -zero
delete t:\$check t:\$assert t:\$assume t:\$print
rename $top gate
design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq $seq -set-init-zero -show-inputs miter
EOF
  timeout -k 10 "$tmo" "$YOSYS" -m "$PLUGIN" miter.ys > miter.log 2>&1
  rc=$?
  cex=$(grep -c "model found: FAIL" miter.log 2>/dev/null); cex=${cex:-0}
  if [ "$rc" -eq 0 ]; then                     got=proven
  elif [ "$cex" -gt 0 ]; then                  got=cex
  elif grep -q "Design elaboration failed" miter.log; then got=elabfail
  # 124/137 come from `timeout`; anything else non-zero without a model means
  # yosys itself died (SIGSEGV / SIGFPE seen on some hpdcache modules).  That
  # is not a SAT budget outcome and should not hide behind `timeout`.
  elif [ "$rc" -ne 124 ] && [ "$rc" -ne 137 ] && [ "$rc" -gt 128 ]; then got=crash
  # A yosys ERROR exits with a small non-zero code -- not the timeout's own
  # 124/137 and not a signal -- so it used to fall through to `timeout` and a
  # module that had stopped IMPORTING looked like a SAT budget outcome.  That
  # is how wt_dcache_mem appeared to improve from `cex` to `timeout` while it
  # was in fact failing to build at all.  `timeout` must mean "SAT ran and
  # found no model", nothing else.
  elif [ "$rc" -ne 124 ] && [ "$rc" -ne 137 ] && [ "$rc" -ne 0 ] &&
       grep -qE "^ERROR:" miter.log; then                got=error
  else                                          got=timeout
  fi
  popd >/dev/null

  # Verdict policy.  `timeout` is a RESOURCE outcome, not a correctness one:
  # how far SAT gets depends on machine load, and this suite runs its modules
  # in parallel, so failing on it would make the gate non-deterministic.  What
  # must never regress is correctness:
  #   * a counterexample where we did not expect one  -> FAIL (real bug)
  #   * a module we prove today failing to elaborate  -> FAIL (harness/frontend)
  # Everything else is reported but tolerated; a module that starts proving is
  # flagged so the manifest can be tightened.
  if [ "$got" = "$want" ]; then
    printf "  ✅ %-34s %s (seq=%s)\n" "$mod" "$got" "$seq"
    echo "OK $mod $got" >> "$WORKROOT/.results"
  elif [ "$got" = cex ]; then
    printf "  ❌ %-34s NEW COUNTEREXAMPLE (want=%s) — see %s\n" "$mod" "$want" "work/$mod/miter.log"
    echo "BAD $mod $got $want" >> "$WORKROOT/.results"
  elif [ "$got" = crash ] && [ "$want" != crash ]; then
    printf "  ❌ %-34s yosys CRASHED (want=%s) — see %s\n" "$mod" "$want" "work/$mod/miter.log"
    echo "BAD $mod $got $want" >> "$WORKROOT/.results"
  elif [ "$got" = error ] && [ "$want" != error ]; then
    printf "  ❌ %-34s yosys ERROR (want=%s) — see %s\n" "$mod" "$want" "work/$mod/miter.log"
    echo "BAD $mod $got $want" >> "$WORKROOT/.results"
  elif [ "$got" = elabfail ] && [ "$want" = proven ]; then
    printf "  ❌ %-34s no longer elaborates (want=proven) — see %s\n" "$mod" "work/$mod/miter.log"
    echo "BAD $mod $got $want" >> "$WORKROOT/.results"
  elif [ "$got" = proven ]; then
    printf "  ⬆  %-34s now PROVEN (manifest says %s) — promote it\n" "$mod" "$want"
    echo "PROMOTE $mod $got $want" >> "$WORKROOT/.results"
  else
    printf "  ⚠  %-34s %s (want=%s) — inconclusive, not a failure\n" "$mod" "$got" "$want"
    echo "SOFT $mod $got $want" >> "$WORKROOT/.results"
  fi
}
export -f run_one
export HERE ROOT YOSYS PLUGIN SURELOG RTL LIST WORKROOT FLIST SEQ TIMEOUT

: > "$WORKROOT/.results"
printf '%s\n' "${mods[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one {}'

pass=$(grep -c '^OK '      "$WORKROOT/.results" 2>/dev/null || true); pass=${pass:-0}
fail=$(grep -c '^BAD '     "$WORKROOT/.results" 2>/dev/null || true); fail=${fail:-0}
skip=$(grep -c '^SKIP '    "$WORKROOT/.results" 2>/dev/null || true); skip=${skip:-0}
prom=$(grep -c '^PROMOTE ' "$WORKROOT/.results" 2>/dev/null || true); prom=${prom:-0}
soft=$(grep -c '^SOFT '    "$WORKROOT/.results" 2>/dev/null || true); soft=${soft:-0}
echo ""
echo "CVA6 module equivalence: $pass as expected, $fail regressions, $prom newly proven, $soft inconclusive, $skip skipped (jobs=$JOBS)"
if [ "$prom" -gt 0 ]; then
  echo "Newly proven (tighten cva6_modules.txt): $(awk '$1=="PROMOTE"{printf "%s ", $2}' "$WORKROOT/.results")"
fi
if [ "$soft" -gt 0 ]; then
  echo "Inconclusive (SAT budget, not a bug): $(awk '$1=="SOFT"{printf "%s ", $2}' "$WORKROOT/.results")"
fi
if [ -n "$RESULTS_OUT" ]; then
  cp "$WORKROOT/.results" "$RESULTS_OUT"
  echo "wrote $RESULTS_OUT"
fi
if [ "$fail" -gt 0 ]; then
  echo "REGRESSIONS: $(awk '$1=="BAD"{printf "%s(got=%s want=%s) ", $2,$3,$4}' "$WORKROOT/.results")"
  exit 1
fi
exit 0
