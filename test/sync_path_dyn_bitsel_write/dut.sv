// A dynamic bit-select write to a plain packed vector in a clocked block
// that ALSO shifts an unpacked array in a for loop (so the whole block goes
// through the legacy sync path): verilog-pcie dma_if_pcie_wr's operation
// table, `op_table_active[op_table_start_ptr_reg[W-1:0]] <= 1'b1` set at the
// start pointer and cleared at the finish pointer.  import_expression of
// such an LHS is the $shiftx READ, so the sync path stored the write into
// that throwaway wire and the bit never changed: no table entry ever became
// active, the TLP state machine never left IDLE and tx data stayed zero
// (276 co-sim divergences).  The write is now a read-modify-write of the
// whole base, like the indexed part-select form.
module sync_path_dyn_bitsel_write (
  input  logic       clk,
  input  logic       rst,
  input  logic       start_en,
  input  logic       fin_en,
  input  logic [7:0] len,
  input  logic [1:0] rp,
  output logic [3:0] active,
  output logic [7:0] len_o,
  output logic [2:0] sp_o,
  output logic [7:0] shadow_o
);
  reg [2:0] op_table_start_ptr_reg = 0, op_table_finish_ptr_reg = 0;
  reg [3:0] op_table_active = 0;
  reg [3:0] op_table_done = 0;
  reg [7:0] op_table_len [3:0];
  reg [7:0] op_table_tag [3:0];
  reg [7:0] shadow [1:0];
  integer i;

  always @(posedge clk) begin
    if (start_en) begin
      op_table_start_ptr_reg <= op_table_start_ptr_reg + 1;
      op_table_active[op_table_start_ptr_reg[1:0]] <= 1'b1;
      op_table_done[op_table_start_ptr_reg[1:0]] <= 1'b0;
      op_table_len[op_table_start_ptr_reg[1:0]] <= len;
      op_table_tag[op_table_start_ptr_reg[1:0]] <= ~len;
    end
    if (fin_en) begin
      op_table_finish_ptr_reg <= op_table_finish_ptr_reg + 1;
      op_table_active[op_table_finish_ptr_reg[1:0]] <= 1'b0;
      op_table_done[op_table_finish_ptr_reg[1:0]] <= 1'b1;
    end
    // the loop memory write is what selects the sync path
    for (i = 0; i < 2; i = i + 1) begin
      shadow[i] <= len + i;
    end
    if (rst) begin
      op_table_start_ptr_reg <= 0;
      op_table_finish_ptr_reg <= 0;
      op_table_active <= 0;
    end
  end

  assign active = op_table_active;
  assign len_o  = op_table_len[rp] ^ op_table_tag[rp];
  assign sp_o   = op_table_start_ptr_reg;
  assign shadow_o = shadow[rp[0]];
endmodule
