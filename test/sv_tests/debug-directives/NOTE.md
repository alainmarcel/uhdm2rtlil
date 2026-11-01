CONVERTED, and UHDM-only against the golden frontend.

`read_verilog` implements neither debug macro: `ERROR: Unimplemented compiler
directive or undefined macro `__LINE__`.  `read_slang` and `read_uhdm` both do,
so the slang miter and the structural proof are this test's gates.  An upstream
yosys capability gap, not a reader defect.
