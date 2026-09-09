// A function that assigns its RETURN value via a CONCAT LHS
// (`{ret, unused} = <wide-expr>; return ret;`) — tlul_pkg's get_cmd_intg does
// `{cmd_intg, unused} = prim_secded_enc(...); return cmd_intg;`.  The function
// inliner had no concat-LHS case, so the whole assignment was dropped and the
// return read undriven (tlul_socket_1n/m1's get_cmd_intg = 7 undriven nets).
module func_concat_lhs_return(input logic [12:0] d, output logic [6:0] o);
  function automatic logic [6:0] f(logic [12:0] din);
    logic [6:0] hi;
    logic [6:0] lo;
    {hi, lo} = {din, 1'b0} ^ 14'h1;   // 14-bit RHS split across two 7-bit locals
    return hi ^ lo;
  endfunction
  assign o = f(d);
endmodule
