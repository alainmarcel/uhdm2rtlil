#!/usr/bin/env bash
# Per-module TL-UL (Pavona OpenTitan bus) equivalence: read_uhdm vs read_slang,
# SAT-mitered.  Sources are the per-module dependency closure (scripts/tlul_srcs.py).
#   ./run_tlul_equiv.sh [module...]     # default: every manifest module
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
Y="$ROOT/out/current/bin/yosys"; P="$ROOT/build/uhdm2rtlil.so"
S="$ROOT/build/third_party/Surelog/bin/surelog"
PRIM="$HERE/rtl/prim"; TLUL="$HERE/rtl/tlul"
JOBS=${JOBS:-$(( $(nproc 2>/dev/null||echo 4)/2 ))}; [ "$JOBS" -lt 1 ]&&JOBS=1

run_one() {
  local m="$1" seq="$2" tmo="$3" want="$4"
  local w="$HERE/work/$m"; mkdir -p "$w"
  local SR; SR=$(python3 "$HERE/scripts/tlul_srcs.py" "$m")
  # 1. surelog (re-run if uhdm missing or surelog newer)
  if [ ! -f "$w/slpp_all/surelog.uhdm" ] || [ "$S" -nt "$w/slpp_all/surelog.uhdm" ]; then
    (cd "$w" && timeout 300 "$S" -parse -d uhdm -DSYNTHESIS -I"$PRIM" -I"$TLUL" -top "$m" $SR > surelog.log 2>&1)
  fi
  [ -f "$w/slpp_all/surelog.uhdm" ] || { printf "  ‼  %-28s elabfail (surelog)\n" "$m"; echo "$m elabfail"; return; }
  cat > "$w/miter.ys" <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $m
flatten; proc; delete t:\$check t:\$assert t:\$assume t:\$print
rename $m gold; design -stash gold
read_slang --ignore-assertions -DSYNTHESIS -I $PRIM -I $TLUL $SR --top $m
hierarchy -check -top $m
flatten; proc; delete t:\$check t:\$assert t:\$assume t:\$print
rename $m gate; design -stash gate
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
  printf "  %s %-28s %s (want=%s)\n" "$ico" "$m" "$got" "$want"
  echo "$m $got"
}
export -f run_one; export HERE ROOT Y P S PRIM TLUL
MODS=(); if [ $# -gt 0 ]; then MODS=("$@"); else
  while read -r n s t w _; do [ -n "${n:-}" ]&&[[ ! "$n" =~ ^# ]]&&MODS+=("$n:$s:$t:$w"); done < "$HERE/tlul_modules.txt"
fi
proven=0; total=0; reg=0
for e in "${MODS[@]}"; do
  IFS=: read -r m s t w <<< "$e"; s=${s:-4}; t=${t:-300}; w=${w:-proven}
  r=$(run_one "$m" "$s" "$t" "$w"); echo "$r"|grep -q "^  " && echo "$r"|head -1
  got=$(echo "$r"|tail -1|awk '{print $2}')
  total=$((total+1)); [ "$got" = proven ]&&proven=$((proven+1)); [ "$got" != "$w" ]&&reg=$((reg+1))
done
echo "TL-UL equivalence: $proven/$total proven, $reg unexpected"
