// A dynamic index WIDER than the array it addresses: `buf[idx] <= d` with a
// 2-bit idx into a 2-entry array (OpenPiton bw_r_dtlb's
// `tte_csm_buf[wr_tte_csm_thrid] <= wr_tte_csm`, thrid 0..3 into [1:0]).
// LRM 7.4.6: a write to an out-of-range index is ignored.  read_slang and
// Verilator ignore it; read_uhdm truncated the index to the port's address
// width and wrote entry (idx mod 2).
module dut(input logic clk, input logic we, input logic [1:0] idx, input logic [7:0] d,
           output logic [7:0] q0, output logic [7:0] q1);
  logic [7:0] buf_q [1:0];
  always_ff @(posedge clk)
    if (we) buf_q[idx] <= d;
  assign q0 = buf_q[0];
  assign q1 = buf_q[1];
endmodule
