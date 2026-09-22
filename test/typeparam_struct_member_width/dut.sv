// KNOWN FAILING — see test/failing_tests.txt.
//
// A struct reached through a TYPE PARAMETER measures its parameter-sized
// members as ZERO, so a member select on a type-parameter-typed port comes out
// too narrow and the missing bits are left undriven.
//
// Surelog emits exactly ONE `struct_typespec` for `aw_t`, and its owner is the
// module DEFINITION (`work@mid`), where every parameter sits at its DEFAULT
// (ADDR_WIDTH = 0).  There is no elaborated copy.  `inner` has no ADDR_WIDTH of
// its own to resolve `logic [ADDR_WIDTH-1:0] addr` with, so that member
// measures 0 and `aw_t` measures `id` alone: 4 bits instead of 36.
//
// The narrow-output widening in uhdm2rtlil.cpp then hands the cell a fresh wide
// wire and connects only the 4 bits back, leaving addr's 32 bits dangling.
//
// In the wild: PULP axi_cut's `output axi_req_t mst_req_o` with
// `.data_o(mst_req_o.aw)` -- `mst_req_o.aw` measures 41 bits instead of 72, and
// axi_cut_intf reports 125 undriven nets against read_slang's 2.
//
// The trigger is specifically the TYPE PARAMETER: the same design with `inner`
// declaring the typedefs locally reads clean.

module leaf #(
  parameter type d_t = logic
) (
  input  logic c_i,
  input  logic [31:0] a_i,
  output d_t   d_o,
  output logic v_o
);
  assign d_o = a_i;
  assign v_o = c_i;
endmodule

module inner #(
  parameter type req_t = logic,   // the whole struct, bound by the parent
  parameter type aw_t  = logic    // one member's type
) (
  input  logic        c_i,
  input  logic [31:0] a_i,
  output req_t        mst_req_o   // TYPE-PARAMETER-typed output port
);
  leaf #(.d_t(aw_t)) u_aw (
    .c_i ( c_i                ),
    .a_i ( a_i                ),
    .d_o ( mst_req_o.aw       ),  // member select as an instance actual
    .v_o ( mst_req_o.aw_valid )
  );
endmodule

module mid #(
  parameter int unsigned ADDR_WIDTH = 0,
  parameter int unsigned ID_WIDTH   = 0
) (
  input  logic                            c_i,
  input  logic [31:0]                     a_i,
  output logic [ADDR_WIDTH+ID_WIDTH : 0]  flat_o
);
  typedef struct packed {
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0]   id;
  } aw_t;
  typedef struct packed {
    aw_t  aw;
    logic aw_valid;
  } req_t;

  req_t req;
  inner #(.req_t(req_t), .aw_t(aw_t)) u_i (.c_i(c_i), .a_i(a_i), .mst_req_o(req));
  assign flat_o = req;
endmodule

module dut (
  input  logic        c_i,
  input  logic [31:0] a_i,
  output logic [36:0] flat_o      // {addr[31:0], id[3:0], aw_valid}
);
  mid #(.ADDR_WIDTH(32), .ID_WIDTH(4)) u_m (.c_i(c_i), .a_i(a_i), .flat_o(flat_o));
endmodule
