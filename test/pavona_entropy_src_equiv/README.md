# Pavona entropy_src per-module equivalence

OpenTitan entropy source (`hw/ip/entropy_src`: noise-source health tests —
repetition count, adaptive proportion, bucket, Markov — the SHA-3
conditioner, FIFOs and the software observe / firmware-override paths) from
`/home/alain/pavona`, vendored UNMODIFIED under `rtl/entropy_src` (all 18
files).  The conditioner instantiates the KMAC campaign's `sha3`
(`../pavona_kmac_equiv/rtl/kmac`); prim / tlul / base packages come from
`../pavona_tlul_equiv`, edn / csrng / lc packages from
`../pavona_acc_equiv`.  Per-module `read_uhdm` vs `read_slang` SAT miter plus
the 3-way Verilator co-sim, same layout as the AES / CSRNG campaigns
(`run_entropy_src_equiv.sh`, `entropy_src_modules.txt`,
`scripts/entropy_src_cosim.py` with `CS_TRACE=1`, `scripts/cs_vcd_diff.py`).

## Status

- **15 manifest rows, 15 formally proven** (seq=4, read_uhdm vs read_slang):
  the `entropy_src` top and `entropy_src_core` (1800 s each — the SHA-3
  conditioner is inside), `entropy_src_reg_top`, the main / ack state
  machines, the four health tests (repcnt, repcnts, adaptp, bucket, markov),
  the counter / watermark / field-enable / enable-delay helpers, and
  `entropy_src_drv`.
- Co-sim (400 cycles, seed 1): **15 / 15 NO_DIVERGENCE**.  The random co-sim
  of the two tops never enables the module (rng_enable_o / hw_if_o never
  move), so `wrappers/flat_entropy_src_drv.sv` is the deep test: a TL-UL
  master FSM writes CONF (fips_enable, entropy_data_reg_enable),
  ENTROPY_CONTROL (es_type = bypass the conditioner, es_route = software),
  MODULE_ENABLE, then polls ENTROPY_DATA; the co-sim's random `rng_bits_i`
  is the noise source (`rng_valid_i` forced high by the DIRECTED table, so a
  96-sample bypass window fills every ~100 cycles).  Under read_uhdm it reads
  the same 4 entropy words in 600 cycles as the RTL and read_slang do.
- `check` (flatten; proc; opt_clean) reports 0 problems on both tops.
- No frontend bug this campaign — the five reader fixes of the AES campaign
  (enum packed arrays, generate-scope typedef widths, concat-written
  generate-scope arrays, whole-array reset element writes) were already in.

Note: `entropy_src_core` instantiates the KMAC campaign's `sha3`; the search
roots include `../pavona_kmac_equiv/rtl/kmac` (without it the tops
elaborate with a 1-bit black-box `sha3` and every read of the conditioner is
X).
