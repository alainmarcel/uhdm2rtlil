CONVERTED, and gated on read_verilog rather than read_slang.

`read_slang` treats a module inside a `celldefine` region as a LIBRARY CELL: it
flattens `u_ncd` and leaves `u_cd` as an empty `cell \cd \u_cd` with no
contents, so the miter has no SAT model for it
(`No SAT model available for cell gate.u_cd (cd)`) and `flatten` cannot inline
it.  That is a defensible reading of what `celldefine` means and not a reader
defect; it does mean read_slang cannot be an oracle for the celldefined module's
INTERNALS.  read_uhdm and read_verilog both keep the content, so the
uhdm-vs-verilog comparison and the structural proof are this test's gates.
