// A function with a reassigned local flag (`matched`) driving an unrolled
// priority loop, inlined from cont_assigns in TWO sibling generate-for
// scopes.  The FIRST inline was correct; the SECOND one resolved `!matched`
// to the $logic_not cell's OWN OUTPUT (connect \A <own Y>) — a comb
// self-loop that left the result undriven (ibex_pmp's access_fault_check in
// g_access_check[1]: only channel 1 broke).
module func_inline_selfloop (
  input  logic [3:0] match_i [2],
  input  logic [3:0] deny_i  [2],
  output logic       fail_o  [2]
);
  function automatic logic acc_fail(input logic [3:0] match_all,
                                    input logic [3:0] deny);
    logic access_fail = 1'b1;
    logic matched = 1'b0;
    for (int r = 0; r < 4; r++) begin
      if (!matched && match_all[r]) begin
        access_fail = deny[r];
        matched = 1'b1;
      end
    end
    return access_fail;
  endfunction

  for (genvar c = 0; c < 2; c++) begin : g_chk
    assign fail_o[c] = acc_fail(match_i[c], deny_i[c]);
  end
endmodule
