// A `static` local of an automatic function keeps its value across calls
// (LRM 6.21): called once per clock, it is a register.  read_uhdm used to
// fold the call at compile time (q constant); MikePopoloski/slang#2067.
module dut(input logic clk, output logic [3:0] q);
  function automatic logic [3:0] next_val();
    logic [3:0] t;           // automatic: a fresh temporary every call
    static logic [3:0] cnt = 4'd3;
    t = cnt + 4'd1;
    cnt = t;
    return cnt;
  endfunction
  always_ff @(posedge clk) q <= next_val();
endmodule
