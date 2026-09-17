// A cross-module reference (XMR) WRITE: `child_inst.sig = <expr>` assigns INTO
// a child instance from outside it.
//
// The importer only had the XMR *read* path, which exposes the child signal as
// an OUTPUT port.  Used for a write, the parent then drove a cell OUTPUT and
// yosys rejected the design:
//
//   Cell port ...u_state_regs.unused_assert_connected is driving constant bits:
//   1'1 <= \u_state_regs.unused_assert_connected_1
//
// caliptra-rtl's caliptra_prim_assert_sec_cm.svh does this in every sparse-FSM
// security check:
//
//   assign HIER_.unused_assert_connected = 1'b1;
//
// so `sha3` (and kmac_app / kmac_errchk under it) could not be synthesised at
// all.  A write needs the opposite direction: the child takes the signal as an
// INPUT, driven from the parent.
//
// Resolution is DEFERRED to after every cell exists — continuous assigns are
// imported before instances, so the child cell is not there yet when the
// assignment is seen.
//
// Both a direct child (`u_leaf.flag`) and a nested one (`u_mid.u_inner.flag`)
// are covered, and both values reach the top output so a dropped write is
// visible rather than optimised away.

module leaf (input logic a, output logic y);
  logic flag;               // written from OUTSIDE via an XMR
  assign y = a ^ flag;
endmodule

module mid (input logic a, output logic y);
  leaf u_inner (.a(a), .y(y));
endmodule

module dut (input logic a, output logic y_direct, output logic y_nested);
  leaf u_leaf (.a(a), .y(y_direct));
  mid  u_mid  (.a(a), .y(y_nested));

  // Downward XMR writes, one direct and one through an intermediate level.
  assign u_leaf.flag = 1'b1;
  assign u_mid.u_inner.flag = 1'b1;
endmodule
