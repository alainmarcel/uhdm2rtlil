#!/usr/bin/env python3
"""Emit docs/slang_cosim_findings.md from a curated row table.

Row: family, module, slang_div, uhdm_div, first_div, source
  slang_div / uhdm_div: divergence counts against the behavioural RTL in the
  same Verilator testbench; None when not measured.
"""
import sys, urllib.parse

ROWS = []          # filled by the caller via add()
def add(family, module, slang, uhdm, first="", source=""):
    ROWS.append(dict(family=family, module=module, slang=slang, uhdm=uhdm,
                     first=first, source=source))

def issue_url(family, module, first):
    title = f"read_slang: {module} netlist does not match the RTL in simulation"
    body = (f"`read_slang` ({family} sweep) produces a netlist whose simulation "
            f"diverges from the behavioural RTL.\n\n"
            f"First divergence: {first or 'see report'}\n\n"
            f"Method: one Verilator testbench drives the behavioural RTL, the "
            f"`read_slang` netlist and the `read_uhdm` netlist with identical "
            f"stimulus. The `read_uhdm` netlist matches the RTL on every cycle; "
            f"the `read_slang` netlist does not.\n\n"
            f"Yosys 0.69, read_slang from the vendored sv-elab (povik/sv-elab @ b4fd362).")
    return ("https://github.com/YosysHQ/yosys/issues/new?"
            + urllib.parse.urlencode({"title": title, "body": body}))

def classify(r):
    if r["slang"] in (None, 0):
        return "clean"
    if r["uhdm"] == 0:
        return "report"
    if r["uhdm"] is None:
        return "unmeasured"
    if r["uhdm"] == r["slang"]:
        return "shared"
    return "adjudicate"

def emit(out):
    g = {k: [r for r in ROWS if classify(r) == k]
         for k in ("report", "adjudicate", "shared", "clean", "unmeasured")}
    L = []
    A = L.append
    A("# Where `read_slang` does not match Verilator\n")
    A("Every nightly IP sweep co-simulates three things against each other with one\n"
      "testbench and one random stimulus: the behavioural RTL, the netlist\n"
      "`read_uhdm` produces, and the netlist `read_slang` produces.  The left-most\n"
      "column of every sweep table is the last of those — how the reference\n"
      "frontend's own netlist tracks the RTL under Verilator.  This file collects\n"
      "every row where it does not.\n")
    A("A row is evidence of a `read_slang` defect when the `read_uhdm` netlist\n"
      "matches the RTL on every cycle and the `read_slang` netlist does not: same\n"
      "testbench, same stimulus, same RTL, one netlist right and one wrong.  When\n"
      "BOTH netlists diverge the cause is almost always the co-simulation itself —\n"
      "an un-reset register reads X out of reset in the RTL and 0 in a netlist —\n"
      "so those rows are listed separately and are not reported.\n")
    A("`read_slang` is a Yosys built-in since v0.67; the code is vendored from\n"
      "[povik/sv-elab](https://github.com/povik/sv-elab) at `b4fd362`.  Measured on\n"
      "Yosys 0.69.\n")
    A("> **A correction.** Until 2026-09-29 this list was much longer, and wrongly\n"
      "> so.  All three co-simulation harnesses flattened an unpacked-array port\n"
      "> with element 0 at the least significant bits whatever the declared\n"
      "> direction, which matched `read_uhdm` alone.  `read_slang` follows the\n"
      "> language — the left index of the dimension takes the most significant\n"
      "> bits, which is what the stream operator `{>>{x}}` computes (LRM 11.4.14)\n"
      "> and what Verilator prints for it — so every module with an ascending\n"
      "> `x [N]` port looked like a slang defect.  The reader and the harnesses\n"
      "> were corrected to the language's order; `ibex_id_stage` went from 52\n"
      "> divergences to none, `otbn_reg_top` from 19 to none, `ibex_ex_block` from\n"
      "> 447 to 58 (and those 58 are shared with `read_uhdm`, so the row is an\n"
      "> artefact, not a defect).  The rows below are what survived.\n")

    A("\n## Report to Yosys\n")
    if g["report"]:
        A("The `read_uhdm` netlist matches the RTL cycle for cycle; the\n"
          "`read_slang` netlist does not.\n")
        A("| Sweep | Module | Diverging cycles | First divergence | Report |")
        A("|---|---|---|---|---|")
        for r in sorted(g["report"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} | {r['first'] or '—'} "
              f"| [file an issue]({issue_url(r['family'], r['module'], r['first'])}) |")
    else:
        A("None outstanding.\n")

    if g["adjudicate"]:
        A("\n## Both netlists diverge, but not equally\n")
        A("Both frontends drift from the RTL, so the co-simulation's own X-initial\n"
          "state explains most of it, but the counts differ — worth adjudicating\n"
          "before either reporting or dismissing.\n")
        A("| Sweep | Module | slang | read_uhdm | First slang divergence |")
        A("|---|---|---|---|---|")
        for r in sorted(g["adjudicate"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} | {r['uhdm']} | {r['first'] or '—'} |")

    if g["shared"]:
        A("\n## Shared divergence — a co-simulation artefact, not a defect\n")
        A("Both netlists diverge from the RTL on exactly the same cycles.  A netlist\n"
          "has no X state, so an un-reset register reads 0 where the RTL reads X;\n"
          "the SAT miter, which starts from a defined state, proves these modules\n"
          "equivalent.  Listed for completeness.\n")
        A("| Sweep | Module | Diverging cycles (both) |")
        A("|---|---|---|")
        for r in sorted(g["shared"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} |")

    if g["unmeasured"]:
        A("\n## Not yet re-measured\n")
        A("Carried from the last CI report; the `read_uhdm` side has not been run\n"
          "since the harness correction, so these are not yet classified.\n")
        A("| Sweep | Module | slang divergences | Source |")
        A("|---|---|---|---|")
        for r in sorted(g["unmeasured"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} | {r['source']} |")

    if g["clean"]:
        A("\n## Cleared by the harness correction\n")
        A("| Sweep | Module | Was | Now |")
        A("|---|---|---|---|")
        for r in sorted(g["clean"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['first']} | 0 |")

    A("\n---\n")
    A("Regenerate with `test/slang_cosim_report.py` after a sweep cycle.  A row moves\n"
      "out of this file the moment its sweep reports the slang column clean.\n")
    open(out, "w").write("\n".join(L) + "\n")
    print(f"{out}: report={len(g['report'])} adjudicate={len(g['adjudicate'])} "
          f"shared={len(g['shared'])} unmeasured={len(g['unmeasured'])} cleared={len(g['clean'])}")

# ----------------------------------------------------------------- the rows
# Measured with the corrected harnesses (2026-09-29) unless marked otherwise.
CI = "CI sweep report, pre-correction"

# --- report: read_uhdm clean, read_slang not
add("caliptra-ss", "width_converter_8toN", 58, 0,
    "cycle 26, `source_data_o` rtl=`0000073f` slang=`0000003f`")
add("cv32e40p", "cv32e40p_register_file", 230, 0,
    "cycle 27, `rdata_a_o` rtl=`82b7c5e0` slang=`00000000`")
add("cva6", "macro_decoder", 1, 0,
    "cycle 6, `instr_o` rtl=`ff313823` slang=`c172ff1c`")
add("cvfpu", "fpnew_fma_multi", 19, 0,
    "cycle 16, `result_o` rtl=`…ffff7fc0` slang=`…ffff5ae0`")
add("opentitan", "otbn_rnd", 296, 0,
    "cycle 4, `ispr_urnd_state_rdata_o` (slang zeroes the low limb)")
add("verilog-ethernet", "axis_ram_switch", 176, 0,
    "cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000`")
add("verilog-pcie", "axis_ram_switch", 206, 0,
    "cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000` (same module, vendored twice)")
add("verilog-pcie", "pcie_axil_master", 219, 0, "cycle 55, `tx_cpl_tlp_data`")
add("verilog-pcie", "pcie_s10_cfg", 103, 0,
    "cycle 198, `cfg_msi_address` rtl=`c2af88347c3321e0` slang=`000000007c3321e0`")

# --- both diverge, counts differ
add("cv32e40p", "cv32e40p_cs_registers", 200, 136)
add("cva6", "axi_adapter", 53, 33)
add("cva6", "hpdcache_ctrl", 151, 154)
add("cva6", "hpdcache_memctrl", 160, 140)
add("cva6", "wt_dcache_mem", 63, 25)
add("ibex", "ibex_cs_registers", 61, 51,
    "cycle 206, `csr_mepc_o` rtl=`0` slang=`548c3846`")
add("verilog-pcie", "pcie_us_if_rc", 238, 272)

# --- shared: both netlists diverge on the same cycles
for fam, mod, n in [
        ("common_cells", "cc_clk_int_div", 5),
        ("cv32e40p", "cv32e40p_controller", 92),
        ("cv32e40p", "cv32e40p_fifo", 30),
        ("cv32e40p", "cv32e40p_prefetch_buffer", 9),
        ("cva6", "hpdcache_amo", 171),
        ("cva6", "hpdcache_cmo", 298),
        ("cva6", "hpdcache_uncached", 300),
        ("cva6", "issue_stage", 3),
        ("cva6", "miss_handler", 1),
        ("cva6", "wt_dcache_wbuffer", 216),
        ("cve2", "cve2_alu", 18),
        ("cve2", "cve2_ex_block", 14),
        ("ibex", "ibex_alu", 38),
        ("ibex", "ibex_ex_block", 58),
        ("pavona", "ibex_cs_registers", 256),
        ("verilog-ethernet", "ptp_td_rel2tod", 2),
        ("verilog-pcie", "pcie_ptile_cfg", 189)]:
    add(fam, mod, n, n)

# --- cleared by the correction
add("ibex", "ibex_id_stage", 0, 0, "52 divergences")
add("opentitan", "otbn_reg_top", 0, 0, "19 divergences")

add("aes", "aes_prng_masking", 300, 0)
add("kmac", "kmac_reduced", 62, 0)
add("rp32", "rp32_r5p_alu", 519, 493)
add("rp32", "rp32_r5p_mouse", 438, 499)
add("rp32", "rp32_r5p_wbu", 181, 181)

# --- carried from the last CI report; the read_uhdm side has not been re-run
#     since the harness correction, so these stay unclassified for now.
for fam, mod, n, src in [
        ("periph5", "spid_status", 15, "pavona nightly 36421592007"),
        ("dragonfly", "u_keymgr_dpe", 301, "pavona nightly 36421592007"),
        ("dragonfly", "u_lc_ctrl", 301, "pavona nightly 36421592007"),
        ("dragonfly", "u_rv_core_ibex", 258, "pavona nightly 36421592007"),
        ("egret", "u_flash_ctrl", 301, "pavona run 36346999995"),
        ("egret", "u_keymgr", 301, "pavona run 36346999995"),
        ("egret", "u_lc_ctrl", 301, "pavona run 36346999995"),
        ("egret", "u_otp_ctrl", 301, "pavona run 36346999995"),
        ("xiangshan-core", "Queue2_TLBundleB_2", 1, "xiangshan run 36421602760"),
        ("xiangshan-core", "Queue2_TLBundleD_21", 1, "xiangshan run 36421602760"),
        ("xiangshan-core", "TLBuffer_14", 6, "xiangshan run 36421602760")]:
    add(fam, mod, n, None, "", src)

if __name__ == "__main__":
    emit(sys.argv[1] if len(sys.argv) > 1 else "slang_cosim_findings.md")
