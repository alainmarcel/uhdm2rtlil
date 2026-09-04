#!/usr/bin/env bash
# Vendor the Pavona (https://github.com/pavona/pavona) Ibex core RTL under
# rtl/, refreshable from an upstream checkout:
#
#   ./vendor_pavona.sh [~/pavona]
#
# Pavona's core processor is lowRISC Ibex at the security-hardened
# OpenTitan-style configuration (see wrappers/pavona_ibex_params.svh):
# RV32IMCB (RV32BOTEarlGrey), RV32MSingleCycle, Zca/Zcb/Zcmp, PMP x16,
# SecureIbex + lockstep, ICache + ECC + scramble, WritebackStage,
# BranchTargetALU.  We vendor:
#   rtl/ibex/  — hw/vendor/lowrisc_ibex/rtl (the core proper)
#   rtl/prim/  — the technology-independent prims (hw/ip/prim/rtl) the core
#                instantiates, plus the prim_generic implementations of the
#                abstract technology prims (buf/flop/clock/ram).
set -euo pipefail
SRC="${1:-$HOME/pavona}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -d "$SRC/hw/vendor/lowrisc_ibex/rtl" ] || {
  echo "no Pavona checkout at $SRC" >&2; exit 1; }

rm -rf "$HERE/rtl/ibex" "$HERE/rtl/prim"
mkdir -p "$HERE/rtl/ibex" "$HERE/rtl/prim"

cp "$SRC"/hw/vendor/lowrisc_ibex/rtl/*.sv "$HERE/rtl/ibex/"

# Tech-independent prims + packages the core (transitively) needs.
for f in prim_assert.sv prim_assert_dummy_macros.svh \
         prim_assert_standard_macros.svh prim_assert_sec_cm.svh \
         prim_flush_macros.svh \
         prim_util_pkg.sv prim_secded_pkg.sv prim_cipher_pkg.sv \
         prim_mubi_pkg.sv prim_count_pkg.sv \
         prim_count.sv prim_lfsr.sv prim_ram_1p_scr.sv \
         prim_secded_inv_39_32_dec.sv prim_secded_inv_39_32_enc.sv \
         prim_prince.sv prim_present.sv prim_subst_perm.sv \
         prim_onehot_check.sv prim_mubi4_dec.sv prim_mubi4_sender.sv \
         prim_sec_anchor_buf.sv prim_sec_anchor_flop.sv; do
  src="$SRC/hw/ip/prim/rtl/$f"
  [ -f "$src" ] && cp "$src" "$HERE/rtl/prim/" || echo "  (skip $f)"
done

# Generic implementations of the abstract technology prims.
for f in prim_pkg.sv prim_ram_1p_pkg.sv prim_ram_1p.sv prim_buf.sv \
         prim_flop.sv prim_flop_en.sv prim_flop_2sync.sv \
         prim_clock_mux2.sv prim_clock_gating.sv prim_xor2.sv \
         prim_and2.sv; do
  src="$SRC/hw/ip/prim_generic/rtl/$f"
  [ -f "$src" ] && cp "$src" "$HERE/rtl/prim/" || echo "  (skip generic $f)"
done

echo "vendored: $(ls "$HERE/rtl/ibex" | wc -l) ibex files," \
     "$(ls "$HERE/rtl/prim" | wc -l) prim files" \
     "(pavona @ $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo '?'))"
