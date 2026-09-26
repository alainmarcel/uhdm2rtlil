// One clocked for loop writing SEVERAL unpacked arrays in turn, plus a reset
// clear loop (verilog-pcie pcie_tlp_mux / axis_ram_switch / dma_if_pcie*:
// `for (i...) begin a_reg[i] <= a_next[i]; b_reg[i] <= b_next[i]; ... end`).
// The legacy sync path's memwr priority mask was ALL ONES over every prior
// write in the sync rule regardless of memory.  proc_memwr maps each set
// bit through THAT memory's own list of earlier ports, so a bit standing for
// a prior write to a DIFFERENT memory indexed past the list and yosys
// SEGFAULTED in `proc` ("read_uhdm failed" rows).  A bit is now set only for
// a prior write to the same memory (last-wins), as at the other emit sites.
module sync_loop_memwr_multi_memid_mask (
  input  logic       clk,
  input  logic       rst,
  input  logic [7:0] d,
  input  logic [3:0] k,
  input  logic       sel,
  output logic [7:0] q,
  output logic [3:0] qk
);
  reg [7:0] data_reg [0:1], data_next [0:1];
  reg [3:0] keep_reg [0:1], keep_next [0:1];
  integer i;

  always @* begin
    for (i = 0; i < 2; i = i + 1) begin
      data_next[i] = data_reg[i];
      keep_next[i] = keep_reg[i];
    end
    if (sel) begin data_next[1] = d; keep_next[1] = k; end
    else     begin data_next[0] = d; keep_next[0] = k; end
  end

  always @(posedge clk) begin
    for (i = 0; i < 2; i = i + 1) begin
      data_reg[i] <= data_next[i];
      keep_reg[i] <= keep_next[i];
    end
    if (rst) begin
      for (i = 0; i < 2; i = i + 1) begin
        data_reg[i] <= 0;
        keep_reg[i] <= 0;
      end
    end
  end

  assign q  = data_reg[sel];
  assign qk = keep_reg[sel];
endmodule
