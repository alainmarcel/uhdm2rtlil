// A dynamic ELEMENT write into a packed 2-D array that is declared inside a
// generate block and written from a deeper generate arm:
//   if (...) begin : gen_a
//     logic [3:0][15:0] storage;
//     if (...) begin : gen_b  if (RESET) ... else begin : gen_c_no_reset
//       always_ff @(posedge clk_i) if (we_i) storage[wptr_i] <= wdata_i;
// -- caliptra_prim_fifo_sync's gen_normal_fifo / gen_depth_gt1 /
// gen_depth_gt1_no_reset.  The write's per-process temp is the RANGED
// `$0\gen_a.storage[63:0]`; recovering the scoped wire name from it kept
// the `[63:0]` suffix, the lookup missed, and the dynamic write fell
// through to the READ import (assigned the $shiftx output): the FIFO never
// stored a word (rdata_o read 0 from cycle 22 in every caliptra-ss FIFO /
// queue row).  At module scope the same write was already right.
// read_verilog cannot handle the packed 2-D dynamic select the same way
// (the miter against read_slang is the gate).
module dut #(parameter bit RESET = 0) (input logic clk_i, input logic clr_i, input logic we_i, input logic [1:0] wptr_i, input logic [1:0] rptr_i, input logic [15:0] wdata_i, output logic [15:0] rdata_o);
  if (1) begin : gen_a
    logic [3:0][15:0] storage;
    assign rdata_o = storage[rptr_i];
    if (1) begin : gen_b
      if (RESET) begin : gen_c_reset
        always_ff @(posedge clk_i) if (clr_i) storage <= 0; else if (we_i) storage[wptr_i] <= wdata_i;
      end else begin : gen_c_no_reset
        always_ff @(posedge clk_i) if (we_i) storage[wptr_i] <= wdata_i;
      end
    end
  end
endmodule
