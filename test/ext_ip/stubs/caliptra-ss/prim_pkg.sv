// Harness stand-in for lowRISC's `prim_pkg` as the OpenTitan files vendored
// into caliptra-ss (src/ast/rtl/*_pgd.sv) knew it.  Those files select their
// implementation with `prim_pkg::impl_e` / `prim_pkg::ImplGeneric`; the
// OpenTitan checkout the sweep pulls for the rest of the prim library ships a
// prim_pkg that dropped the enum years ago.  Both the enum and the current
// `PrimTechName` are provided so either generation of consumer compiles.
package prim_pkg;
  parameter PrimTechName = "Generic";
  typedef enum integer {
    ImplGeneric,
    ImplXilinx,
    ImplXilinxUltrascale,
    ImplBadbit
  } impl_e;
endpackage : prim_pkg
