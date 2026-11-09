// A module's OWN parameter shadows a same-named parameter brought in by a
// WILDCARD package import (LRM 26.3).  Surelog re-binds the package's
// param_assign onto the module's parameter, so the reader applied
// `W = $clog2(Words) = 10` over the module's `W = 9`.  OpenTitan i3c_buffer
// (`parameter BufAddrW = 9` + `import i3c_pkg::*`, where i3c_pkg has
// `localparam BufAddrW = $clog2(BufWords)` = 10): every struct member read
// at a child's port actual was measured 2 bits too high, and the SRAM's
// write / address actuals fell off the struct and read as X.
//
// Needs both a second package that references the name (i3c_fifo_pkg) and a
// parent that also imports the packages (the flat wrapper) to trigger.
package p;
  localparam int unsigned Words = 1024;
  localparam int unsigned W = $clog2(Words);
endpackage

package q;
  import p::*;
  typedef logic [W-1:0] ptr_t;
endpackage

module child #(parameter int Depth = 4) (
    input  logic                     w,
    input  logic [$clog2(Depth)-1:0] a,
    output logic                     ow,
    output logic [$clog2(Depth)-1:0] oa
);
  assign ow = w;
  assign oa = a;
endmodule

module mid import p::*; import q::*; #(parameter int unsigned W = 9) (
  input  logic [W:0] d,
  input  ptr_t       pi,
  output ptr_t       po,
  output logic       wr,
  output logic [W:0] a
);
  typedef struct packed {
    logic         write;
    logic [W-1:0] addr;
  } s_t;
  s_t s;
  assign s  = d;
  assign po = pi;
  child #(.Depth(Words)) u (.w(s.write), .a(s.addr), .ow(wr), .oa(a));
endmodule

module dut import p::*; import q::*; #(parameter int unsigned W = 9) (
  input  logic [9:0] d,
  input  logic [9:0] pi,
  output logic [9:0] po,
  output logic       wr,
  output logic [9:0] a
);
  mid u_mid (.*);
endmodule
