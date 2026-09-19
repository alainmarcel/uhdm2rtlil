# Upstream OpenTitan equivalence (`test/opentitan_equiv/`)

Per-module `read_uhdm` vs `read_slang` SAT miters, plus a three-way Verilator
co-sim, for **upstream [lowRISC/OpenTitan](https://github.com/lowRISC/opentitan)**
pinned at the commit in `opentitan.commit`.

## Why this is separate from `test/pavona_equiv/`

Pavona is a hard **fork** of OpenTitan and its RTL has diverged substantially.
Measured across the IP the two trees share
(`aes`, `kmac`, `hmac`, `csrng`, `edn`, `keymgr`, `entropy_src`, `lc_ctrl`):

| pavona files | byte-identical to upstream | different | pavona-only |
|---|---|---|---|
| 120 | **66** | **51** | 3 |

…and the differences are not cosmetic — `kmac_app.sv` differs by 1531 lines,
`entropy_src_reg_top.sv` by 927, `csrng_core.sv` by 757, `aes_control_fsm.sv`
by 494.  **A pavona verdict is not an upstream verdict**, so this family shares
nothing with that one: its own vendored sources, manifest, runner and co-sim
harness.

## Layout

| path | what |
|---|---|
| `opentitan.commit` | the upstream commit the vendored RTL came from |
| `vendor_opentitan.sh` | re-vendors `rtl/` from a checkout (`./vendor_opentitan.sh ~/ext/opentitan`) |
| `prim_files.txt`, `tlul_files.txt` | the dependency closure to vendor — **not** the whole directory |
| `rtl/{otbn,prim,tlul,pkg}` | vendored sources (122 files) |
| `opentitan_modules.txt` | per-module manifest + expected verdict (shrink-only ratchet) |
| `run_opentitan_equiv.sh` | the miter runner (parallel, `JOBS=`) |
| `scripts/adjudicate.py` | per-module Verilator co-sim: RTL vs read_uhdm vs read_slang |

## Scope

First IP is **OTBN**, OpenTitan's 256-bit bignum crypto accelerator, which does
not exist in the pavona tree at all — so all 32 rows are new coverage.

Current measured baselines (first full sweep):

```
OpenTitan module equivalence: 23/32 proven
  23 proven | 5 cex | 3 timeout | 1 error
```

- **5 `cex`** — `otbn_instruction_fetch`, `otbn_mac_bignum`,
  `otbn_mac_bignum_fsm`, `otbn_mai`, `otbn_reg_top`.  Genuine
  `read_uhdm != read_slang` counterexamples on RTL no other family exercises:
  real frontend bugs to work, recorded rather than hidden.
- **3 `timeout`** — `otbn_alu_bignum`, `otbn_vec_multiplier`,
  `otbn_vec_shifter`.  SAT capacity on 256-bit datapaths, not mismatches.

## Gotchas found while wiring this up

1. **Do not feed all of `hw/ip/prim/rtl`.**  It carries blocks with their own
   unmet dependencies (`prim_ascon_duplex` needs `prim_ascon_pkg`, `prim_flash`
   needs DV assert macros) and elaboration dies.  Vendor the closure only.
2. **The closure must be seeded by hand for macro-instantiated modules.**
   `prim_sparse_fsm_flop` is instantiated *only* by the `PRIM_FLOP_SPARSE_FSM`
   macro, so a module-graph closure never names it — four OTBN FSM modules
   failed with `unknown module 'prim_sparse_fsm_flop'` until it was added
   explicitly.
3. **Include-only files are invisible to a module-graph closure.**
   `prim_assert.sv` and `prim_flop_macros.sv` declare no module or package;
   without them you get ~479 "Unknown macro" errors.
4. **OpenTitan relies on compilation-unit scope for its macros.**
   `otbn_kmac_if.sv` uses `` `ASSERT `` / `` `PRIM_FLOP_SPARSE_FSM `` with no
   `` `include `` of its own, so the macro files must lead the source list…
5. **…and `read_slang` needs `--single-unit`**, because it compiles each file
   as its own unit by default and otherwise reports the same unknown macros.

## Running

```bash
cd test/opentitan_equiv
JOBS=6 ./run_opentitan_equiv.sh              # whole manifest
JOBS=6 ./run_opentitan_equiv.sh otbn_stack   # one module
python3 scripts/adjudicate.py otbn_stack 200 1   # co-sim one module

cd ../ && python3 core_sweep.py opentitan --cycles 300 --jobs 4   # full table
```
