// A PACKED array (`logic [DEPTH-1:0][W-1:0] ram`) written at a DYNAMIC index
// in a clocked block -- `ram[waddr[port]] <= wdata[port]` under the write-port
// loop, behind a synchronous `zeroize` arm.  The sync-path emitter for a
// dynamic bit-select write (emit_dynamic_packed_bit_write_sync) knew only
// plain vectors: it wrote BIT idx of the array with bit 0 of the data, so every
// word of adams-bridge's abr_ram_regout held one bit (106 diverging
// co-simulated cycles, read_slang clean).  `ram[idx]` on a packed array is a
// W-bit ELEMENT at `(idx - low) * W`; the write now follows the same geometry
// the constant-index write already used.  read_verilog handles the shape, so
// the ordinary workflow is one formal gate; the read_slang miter (3 steps, so
// a write lands and is read back) is the other.
module dut #(parameter DEPTH = 4, parameter W = 8, parameter NP = 1, parameter AW = $clog2(DEPTH))
  (input logic clk, input logic zeroize, input logic [NP-1:0] we, input logic [NP-1:0][AW-1:0] waddr,
   input logic [NP-1:0][W-1:0] wdata, output logic [DEPTH-1:0][W-1:0] reg_o, output logic [W-1:0] r0);
   logic [DEPTH-1:0][W-1:0] ram;
   always @(posedge clk) begin
      if (zeroize) ram <= '0;
      else begin
         for (int port = 0; port < NP; port++)
            if (we[port]) ram[waddr[port]] <= wdata[port];
      end
   end
   assign reg_o = ram;
   assign r0 = ram[0];
endmodule
