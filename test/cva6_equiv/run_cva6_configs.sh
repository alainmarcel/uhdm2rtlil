#!/usr/bin/env bash
# Whole-core CVA6 read + structural gate, once per CONFIGURATION.
#
# chipsalliance/sv-tests defines FIVE ariane/CVA6 flavours (generators/ariane)
# and our per-module and per-instance sweeps covered ONE of them.  The other
# flavours are not a different design: they are the same RTL with a different
# `*_config_pkg.sv`, and every one of those packages declares the same package
# name (`cva6_config_pkg`), so a flavour is one line of the file list.  Each
# one selects genuinely different RTL -- the HPDcache subsystem instead of the
# write-through cache, the hypervisor two-stage MMU, a 32-bit datapath with no
# FPU -- so reading one says little about the others.
#
# What this measures per config: read_uhdm elaborates the whole core, and after
# proc/flatten/opt_clean every net the SOURCE assigns has a driver.  The
# expectation per config lives in cva6_configs.txt and is a RATCHET.
#
# This is deliberately NOT a per-module SAT sweep: the whole core is a SAT
# timeout even at the default config (cva6_modules.txt), and the structural
# check is what actually catches a dropped driver.
#
# Usage: run_cva6_configs.sh [config ...]        (default: every config listed)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
YOSYS="$ROOT/out/current/bin/yosys"
PLUGIN="$ROOT/build/uhdm2rtlil.so"
SURELOG="$ROOT/build/third_party/Surelog/bin/surelog"
RTL="$HERE/rtl"
LIST="$HERE/cva6_configs.txt"
WORKROOT="$HERE/work_cfg"

if [ ! -x "$YOSYS" ] || [ ! -f "$PLUGIN" ]; then
  echo "SKIP: build the plugin first (make -j)"; exit 0
fi

cfgs=("$@")
if [ ${#cfgs[@]} -eq 0 ]; then
  mapfile -t cfgs < <(grep -vE '^\s*(#|$)' "$LIST" | awk '{print $1}')
fi

mkdir -p "$WORKROOT"
rc_all=0
printf "%-30s %-10s %-22s %s\n" CONFIG READ "UNDRIVEN NETS" VERDICT
for cfg in "${cfgs[@]}"; do
  want=$(grep -E "^\s*$cfg\s" "$LIST" | head -1 | awk '{print $2}')
  want=${want:-0}
  pkg="$RTL/core/include/${cfg}_config_pkg.sv"
  if [ ! -f "$pkg" ]; then
    printf "%-30s %-10s %-22s %s\n" "$cfg" "-" "-" "SKIP (no $cfg config package vendored)"
    continue
  fi
  work="$WORKROOT/$cfg"; mkdir -p "$work"
  # The flist names the DEFAULT config package; swap in this flavour's.
  sed -e "s|__CVA6_RTL__|$RTL|g" \
      -e "s|cv64a6_imafdc_sv39_config_pkg.sv|${cfg}_config_pkg.sv|" \
      "$HERE/cva6.flist" > "$work/cva6.f"

  if [ ! -f "$work/slpp_all/surelog.uhdm" ] || [ "$SURELOG" -nt "$work/slpp_all/surelog.uhdm" ]; then
    ( cd "$work" && timeout 2400 "$SURELOG" -parse -sverilog -mt 4 \
        -f cva6.f -top cva6 > surelog.log 2>&1 )
  fi
  if [ ! -f "$work/slpp_all/surelog.uhdm" ]; then
    printf "%-30s %-10s %-22s %s\n" "$cfg" "FAIL" "-" "surelog produced no UHDM (see $work/surelog.log)"
    rc_all=1; continue
  fi

  cat > "$work/check_undriven.ys" <<YS
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top cva6
proc
flatten
opt_clean
check
YS
  ( cd "$work" && timeout 3600 "$YOSYS" -m "$PLUGIN" check_undriven.ys > check.log 2>&1 )
  if ! grep -q "Found and reported" "$work/check.log" && \
     ! grep -q "found no problems" "$work/check.log"; then
    printf "%-30s %-10s %-22s %s\n" "$cfg" "FAIL" "-" "read_uhdm failed (see $work/check.log)"
    rc_all=1; continue
  fi
  # DISTINCT nets, not bits: one dropped driver on a wide bus is one defect.
  got=$(grep -oE "Wire \S+ \[" "$work/check.log" | sed 's/^Wire //;s/ \[$//' | sort -u | wc -l)
  if [ "$got" -eq "$want" ]; then
    v="ok"
  elif [ "$got" -lt "$want" ]; then
    v="UNEXPECTED SUCCESS ($got < $want expected) -- update cva6_configs.txt"
    rc_all=1
  else
    v="REGRESSION ($got > $want expected)"
    rc_all=1
  fi
  printf "%-30s %-10s %-22s %s\n" "$cfg" "ok" "$got (want $want)" "$v"
  grep -oE "Wire \S+ \[" "$work/check.log" | sed 's/^Wire //;s/ \[$//' | sort -u \
      | sed 's/^/      /'
done
exit $rc_all
