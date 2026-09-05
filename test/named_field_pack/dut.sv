// Named-field assignment pattern into a packed struct inside a procedural
// branch (mirrors ibex_controller's NMI cause):
//   exc = cond ? CONST : '{a: 1'b0, b: 1'b1, c: CAUSE};
// The named 1-bit fields a/b landed SWAPPED in the packed value (UHDM said
// {a=1,b=0} for '{a:0,b:1}) — gold reported the external-NMI cause for an
// internal NMI.
package nfp_pk;
  typedef struct packed {
    logic       b;
    logic       a;
    logic [4:0] c;
  } s_t;
  parameter s_t CONST_S = '{a: 1'b1, b: 1'b0, c: 5'd16};
endpackage
module named_field_pack import nfp_pk::*; (
  input  logic       sel_i,
  input  logic [4:0] cause_i,
  output s_t         y_o,
  output s_t         z_o
);
  always_comb begin
    if (sel_i) begin
      y_o = CONST_S;
    end else begin
      y_o = '{a: 1'b0, b: 1'b1, c: cause_i};
    end
  end
  assign z_o = '{a: 1'b0, b: 1'b1, c: cause_i};
endmodule
