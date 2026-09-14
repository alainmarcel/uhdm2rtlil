#!/usr/bin/env bash
# Per-module small peripherals set 2 (Pavona OpenTitan mbx, dma,
# soc_dbg_ctrl, ascon) equivalence: read_uhdm vs read_slang, SAT-mitered.  Sources are
# the per-module dependency closure (scripts/periph3_srcs.py), which pulls the ACC
# RTL plus the shared prim library / base packages vendored for the TL-UL
# campaign (../pavona_tlul_equiv/rtl/{prim,tlul,pkg}).
#   ./run_periph3_equiv.sh [module...]      # default: every manifest module
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TLUL="$(cd "$HERE/../pavona_tlul_equiv" && pwd)"
ACC="$(cd "$HERE/../pavona_acc_equiv" && pwd)"
Y="$ROOT/out/current/bin/yosys"; P="$ROOT/build/uhdm2rtlil.so"
S="$ROOT/build/third_party/Surelog/bin/surelog"
# Include dirs: CSRNG-local + shared prim/tlul/base-pkg + ACC pkgs (edn/keymgr).
KMAC="$(cd "$HERE/../pavona_kmac_equiv" && pwd)"
INCS=(-I"$HERE/rtl/mbx" -I"$HERE/rtl/dma" -I"$HERE/rtl/soc_dbg_ctrl" -I"$HERE/rtl/ascon" -I"$HERE/rtl/pkg" -I"$TLUL/rtl/prim" -I"$TLUL/rtl/tlul" -I"$TLUL/rtl/pkg" -I"$ACC/rtl/pkg")
SINCS=(); for d in "${INCS[@]}"; do SINCS+=(-I "${d#-I}"); done   # read_slang wants "-I dir"
JOBS=${JOBS:-$(( $(nproc 2>/dev/null||echo 4)/2 ))}; [ "$JOBS" -lt 1 ]&&JOBS=1

run_one() {
  local m="$1" seq="$2" tmo="$3" want="$4"
  local w="$HERE/work/$m"; mkdir -p "$w"
  local SR; SR=$(python3 "$HERE/scripts/periph3_srcs.py" "$m")
  local top="$m"
  if [ -f "$HERE/wrappers/flat_$m.sv" ]; then
    top="${m}_flat"; SR="$SR $HERE/wrappers/flat_$m.sv"
  fi
  # spi_host_fsm / spi_host_core use `ASSERT without including prim_assert.sv
  # (only spi_host.sv includes it — the IP relies on one compilation unit), so
  # both tools get prim_assert.sv FIRST and read_slang runs --single-unit.
  SR="$TLUL/rtl/prim/prim_assert.sv $SR"
  # Re-elaborate when the Surelog binary, the wrapper OR ANY SOURCE of the
  # closure is newer than the cached UHDM (a re-vendored package was silently
  # read stale while read_slang saw the new file).
  local newest_src; newest_src=$(ls -t $SR 2>/dev/null | head -1)
  if [ ! -f "$w/slpp_all/surelog.uhdm" ] || [ "$S" -nt "$w/slpp_all/surelog.uhdm" ] || [ "$HERE/wrappers/flat_$m.sv" -nt "$w/slpp_all/surelog.uhdm" ] || [ -n "$newest_src" -a "$newest_src" -nt "$w/slpp_all/surelog.uhdm" ]; then
    (cd "$w" && timeout 400 "$S" -parse -d uhdm -DSYNTHESIS "${INCS[@]}" -top "$top" $SR > surelog.log 2>&1)
  fi
  [ -f "$w/slpp_all/surelog.uhdm" ] || { printf "  ‼  %-30s elabfail (surelog)\n" "$m"; echo "$m elabfail"; return; }
  cat > "$w/miter.ys" <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $top
flatten; proc; opt; memory; async2sync; delete t:\$check t:\$assert t:\$assume t:\$print
rename $top gold; design -stash gold
read_slang --ignore-assertions -DSYNTHESIS --single-unit --relax-enum-conversions ${SINCS[@]} $SR --top $top
hierarchy -check -top $top
flatten; proc; opt; memory; async2sync; delete t:\$check t:\$assert t:\$assume t:\$print
rename $top gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq $seq -set-init-zero miter
EOF
  local out rc; out=$( (cd "$w" && timeout "$tmo" "$Y" -m "$P" miter.ys 2>&1) ); rc=$?
  local got
  # Herestrings, not `echo | grep -q`: under `pipefail` a large $out gives
  # echo a SIGPIPE when grep -q exits early, the pipeline fails and every
  # read_slang elaboration error was reported as "timeout".  A run killed by
  # `timeout` (rc 124) has no verdict line and its read_uhdm hierarchy notes
  # ("wire … not found in hierarchical lookup") matched the error pattern.
  if grep -q "no model found: SUCCESS" <<< "$out"; then got=proven
  elif grep -q "model found: FAIL" <<< "$out"; then got=cex
  elif [ "$rc" = 124 ]; then got=timeout
  elif grep -qiE "Design elaboration failed|No such|ERROR.*read_slang|not found" <<< "$out"; then got=error
  elif grep -qiE "Interrupted|timeout|TIMEOUT" <<< "$out"; then got=timeout
  else got=timeout; fi
  local ico=✅; [ "$got" != "$want" ] && ico=❌
  printf "  %s %-30s %s (want=%s)\n" "$ico" "$m" "$got" "$want"
  echo "$m $got"
}

MODS=(); if [ $# -gt 0 ]; then
  # Named modules take their seq/timeout/want from the manifest when listed
  # there (an explicit `./run_periph3_equiv.sh aes_core` used to run with the
  # 300 s default and report the manifest's SAT-hard rows as unexpected).
  for a in "$@"; do
    e=$(awk -v m="$a" '$1==m && $1!~/^#/ {print $1":"$2":"$3":"$4; exit}' "$HERE/periph3_modules.txt")
    MODS+=("${e:-$a}")
  done
else
  while read -r n s t w _; do [ -n "${n:-}" ]&&[[ ! "$n" =~ ^# ]]&&MODS+=("$n:$s:$t:$w"); done < "$HERE/periph3_modules.txt"
fi
proven=0; total=0; reg=0
for e in "${MODS[@]}"; do
  IFS=: read -r m s t w <<< "$e"; s=${s:-4}; t=${t:-300}; w=${w:-proven}
  r=$(run_one "$m" "$s" "$t" "$w")
  echo "$r"|grep -qE "^  [✅❌‼]" && echo "$r"|grep -E "^  [✅❌‼]"
  got=$(echo "$r"|tail -1|awk '{print $2}')
  total=$((total+1)); [ "$got" = proven ]&&proven=$((proven+1)); [ "$got" != "$w" ]&&reg=$((reg+1))
done
echo "PERIPH3 equivalence: $proven/$total proven, $reg unexpected"
