// `{hi, lo} = expr;` -- a CONCATENATION of function locals -- then `return hi`.
// Called from a continuous assign the function is right (that path is
// process_stmt_to_case, which has a concat branch); called from an
// always_comb it went through inline_func_body_comb, which resolved only a
// NAMED left-hand side, so the statement was dropped and `return hi` read the
// local's X initialiser.  OpenTitan tlul_pkg::get_cmd_intg is
// `{cmd_intg, unused_cmd_payload} = prim_secded_inv_64_57_enc(...)`, called
// from always_comb blocks all over the TL-UL IP: cheriot_rmw_filter emitted a
// constant 7'x command integrity at every call site (36 diverging co-simulated
// cycles, read_slang clean).
module dut (
  input  logic [7:0] i,
  output logic [6:0] o_assign,
  output logic [6:0] o_comb,
  output logic       lo_comb
);
  function automatic logic [6:0] f(input logic [7:0] a);
    logic [6:0] hi;
    logic       lo;
    {hi, lo} = {a[7:1], a[0]} ^ 8'h0F;
    return hi;
  endfunction

  function automatic logic g(input logic [7:0] a);
    logic [6:0] hi;
    logic       lo;
    {hi, lo} = a + 8'd1;
    return lo;
  endfunction

  assign o_assign = f(i);
  always_comb begin
    o_comb  = f(~i);
    lo_comb = g(i);
  end
endmodule
