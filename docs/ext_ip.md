# External IP sweeps (`test/ext_ip/`)

Manifest-driven per-module sweeps of external SystemVerilog / Verilog
repositories, on top of the same three checks the core-IP rows use: formal
equivalence read_uhdm vs `read_slang` (SAT miter from reset), a structural
opt-check (undriven nets after `read_uhdm`), and Verilator co-simulation of
both netlists against the behavioural RTL (`test/netlist_cosim.py`).  Nothing
is vendored: each family's repositories are shallow-cloned at a pinned commit
(`$EXT_IP_ROOT`, default `~/ext` on a developer machine, `test/ext_ip/repos/`
in CI).

Run one family locally:

```bash
cd test
python3 core_sweep.py common_cells --jobs 2 --cycles 300   # any family below
python3 ext_ip/ext_flow.py hdmi --survey                   # elaborate only (first pass)
python3 ext_ip/ext_flow.py axi --list                      # module list
```

The nightly [Sweep external IP](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml)
workflow runs every family below as one sweep job and publishes the per-module
table to the run's step summary.

## Families

| Family | Repository | Modules | First survey (elaborate with read_uhdm) | Notes |
|--------|------------|--------:|------------------------------------------|-------|
| `common_cells` | [pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) (+ tech_cells_generic) | 126 | 121 / 126 read; **110 / 126 formally proven, 109 co-sim PASS** in the first full run | 2 reader crashes (`cc_cb_filter`, `cc_hash_block`: constant-function permutation tables), `cc_sub_per_hash` / `cc_id_queue` / `cc_mem_to_banks*` differ, 4 `*_clearable` CDC modules read_slang-only failures, 1 recursive instantiation |
| `axi` | [pulp-platform/axi](https://github.com/pulp-platform/axi) | 108 | 87 / 108 read | reader assertion on the `axi_burst_*` family; most `*_intf` wrappers fail in read_slang (interface ports) |
| `cve2` | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) | 23 | 23 / 23 read | OpenHW CVE2 (2-stage RV32 core, Ibex lineage) |
| `cvw` | [openhwgroup/cvw](https://github.com/openhwgroup/cvw) | 234 | 211 / 234 read | CORE-V Wally; most modules take `parameter cvw_t P` with no default, so read_slang refuses them standalone — the SoC top needs a config-package wrapper |
| `verilog-ethernet` | [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) | 129 | 125 / 129 read | Verilog-2001 corpus (+ its axis library) |
| `verilog-pcie` | [alexforencich/verilog-pcie](https://github.com/alexforencich/verilog-pcie) (+ verilog-axis) | 93 | 80 / 93 read | `dma_psdpram*` "missing edge-sensitive event", several DMA / PTile modules fail to read |
| `hdmi` | [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | 10 | 9 / 10 read | top `hdmi` out-of-range bit-select on read; `packet_picker` 62k undriven (partially assigned `headers` table, read_slang fails too) |

"read" = Surelog elaborates and `read_uhdm` + `hierarchy -check` succeed; the
nightly table adds the miter verdict, the opt-check and the co-sim result per
module.  The first survey findings above are **tracked, not yet fixed** — the
point of the sweep is to keep the counts moving in the open.

## Not duplicated here

- **Ibex** — `test/ibex/` (own sweep) and the Pavona hardened variant.
- **CVA6 and its HPDcache** — `test/cva6_equiv/` (own sweep; the HPDcache
  modules are part of it).
- **OpenTitan IP blocks** — the Pavona families in [pavona_sweep.md](pavona_sweep.md)
  are the OpenTitan-derived IPs; OpenTitan itself is planned as a third full
  chip (`top_earlgrey`) through the `test/pavona_chips/` flow.
- **snitch_cluster / cheshire** (PULP) need their Bender dependency sets
  fetched before a manifest makes sense; **XiangShan** is generated SystemVerilog
  and is deferred.

## Manifest

`test/ext_ip/<family>.json`:

```json
{"repos": [{"url": "...", "commit": "abc1234", "dir": "name", "submodules": false}],
 "roots": ["name/src/*.sv"], "incdirs": ["name/include"], "defines": ["SYNTHESIS"],
 "modules": "auto", "exclude": ["_tb$"], "only_prefix": "axi_",
 "seq": 4, "timeout": 300, "want": "proven"}
```

`ext_flow.py` computes each module's dependency closure by an identifier scan
over the roots (packages first), runs Surelog with `-top <module>`, then the
three checks, and writes `work/<family>/rows.json` in `core_sweep.py`'s row
schema; `core_sweep.py <family>` fetches the repositories, runs it (sharded
runs take every N-th module) and renders the table.
