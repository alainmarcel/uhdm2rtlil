#!/usr/bin/env bash
# Vendor the upstream lowRISC OpenTitan RTL this family sweeps, refreshable
# from a checkout:
#
#   ./vendor_opentitan.sh [~/ext/opentitan]
#
# DELIBERATELY SEPARATE from test/pavona_equiv.  Pavona is a hard FORK of
# OpenTitan and its RTL has diverged substantially -- of the 120 files the two
# trees share across aes/kmac/hmac/csrng/edn/keymgr/entropy_src/lc_ctrl, only
# 66 are byte-identical; 51 differ (kmac_app.sv by 1531 lines, csrng_core.sv by
# 757, aes_control_fsm.sv by 494).  Proving the pavona copy says nothing about
# upstream, so nothing here is shared with that family: its own vendored
# sources, its own manifest, its own sweep.
#
# Scope: the OTBN dependency closure.  OTBN (OpenTitan's 256-bit bignum crypto
# accelerator) does not exist in pavona at all, so it is entirely new coverage.
# Every cross-IP dependency is package-only, which keeps the set self-contained.
set -euo pipefail
SRC="${1:-$HOME/ext/opentitan}"
HERE="$(cd "$(dirname "$0")" && pwd)"
HW="$SRC/hw"

[ -d "$HW/ip/otbn/rtl" ] || {
  echo "no OpenTitan checkout at $SRC (expected $HW/ip/otbn/rtl)" >&2
  exit 1
}
want="$(cat "$HERE/opentitan.commit" 2>/dev/null || true)"
got="$(cd "$SRC" && git rev-parse HEAD)"
[ -z "$want" ] || [ "$want" = "$got" ] || {
  echo "WARNING: checkout is at $got, opentitan.commit pins $want" >&2
}

rm -rf "$HERE/rtl"
mkdir -p "$HERE/rtl/otbn" "$HERE/rtl/prim" "$HERE/rtl/tlul" "$HERE/rtl/pkg"

cp "$HW"/ip/otbn/rtl/*.sv                "$HERE/rtl/otbn/"
while read -r f; do
  [ -n "$f" ] || continue
  cp "$HW/ip/tlul/rtl/$f" "$HERE/rtl/tlul/"
done < "$HERE/tlul_files.txt"
# Only the prims in the dependency CLOSURE (prim_files.txt), not the whole
# directory: hw/ip/prim/rtl carries blocks with their own unmet dependencies
# (prim_ascon_duplex needs prim_ascon_pkg, prim_flash needs DV assert macros),
# and feeding those to the frontends just breaks elaboration.  Same for tlul.
# prim_generic supplies the implementations of the abstract technology prims;
# the asap7 / xilinx variants are deliberately not vendored.
while read -r f; do
  [ -n "$f" ] || continue
  if   [ -f "$HW/ip/prim/rtl/$f" ];         then cp "$HW/ip/prim/rtl/$f"         "$HERE/rtl/prim/"
  elif [ -f "$HW/ip/prim_generic/rtl/$f" ]; then cp "$HW/ip/prim_generic/rtl/$f" "$HERE/rtl/prim/"
  else echo "WARNING: prim source not found: $f" >&2
  fi
done < "$HERE/prim_files.txt"
# NB prim_sparse_fsm_flop is in prim_files.txt but is NOT reachable from the
# module graph: it is instantiated only by the `PRIM_FLOP_SPARSE_FSM macro, so
# a closure computed from module/package references misses it and four OTBN
# FSM modules fail to elaborate with "unknown module 'prim_sparse_fsm_flop'".
# Any future macro-instantiated prim needs the same explicit entry.
#
# Include-only sources: OpenTitan keeps its assertion / flop macros in files
# that declare no module or package (prim_assert.sv, prim_flop_macros.sv and
# the .svh set), so the module-graph closure never names them -- but every
# `include "prim_assert.sv"` fails without them ("Unknown macro" x479).
cp "$HW"/ip/prim/rtl/*.svh               "$HERE/rtl/prim/" 2>/dev/null || true
cp "$HW"/ip/prim/rtl/prim_assert.sv      "$HERE/rtl/prim/"
cp "$HW"/ip/prim/rtl/prim_flop_macros.sv "$HERE/rtl/prim/"
# Cross-IP dependencies -- ALL package-only.
for p in ip/csrng/rtl/csrng_pkg.sv ip/csrng/rtl/csrng_reg_pkg.sv \
         ip/edn/rtl/edn_pkg.sv ip/entropy_src/rtl/entropy_src_pkg.sv \
         ip/keymgr/rtl/keymgr_pkg.sv ip/keymgr/rtl/keymgr_reg_pkg.sv \
         ip/keymgr_dpe/rtl/keymgr_dpe_pkg.sv \
         ip/kmac/rtl/kmac_pkg.sv ip/kmac/rtl/sha3_pkg.sv \
         ip/lc_ctrl/rtl/lc_ctrl_pkg.sv ip/lc_ctrl/rtl/lc_ctrl_reg_pkg.sv \
         ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv \
         ip/otp_ctrl/rtl/otp_ctrl_pkg.sv \
         top_earlgrey/rtl/top_pkg.sv; do
  cp "$HW/$p" "$HERE/rtl/pkg/"
done

echo "$got" > "$HERE/opentitan.commit"
printf 'vendored %s .sv files from %s @ %s\n' \
  "$(find "$HERE/rtl" -name '*.sv' | wc -l)" "$SRC" "$got"
