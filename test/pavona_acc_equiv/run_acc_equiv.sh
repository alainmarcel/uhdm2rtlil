#!/usr/bin/env bash
# Per-module ACC (Pavona OpenTitan Asymmetric Crypto Coprocessor, OTBN-family
# bignum core) equivalence: read_uhdm vs read_slang, SAT-mitered.  Sources are
# the per-module dependency closure (scripts/acc_srcs.py), which pulls the ACC
# RTL plus the shared prim library / base packages vendored for the TL-UL
# campaign (../pavona_tlul_equiv/rtl/{prim,tlul,pkg}).
#   ./run_acc_equiv.sh [module...]      # default: every manifest module
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TLUL="$(cd "$HERE/../pavona_tlul_equiv" && pwd)"
Y="$ROOT/out/current/bin/yosys"; P="$ROOT/build/uhdm2rtlil.so"
S="$ROOT/build/third_party/Surelog/bin/surelog"
# Include dirs: ACC-local + shared prim/tlul/base-pkg (for `include`d headers).
INCS=(-I"$HERE/rtl/acc" -I"$HERE/rtl/pkg" -I"$TLUL/rtl/prim" -I"$TLUL/rtl/tlul" -I"$TLUL/rtl/pkg")
SINCS=(); for d in "${INCS[@]}"; do SINCS+=(-I "${d#-I}"); done   # read_slang wants "-I dir"
JOBS=${JOBS:-$(( $(nproc 2>/dev/null||echo 4)/2 ))}; [ "$JOBS" -lt 1 ]&&JOBS=1

run_one() {
  local m="$1" seq="$2" tmo="$3" want="$4"
  local w="$HERE/work/$m"; mkdir -p "$w"
  local SR; SR=$(python3 "$HERE/scripts/acc_srcs.py" "$m")
  local top="$m"
  if [ -f "$HERE/wrappers/flat_$m.sv" ]; then
    top="${m}_flat"; SR="$SR $HERE/wrappers/flat_$m.sv"
  fi
  if [ ! -f "$w/slpp_all/surelog.uhdm" ] || [ "$S" -nt "$w/slpp_all/surelog.uhdm" ] || [ "$HERE/wrappers/flat_$m.sv" -nt "$w/slpp_all/surelog.uhdm" ]; then
    (cd "$w" && timeout 400 "$S" -parse -d uhdm -DSYNTHESIS "${INCS[@]}" -top "$top" $SR > surelog.log 2>&1)
  fi
  [ -f "$w/slpp_all/surelog.uhdm" ] || { printf "  ‼  %-30s elabfail (surelog)\n" "$m"; echo "$m elabfail"; return; }
  cat > "$w/miter.ys" <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $top
flatten; proc; opt; memory; async2sync; delete t:\$check t:\$assert t:\$assume t:\$print
rename $top gold; design -stash gold
read_slang --ignore-assertions -DSYNTHESIS ${SINCS[@]} $SR --top $top
hierarchy -check -top $top
flatten; proc; opt; memory; async2sync; delete t:\$check t:\$assert t:\$assume t:\$print
rename $top gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq $seq -set-init-zero miter
EOF
  local out; out=$( (cd "$w" && timeout "$tmo" "$Y" -m "$P" miter.ys 2>&1) )
  local got
  if echo "$out"|grep -q "no model found: SUCCESS"; then got=proven
  elif echo "$out"|grep -q "model found: FAIL"; then got=cex
  elif echo "$out"|grep -qiE "Design elaboration failed|No such|ERROR.*read_slang|not found"; then got=error
  elif echo "$out"|grep -qiE "Interrupted|timeout|TIMEOUT"; then got=timeout
  else got=timeout; fi
  local ico=✅; [ "$got" != "$want" ] && ico=❌
  printf "  %s %-30s %s (want=%s)\n" "$ico" "$m" "$got" "$want"
  echo "$m $got"
}

MODS=(); if [ $# -gt 0 ]; then MODS=("$@"); else
  while read -r n s t w _; do [ -n "${n:-}" ]&&[[ ! "$n" =~ ^# ]]&&MODS+=("$n:$s:$t:$w"); done < "$HERE/acc_modules.txt"
fi
proven=0; total=0; reg=0
for e in "${MODS[@]}"; do
  IFS=: read -r m s t w <<< "$e"; s=${s:-4}; t=${t:-300}; w=${w:-proven}
  r=$(run_one "$m" "$s" "$t" "$w")
  echo "$r"|grep -qE "^  [✅❌‼]" && echo "$r"|grep -E "^  [✅❌‼]"
  got=$(echo "$r"|tail -1|awk '{print $2}')
  total=$((total+1)); [ "$got" = proven ]&&proven=$((proven+1)); [ "$got" != "$w" ]&&reg=$((reg+1))
done
echo "ACC equivalence: $proven/$total proven, $reg unexpected"
