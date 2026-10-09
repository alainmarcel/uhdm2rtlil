// A non-blocking write to a FIELD of a DYNAMICALLY indexed struct-array element
// inside an always_ff, under a conditional arm -- RSD's BTB:
//
//     always_ff @(posedge port.clk)
//         if (port.rst)            btbQueue[resetIndex].btbWA <= '0;
//         else if (pushBtbQueue)   btbQueue[headPtr].btbWA   <= btbWA[...];
//
// The per-element read-modify-write looked its next-state temp up as
// `$0\arr[k]`, but the always_ff temps are `$0\arr[k][W-1:0]`, so the write
// landed on the register wire itself; with the hold input of the RMW mux
// reading that same wire, every element became a combinational loop.  yosys's
// proc_dlatch walked it until the stack ran out (268k frames) and read_uhdm
// died with a bare segfault -- BTB, and Core / Main_Zynq / Main_Zynq_Wrapper
// above it, were "read_uhdm failed" rows with no message at all.
module always_ff_dyn_elem_field_write
  (input  logic       clk,
   input  logic       rst,
   input  logic       push,
   input  logic [1:0] head,
   input  logic [1:0] ridx,
   input  logic [7:0] wa,
   input  logic [3:0] wv,
   input  logic [1:0] ridx_o,
   output logic [7:0] ra_o,
   output logic [3:0] rv_o);
  typedef struct packed { logic [7:0] wa; logic [3:0] wv; } entry_t;
  entry_t q [4];
  always_ff @(posedge clk) begin
    if (rst) begin
      q[ridx].wa <= '0;
      q[ridx].wv <= '0;
    end
    else if (push) begin
      q[head].wa <= wa;
      q[head].wv <= wv;
    end
  end
  assign ra_o = q[ridx_o].wa;
  assign rv_o = q[ridx_o].wv;
endmodule
