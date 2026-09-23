// A struct reached through a TYPE PARAMETER used to measure its
// parameter-sized members as the degenerate `[-1:0]`, two bits each.
//
// Surelog CLONES the typedef into the receiving instance, and the clone's
// parameter references lose their binding: under `inner #(.aw_t(aw_t))` the
// cloned `aw_t` carries `ref_obj (work@dut.u_m.u_i.aw_t.aw_t.addr.ADDR_WIDTH)`
// with no vpiActual, and `inner` has no ADDR_WIDTH of its own.  Relayed one
// level further (`leaf #(.d_t(aw_t))`) the clone arrives with no VpiParent at
// all and with its names stripped to `aw_t.addr.ADDR_WIDTH`.
//
// So `aw_t` measured 4 bits instead of 36, the member select on the
// type-parameter'd port came out short, and the narrow-output widening left
// addr's 32 bits undriven.  In the wild: PULP axi_cut's `.data_o(mst_req_o.aw)`
// measured 41 bits instead of 72, and axi_cut_intf reported 125 undriven nets
// against read_slang's 2.
//
// The fix measures such a clone in the instance that DECLARED the type --
// found through the type parameter's instance ancestors, or, for a detached
// clone, by the typedef's source location.
//
// The trigger is specifically the TYPE PARAMETER: the same design with `inner`
// declaring the typedefs locally has always read clean.

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
