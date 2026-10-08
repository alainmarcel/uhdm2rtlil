# pkg.sv must come first: it declares the package the $unit import names.
# top: unit_struct_member_pkg_type
# read_verilog cannot parse a $unit-scope typedef at all ("dut.sv:19: ERROR:
# syntax error, unexpected TOK_ID"), so the verilog-vs-uhdm comparison would
# be vacuous.  The gate is test_slang_equiv.ys -- see CLAUDE.md, "Known
# Failing Tests -- two lists, and which one to use".
# mode: uhdm-only

pkg.sv
dut.sv
