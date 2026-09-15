#!/usr/bin/env bash
# Per-module small peripherals set 2 (Pavona OpenTitan mbx, dma,
# spi_device) equivalence: read_uhdm vs read_slang, SAT-mitered.  Sources are
# the per-module dependency closure (scripts/periph5_srcs.py), which pulls the ACC
# RTL plus the shared prim library / base packages vendored for the TL-UL
# campaign (../pavona_tlul_equiv/rtl/{prim,tlul,pkg}).
#   ./run_periph5_equiv.sh [module...]      # default: every manifest module
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TLUL="$(cd "$HERE/../pavona_tlul_equiv" && pwd)"
ACC="$(cd "$HERE/../pavona_acc_equiv" && pwd)"
Y="$ROOT/out/current/bin/yosys"; P="$ROOT/build/uhdm2rtlil.so"
S="$ROOT/build/third_party/Surelog/bin/surelog"
# Include dirs: CSRNG-local + shared prim/tlul/base-pkg + ACC pkgs (edn/keymgr).
KMAC="$(cd "$HERE/../pavona_kmac_equiv" && pwd)"
KEYMGR="$(cd "$HERE/../pavona_keymgr_equiv" && pwd)"
INCS=(-I"$HERE/rtl/usbdev" -I"$HERE/rtl/spi_device" -I"$HERE/rtl/pkg" -I"$KMAC/rtl/kmac" -I"$KEYMGR/rtl/keymgr" -I"$TLUL/rtl/prim" -I"$TLUL/rtl/tlul" -I"$TLUL/rtl/pkg" -I"$ACC/rtl/pkg")
SINCS=(); for d in "${INCS[@]}"; do SINCS+=(-I "${d#-I}"); done   # read_slang wants "-I dir"
JOBS=${JOBS:-$(( $(nproc 2>/dev/null||echo 4)/2 ))}; [ "$JOBS" -lt 1 ]&&JOBS=1

run_one() {
  local m="$1" seq="$2" tmo="$3" want="$4"
  local w="$HERE/work/$m"; mkdir -p "$w"
  local SR; SR=$(python3 "$HERE/scripts/periph5_srcs.py" "$m")
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
  # … or when the closure's FILE LIST changed (a root added to the resolver
  # leaves every mtime untouched).
  local srcs_changed=0; [ "$(cat "$w/srcs.txt" 2>/dev/null)" != "$SR" ] && srcs_changed=1
  if [ ! -f "$w/slpp_all/surelog.uhdm" ] || [ "$S" -nt "$w/slpp_all/surelog.uhdm" ] || [ "$HERE/wrappers/flat_$m.sv" -nt "$w/slpp_all/surelog.uhdm" ] || [ -n "$newest_src" -a "$newest_src" -nt "$w/slpp_all/surelog.uhdm" ] || [ "$srcs_changed" = 1 ]; then
    echo "$SR" > "$w/srcs.txt"
    (cd "$w" && timeout 400 "$S" -parse -d uhdm -DSYNTHESIS "${INCS[@]}" -top "$top" $SR > surelog.log 2>&1)
  fi
  [ -f "$w/slpp_all/surelog.uhdm" ] || { printf "  ‼  %-30s elabfail (surelog)\n" "$m"; echo "$m elabfail"; return; }
  # Dual-clock modules (wrappers/clk_excl_<m>.txt names the two clock ports):
  # `memory_map` refuses a RAM whose write ports sit on different clocks, so
  # the RAM stayed a $mem_v2 the SAT solver has no model for ("nosat").  The
  # global-clock flow instead: `memory -nordff -nomap` keeps the read ports
  # combinational, `clk2fflogic` turns every FF (and the RAM's write ports)
  # into sampled logic under one global step, `memory_map -formal` maps the
  # now-unclocked write ports to FFs.  Both write ports hitting one address in
  # the SAME global step is a race in the RTL that memory_map resolves by port
  # ORDER — which differs between frontends (false cex) — so the miter assumes
  # the two clocks never rise in the same step (scripts/add_clk_excl.py) and
  # the SAT runs with -set-assumes.  seq counts GLOBAL steps (2 per clock).
  # A big RAM mapped to FFs is SAT-hard at any depth (spid_dpram's 1024x36:
  # no verdict in 1800 s even at seq=4; usbdev's 512x32 packet buffer: the
  # same), so `wrappers/memsize_<m>.txt` — or a `memsize` line in the
  # clk_excl file — holds `memsize <cell glob> <words>`: the $mem_v2 matching
  # the glob is shrunk to that many words on BOTH sides before mapping
  # (setparam SIZE) — a bounded-address abstraction of the RAM identical for
  # the two frontends (addresses beyond it alias no stored word); the co-sim
  # keeps the full depth.
  local MEMS='' ms=''
  for f in "$HERE/wrappers/memsize_$m.txt" "$HERE/wrappers/clk_excl_$m.txt"; do
    [ -z "$ms" ] && [ -f "$f" ] && ms=$(grep '^memsize' "$f" | head -1)
  done
  [ -n "$ms" ] && MEMS="setparam -set SIZE $(echo "$ms" | awk '{print $3}') c:$(echo "$ms" | awk '{print $2}') t:\$mem_v2 %i; "
  local FLOW='flatten; proc; opt; memory; async2sync; delete t:$check t:$assert t:$assume t:$print'
  [ -n "$MEMS" ] && FLOW="flatten; proc; opt; memory -nomap; ${MEMS}memory_map; opt; async2sync; delete t:\$check t:\$assert t:\$assume t:\$print"
  local CSTR='' SATX=''
  if [ -f "$HERE/wrappers/clk_excl_$m.txt" ]; then
    local clks; clks=$(grep -v '^memsize' "$HERE/wrappers/clk_excl_$m.txt" | head -1)
    FLOW="flatten; proc; opt; memory -nordff -nomap; ${MEMS}clk2fflogic; memory_map -formal; opt_clean; delete t:\$check t:\$assert t:\$assume t:\$print"
    CSTR="write_rtlil miter.il
!python3 $HERE/scripts/add_clk_excl.py miter.il $(for c in $clks; do printf 'in_%s ' "$c"; done)
design -reset
read_rtlil miter.il"
    # Even with the exclusion assumption the free clock inputs leave the
    # solver every interleaving (64-word RAM, seq=8: no verdict in 1800 s),
    # so the clocks follow a FIXED two-phase schedule: the first clock
    # toggles every step (rises on even steps), the second every two steps
    # (rises on 3, 7, …), any further clock (scan) is held 0.  A sys write is
    # then read back on the SPI side (and vice versa) within seq=8.
    SATX='-set-assumes'
    local ci=0 st
    for c in $clks; do
      for ((st=1; st<=seq; st++)); do
        local v=0
        if [ $ci = 0 ]; then v=$(( st % 2 == 0 ));
        elif [ $ci = 1 ]; then v=$(( (st % 4 == 3) || (st % 4 == 0) )); fi
        SATX+=" -set-at $st in_$c $v"
      done; ci=$((ci+1))
    done
  fi
  cat > "$w/miter.ys" <<EOF
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top $top
$FLOW
rename $top gold; design -stash gold
read_slang --ignore-assertions -DSYNTHESIS --single-unit --relax-enum-conversions ${SINCS[@]} $SR --top $top
hierarchy -check -top $top
$FLOW
rename $top gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
$CSTR
sat -verify -prove-asserts $SATX -seq $seq -set-init-zero miter
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
  # A memory `memory_map` refuses (two write ports on different clocks) stays
  # a $mem_v2 the SAT solver has no model for — give the module a
  # wrappers/clk_excl_<m>.txt (global-clock flow above).
  elif grep -q "No SAT model available" <<< "$out"; then got=nosat
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
  # there (an explicit `./run_periph5_equiv.sh aes_core` used to run with the
  # 300 s default and report the manifest's SAT-hard rows as unexpected).
  for a in "$@"; do
    e=$(awk -v m="$a" '$1==m && $1!~/^#/ {print $1":"$2":"$3":"$4; exit}' "$HERE/periph5_modules.txt")
    MODS+=("${e:-$a}")
  done
else
  while read -r n s t w _; do [ -n "${n:-}" ]&&[[ ! "$n" =~ ^# ]]&&MODS+=("$n:$s:$t:$w"); done < "$HERE/periph5_modules.txt"
fi
proven=0; total=0; reg=0
for e in "${MODS[@]}"; do
  IFS=: read -r m s t w <<< "$e"; s=${s:-4}; t=${t:-300}; w=${w:-proven}
  r=$(run_one "$m" "$s" "$t" "$w")
  echo "$r"|grep -qE "^  [✅❌‼]" && echo "$r"|grep -E "^  [✅❌‼]"
  got=$(echo "$r"|tail -1|awk '{print $2}')
  total=$((total+1)); [ "$got" = proven ]&&proven=$((proven+1)); [ "$got" != "$w" ]&&reg=$((reg+1))
done
echo "PERIPH5 equivalence: $proven/$total proven, $reg unexpected"
