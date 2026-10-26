// Two DYNAMIC element writes to one unpacked array in SIBLING arms of the
// clocked body of an async-reset always block whose reset (and flush) arms
// clear the array with a for-loop -- biRISC-V's fetch_fifo pushes and pops in
// one cycle:
//
//     if (rst_i) for (i) valid0_q[i] <= 0;
//     else if (flush_i) for (i) valid0_q[i] <= 0;
//     else begin
//       if (push_w) valid0_q[wr_ptr_q] <= 1'b1;
//       if (pop1_w) valid0_q[rd_ptr_q] <= 1'b0;
//     end
//
// A dynamic index touches every element (one hold-mux each), so both arms
// assign all `$0\valid0_q[k]` temps.  The pop arm's muxes must start from the
// value the push arm just gave each element; the emitter folded that value
// from the process ROOT, but a switch is attached to its parent case only
// after its arms are imported, so inside the `else if ... else` arm the
// sibling push switch was not reachable yet and the pop arm started from the
// REGISTERED elements: with both firing in one cycle the pushed valid bit was
// lost (valid0_o read 0 where the simulator read 1; 3 cycles on fetch_fifo, 17
// through biriscv_decode, 201 through riscv_core).  Without the reset-arm
// clear the arms sit directly under the reset switch and the root fold works.
module dut #(parameter DEPTH=2, parameter ADDR_W=1) (input clk_i, input rst_i, input flush_i, input push_w, input pop1_w, input [ADDR_W-1:0] wr_ptr_q, input [ADDR_W-1:0] rd_ptr_q, output valid0_o);
  reg valid0_q[DEPTH-1:0];
  integer i;
  always @(posedge clk_i or posedge rst_i)
    if (rst_i) begin
      for (i = 0; i < DEPTH; i = i + 1) valid0_q[i] <= 1'b0;
    end else if (flush_i) begin
      for (i = 0; i < DEPTH; i = i + 1) valid0_q[i] <= 1'b0;
    end else begin
      if (push_w) valid0_q[wr_ptr_q] <= 1'b1;
      if (pop1_w) valid0_q[rd_ptr_q] <= 1'b0;
    end
  assign valid0_o = valid0_q[rd_ptr_q];
endmodule
