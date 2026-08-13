// Repro of CVA6 wt_axi_adapter.sv:142 / cva6_fifo_v3.sv:75 importer-temp
// latches ($auto$expression.cpp:...:import_bit_select / import_expression):
// DYNAMIC writes into PACKED arrays (one flat wire, no per-element wires).
//   - `mem_n[wptr] = data`           (bit_select, dynamic element index —
//                                     cva6_fifo_v3's `dtype [DEPTH-1:0] mem_n`)
//   - `wr_be[0][bit_idx] = '1`       (var_select: const element, dynamic bit —
//                                     wt_axi_adapter byte enables)
//   - `wr_be[0][bit_idx+:2] = '1`    (var_select + indexed part select)
// The LHS must be lowered as a mask/shift/or RMW of the flat wire; the READ
// path ($shiftx output wire) as a write target self-holds and latches, and
// the write itself is dropped.  slang: 0 latches.
module latch_packed_dyn_write #(
    parameter int unsigned DEPTH = 4,
    parameter int unsigned W = 8,
    parameter int unsigned BE = 8
) (
    input  logic [W-1:0]              data_i,
    input  logic [1:0]                wptr_i,
    input  logic [2:0]                bit_i,
    input  logic [1:0]                size_i,
    input  logic                      push_i,
    output logic [DEPTH-1:0][W-1:0]   mem_o,
    output logic [1:0][BE-1:0]        be_o
);
  logic [DEPTH-1:0][W-1:0] mem_n, mem_q;
  logic [1:0][BE-1:0]      wr_be;

  always_comb begin
    for (int unsigned k = 0; k < DEPTH; k++) mem_q[k] = data_i ^ W'(k);
  end

  always_comb begin : read_write_comb
    mem_n = mem_q;
    if (push_i) begin
      mem_n[wptr_i] = data_i;
    end

    // Size-aligned dynamic bit offsets, like wt_axi_adapter's byte enables.
    // The +: base MUST stay in range: for a partially out-of-range packed
    // part-select write, UHDM and slang clamp to the element (LRM 11.5.1)
    // while read_verilog / Verilator / iverilog spill into the flat vector —
    // OOB stimulus makes the miter fail on a tool divergence, not a bug.
    wr_be = '0;
    unique case (size_i)
      2'b00:   wr_be[0][bit_i] = 1'b1;
      2'b01:   wr_be[0][{bit_i[2:1], 1'b0}+:2] = '1;
      2'b10:   wr_be[0][{bit_i[2], 2'b00}+:4] = '1;
      default: wr_be[0] = '1;
    endcase
  end

  assign mem_o = mem_n;
  assign be_o  = wr_be;
endmodule
