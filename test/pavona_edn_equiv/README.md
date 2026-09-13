# Pavona EDN per-module equivalence

Entropy distribution network (OpenTitan `hw/ip/edn`), vendored UNMODIFIED from
/home/alain/pavona. Per-module `read_uhdm` vs `read_slang` SAT miter, mirroring
the HMAC / KMAC / ACC / TL-UL campaigns.

- `rtl/edn` — vendored EDN RTL (edn, edn_core, edn_main_sm, edn_ack_sm,
  edn_field_en, edn_reg_top, edn_pkg, edn_reg_pkg).
- Shares the prim library + tlul + base packages from
  `../pavona_tlul_equiv/rtl/{prim,tlul,pkg}` and csrng_pkg from
  `../pavona_acc_equiv/rtl/pkg` — nothing re-vendored.
- `./run_edn_equiv.sh [module]` — surelog → read_uhdm vs read_slang miter.
  `edn_modules.txt` = manifest.
- `scripts/edn_cosim.py <mod> [cycles] [seed]` — Verilator co-sim (RTL vs
  read_uhdm vs read_slang netlists) with the per-output ACTIVITY line and the
  `DIRECTED[mod]` stimulus table.

## Status
- **All 6 manifest modules proven** (seq=4): edn_field_en, edn_ack_sm, edn_main_sm,
  edn_core, edn_reg_top, edn.
- Co-sim (`edn_cosim.py <mod> 1000 1`): NO_DIVERGENCE everywhere; real activity
  on edn_core (csrng_cmd_o 119 / hw2reg 888 changes), edn_reg_top (tl_o 533),
  edn (tl_o 513, alert_tx_o 697), edn_field_en.  edn_ack_sm / edn_main_sm park
  in their sparse-FSM error state under random control (local_escalate_i), so
  the DIRECTED table in `scripts/edn_cosim.py` holds escalate low and the
  enable high: ack_o 412 / fifo_pop_o 110 changes, main_sm send_gencmd_o 110 /
  send_rescmd_o 100 — NO_DIVERGENCE.
