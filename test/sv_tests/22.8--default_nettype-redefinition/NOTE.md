CONVERTED, and UHDM-only against the golden frontend.

Upstream walks `default_nettype through all eleven net types.  `read_verilog`
stops at the second one -- `dut.sv:8: ERROR: Unsupported default nettype: tri` --
so it cannot read this test at all and the uhdm-vs-verilog comparison is
unavailable.  `read_slang` reads it and the miter plus the structural proof are
the gates.  An upstream yosys capability gap, not a reader defect: read_uhdm
accepts all eleven.
