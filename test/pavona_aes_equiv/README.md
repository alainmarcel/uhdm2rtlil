# Pavona AES per-module equivalence

OpenTitan AES accelerator (`hw/ip/aes`, AES-128/192/256 ECB/CBC/CFB/OFB/CTR,
two-share domain-oriented masking) from `/home/alain/pavona`, vendored
UNMODIFIED under `rtl/aes` (all 37 files); prim / tlul / base packages come
from `../pavona_tlul_equiv`, edn / keymgr / lc packages from
`../pavona_acc_equiv`.  Per-module `read_uhdm` vs `read_slang` SAT miter plus a
3-way Verilator co-sim (RTL vs read_uhdm vs read_slang), same layout as the
KMAC / HMAC / EDN / CSRNG campaigns.  Default parameters are the shipped ones:
**SecMasking=1 (two shares) + SecSBoxImpl=SBoxImplDom** everywhere the module
has them.

- `./run_aes_equiv.sh [module…]` — surelog → read_uhdm vs read_slang miter
  (`aes_modules.txt` = manifest: module, seq, timeout, want; named modules take
  their manifest settings).
- `scripts/aes_cosim.py <module> [cycles] [seed]` — 3-way co-sim with the
  per-output ACTIVITY line.  `CS_TRACE=1` records `work/<mod>/cs.vcd`.
- `scripts/cs_trace_prep.py` + `scripts/cs_vcd_diff.py` — earliest-internal-
  divergence tooling (see *Localizing*).
- `wrappers/flat_<mod>.sv` — `<mod>_flat` tops: two-share unpacked-array ports
  flattened elem0@LSB (read_uhdm and read_slang flatten unpacked PORTS in
  opposite element order, so a bare multi-element unpacked port can never
  miter), parameter variants (`_m` = SecMasking=1), and `aes_wrap_dut` /
  `prim_lfsr_nl` wrapper-only tops.

## Status

- **36 manifest rows, 34 formally proven** (seq=4, read_uhdm vs read_slang):
  the full `aes` IP top, `aes_core`, `aes_cipher_core` (masked, DOM), the
  control / cipher-control / counter FSMs and their `_p` / `_n` sparsified
  wrappers, `aes_control`, `aes_ctr`, `aes_ctrl_reg_shadowed`, `aes_reg_top`,
  `aes_key_expand` (+ `_m`: SecMasking=1/DOM), `aes_sub_bytes` /
  `aes_reduced_round` (DOM), the LUT / Canright / Canright-masked-noreuse /
  DOM S-boxes, ShiftRows / MixColumns, `aes_sel_buf_chk`, `aes_reg_status`,
  `aes_prng_clearing` + `prim_lfsr_nl`, and the self-driving `aes_wrap_dut`.
- 2 rows are SAT-hard and marked `timeout`, adjudicated by the co-sim:
  `aes_sbox_canright_masked` (NO_DIVERGENCE) and `aes_prng_masking`
  (read_uhdm == RTL; **read_slang diverges** from the RTL on `data_o` from
  cycle 0 — a slang bug, not ours).
- Co-sim (400 cycles, seed 1): **35 / 36 NO_DIVERGENCE** with real activity
  (aes_wrap_dut's `aes_output` = the ciphertext at cycle ~139, `aes` tl_o 172
  changes, aes_key_expand key_o 400, aes_ctr ctr_o 400); the 36th is the
  read_slang divergence above.
- `aes_prng_clearing` and `prim_lfsr_nl` need chipsalliance/Surelog#4173
  (bug 3 below); the submodule is bumped to that merge (319e32763f).

## The deep test: `aes_wrap_dut`

OpenTitan's `aes_wrap` is a self-driving SCA/FPGA wrapper: a TL-UL master FSM
configures the core, loads key / IV / plaintext through the register file,
waits for idle and reads the ciphertext back — an end-to-end encryption in
~140 cycles under the co-sim.  It is the only row that exercises the assembled
IP the way software does (the random-stimulus co-sim of `aes` / `aes_core`
never programs a key), and it caught two bugs every sub-module miter had
"proven" away, because the sub-module proofs start from the all-zero state
(`-set-init-zero`) which for OpenTitan's sparse FSMs is an INVALID state — the
proof explores the error branch only.  (`work/<mod>/miter_rst.ys` — `sat …
-set-at 1 in_rst_ni 0 -seq 8..10` — is the reset-aware variant used while
debugging.)

The vendored `aes_wrap` itself drives `h2d_intg.a_user.data_intg` twice
(`tlul_cmd_intg_gen`'s whole-struct output and its own `prim_secded` encoder
concat); both frontends' netlists carry the 7-bit conflict (`check`: 7
problems) and Verilator resolves the two continuous drivers by statement
order, so the co-sim diverged for a reason that is the wrapper's, not the
frontend's.  `wrappers/flat_aes_wrap_dut.sv` is that wrapper minus the extra
encoder (`tlul_cmd_intg_gen` already generates data_intg); it is the manifest
row.

## Bugs found (all fixed)

1. **Packed arrays of an ENUM typedef** (`sp2v_e [N-1:0]`, aes_ctr /
   aes_control): staged at ONE bit per element wherever the geometry came from
   a `logic_typespec` only — function formal / local / return
   (`aes_rev_order_sp2v`: `ctr_we_o` read 0x000024 instead of 0x924924), the
   var_select typespec walk (element width now pushed as the innermost dim),
   and the unpacked-element path (`key_init_we_o[s][i] = sp2v_e'(…)` on
   `sp2v_e [NumRegsKey-1:0] key_init_we_o [NumSharesKey]`, whose Surelog
   element is a `packed_array_var` carrying the packed dims itself).
2. **A generate-scope localparam dropped from a multi-range typedef**
   (`typedef logic [NumSboxes-1:0][LfsrIdxDw-1:0] matrix_col_t` in
   prim_lfsr's `gen_out_non_linear`): ExprEval sized it 6 instead of 96 with
   `invalidValue` clear; the ranges are now folded through the importer first.
3. **Surelog** (chipsalliance/Surelog#4173): a PARAMETER-named streaming
   slice size `{<<LfsrIdxDw{col}}` parses as a `simple_type` and was compiled
   as `$bits(<non-type>)` = 0 → a full bit reversal instead of 6-bit slices —
   prim_lfsr's PRINCE S-box input indices were scrambled, and with them
   aes_prng_clearing.  `prim_lfsr_nl` (prim_lfsr exactly as aes_prng_clearing
   configures it: GAL_XOR 64, StatePerm, NonLinearOut=1 — the only OpenTitan
   user of that layer) is a manifest row so this stays covered.
4. **Unpacked array declared in a generate block and written only through an
   instance output CONCAT actual** (aes_core's
   `prim_buf … .out_o({state_done_buf[1], state_done_buf[0]})`): the
   instance-written-array scans only recognised a bare `a[i]` actual, so the
   array became a writer-less `$memory` whose `$memrd` data wires the instance
   output was wired onto — both masked state shares read 0 and the ciphertext
   XORed to 0.
5. **Whole-array reset + two-index element writes in one always_ff**
   (`key_init_q <= '{default:'0}` + `key_init_q[s][i] <= key_init_d[s][i]`,
   aes_core's key_init_reg): the async-reset assignment path had no
   `var_select` case, the element write landed on the alias wire `\q[s]` and
   the sync update overwrote it — every key share stayed 0 and the ciphertext
   was wrong (`120ee6a2` instead of `a2bdb42b`).

Internal tests: `func_packed_enum_array_reverse`,
`enum_array_unpacked_elem_write`, `genscope_func_typedef_multirange`,
`genscope_array_inst_concat_write`,
`ff_whole_array_reset_varselect_elem_write`, `genscope_func_stream_slice_param`;
Surelog `tests/StreamSliceParam`.

## Localizing a divergence in an assembled top

`CS_TRACE=1 scripts/aes_cosim.py <mod> 160 1` writes `work/<mod>/cs.vcd`
(Verilator `--trace` crashes on the long bracketed escaped identifiers of a
flattened yosys netlist — `scripts/cs_trace_prep.py` renames them to short
ids with a map, `cs_vcd_diff.py` restores the paths).  Then in `work/<mod>`:

```
python3 ../../scripts/cs_vcd_diff.py cs.vcd 60 --sample 10000 4999          # vs RTL, sampled just before each posedge
python3 ../../scripts/cs_vcd_diff.py cs.vcd 60 --ref gate --sample 10000 4999   # read_uhdm vs read_slang netlists
python3 ../../scripts/cs_vcd_diff.py cs.vcd --at 674999 --grep 'u_aes_core\.[a-z_0-9]+$'   # snapshot, DIFF-flagged
```

Sample BEFORE the edge and read the netlist-vs-netlist diff first: yosys's
`opt_dff` rewrites `sel ? new : q` feedback muxes into enable flops and marks
the hold input don't-care (`_ns` / `d_i` wires read 0), and the two frontends'
opposite unpacked-port flattening makes every `[NumShares]` bus look
different against the RTL — both flood a naive diff.  On a divergence, run
`check` on BOTH netlists first: a conflict present on both sides is the DUT's
own multi-driver (see aes_wrap above).
