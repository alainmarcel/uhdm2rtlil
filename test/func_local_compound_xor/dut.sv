// A function LOCAL variable updated by guarded compound assignments and
// returned — CVA6 aes_pkg::gfmul's shape:
//
//   function automatic logic [7:0] gfmul(x, y);
//     logic [7:0] result, temp;
//     result = 8'h00;
//     if (y[0]) result ^= x;
//     ...
//     return result;
//
// The UHDM frontend inlined `result ^= ...` as a continuous assign whose RHS
// read the SAME wire being driven (`$result = $result ^ x`) — a combinational
// self-loop that simulates as 0, so aes_mixcolumn_inv (and with it CVA6's
// aes64dsm/aes64im results) folded to constant 0.  Each blocking assignment
// to a function local must see the PREVIOUS value, not the final wire.
package p;
  function automatic logic [7:0] gf(input logic [7:0] x, input logic [3:0] y);
    logic [7:0] result, temp;
    result = 8'h00;
    if (y[0]) result ^= x;
    if (y[1]) result ^= ((x << 1) ^ ((x[7]) ? 8'h1B : 8'h00));
    if (y[2]) begin
      temp = (x << 1) ^ ((x[7]) ? 8'h1B : 8'h00);
      result ^= (temp << 1) ^ ((temp[7]) ? 8'h1B : 8'h00);
    end
    if (y[3]) begin
      temp = (x << 1) ^ ((x[7]) ? 8'h1B : 8'h00);
      temp = (temp << 1) ^ ((temp[7]) ? 8'h1B : 8'h00);
      result ^= (temp << 1) ^ ((temp[7]) ? 8'h1B : 8'h00);
    end
    return result;
  endfunction
endpackage

module func_local_compound_xor (
    input  logic [7:0] a_i,
    input  logic [3:0] s_i,
    output logic [7:0] r_o
);
  assign r_o = p::gf(a_i, s_i);
endmodule
