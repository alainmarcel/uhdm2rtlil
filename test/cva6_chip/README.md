# CVA6 full core, per instantiation

`scripts/chip_flow.py` sweeps the CVA6 core the way `test/pavona_chips` and
`test/caliptra_chip` sweep their tops:

1. **Elaborate once.** Surelog on `test/cva6_equiv/cva6.flist` with
   `-top cva6` (`cva6.sv`'s parameter defaults *are* the chip configuration,
   `build_config(cva6_config_pkg::cva6_cfg)`), then `read_uhdm` and
   `read_slang --keep-hierarchy`, both written as hierarchical RTLIL
   (`work/cva6_uhdm_hier.il`, `work/cva6_slang_keephier.il`).
2. **Enumerate every instance at every level** of both hierarchies and pair
   them by instance path.  The pairing key drops the number of unnamed
   generate blocks (`genblk3` on the read_uhdm side is `genblk1` on the
   read_slang side, which numbers only the elaborated arms).
3. **One miter per distinct parameterisation.**  Instances that share a
   read_uhdm `$paramod` are one group; its shortest path is the
   representative and `work/inst/groups.json` lists the rest.  Rows and files
   are named after the module (`lzc`, `lzc#2`, ...), never the path — a deep
   fpnew generate path exceeds the 255-byte file-name limit.
4. **Miter + structural check.**  Each representative is SAT-mitered
   read_uhdm vs read_slang from reset (`-seq 2 -set-init-zero`), and
   `core_sweep.py cva6-chip` adds the undriven / driver-conflict check of its
   read_uhdm netlist.  There is no per-instance RTL co-sim yet: every CVA6
   module takes the struct-valued `CVA6Cfg` (and type parameters) that the
   `$paramod` name encodes as bit strings, which Verilator's `-G` cannot take,
   so the RTL side cannot be rebuilt from the name the way pavona's
   plain-parameter instances are — a per-instance wrapper generator is the
   follow-up.  The RTL co-sim of every module (at the core-level parameters)
   and of the whole core stay with the per-module sweep.

Why a second CVA6 family: the per-module sweep (`test/cva6_equiv`) wraps
each module with `cva6.sv`'s parameter block and binds same-named
parameters, so an instantiation's *own* overrides are invisible to it — a
load port and a store port of the same adapter, the nine different `lzc`
widths, a `SHORT` bypass.  Here every module is checked with exactly the
parameters it has under the core.  The whole-core co-sim remains the `cva6`
row of the per-module sweep.

```bash
cd test && python3 core_sweep.py cva6-chip                      # everything (137 miters)
cd test/cva6_chip && SKIP_IMPORT=1 python3 scripts/chip_flow.py '^lzc'   # re-use the netlists, miter the lzc group
```

CI: the `chip` job of `.github/workflows/sweep-cva6.yml`, 6 shards.
