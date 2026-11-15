// A non-ANSI function port with a signing keyword and an implicit type keeps
// its range and sign (Surelog #4261; MikePopoloski/slang#1154: the 8-bit
// formal read as 1 bit and the popcount returned X).
function signed [7:0] incr_sum;
  input signed [7:0] a;
  logic signed [7:0] tmp;
  begin
    tmp = 'd0;
    for (int i = 0; i < 8; i = i + 1) tmp = tmp + a[i];
    incr_sum = tmp;
  end
endfunction
module dut(input logic [7:0] x, output logic [7:0] pop, output logic [7:0] id);
  function signed [7:0] ident;
    input signed [7:0] a;
    ident = a;
  endfunction
  always_comb pop = incr_sum(x);
  always_comb id = ident(x);
endmodule
