// Packed array whose dimension is a localparam Surelog could not fold.
// HtCapacity depends on `$bits(id_t)` of the PARENT's type parameter (an
// override actual Surelog leaves unfolded -- Surelog #4189), so Surelog
// inlines HtCapacity at every use as its expression tree
// `((2**IdWidth <= Capacity) ? 2**IdWidth : Capacity) - 1`.  Imported
// plainly, the power / ternary stayed cells, the bound was "not fully
// const", and the reader sized ht_q to ONE element (5 bits instead of 40),
// never stamped the packed-element geometry, and dropped the element
// writes: rd_o read 0 after a write to entry 3 (common_cells cc_id_queue's
// head_tail_q, PULP axi_burst_splitter).  The reader now folds every
// declared range bound at the import_expression entry.
//
// read_verilog cannot parse the type parameter, so the slang miter is the
// only real gate; it fails without the fix.
module packed_range_inlined_localparam (
  input  logic       clk_i, rst_ni,
  input  logic [3:0] id_i,
  input  logic [2:0] widx, ridx,
  input  logic       we,
  output logic [4:0] rd_o
);
  mid #(.id_t(logic [3:0])) u_mid (.*);
endmodule

module mid #(parameter type id_t = logic) (
  input  logic       clk_i, rst_ni,
  input  id_t        id_i,
  input  logic [2:0] widx, ridx,
  input  logic       we,
  output logic [4:0] rd_o
);
  child #(.IdWidth($bits(id_t)), .Capacity(8)) u_child (.*);
endmodule

module child #(
  parameter int unsigned IdWidth  = 0,
  parameter int unsigned Capacity = 0
) (
  input  logic               clk_i, rst_ni,
  input  logic [IdWidth-1:0] id_i,
  input  logic [2:0]         widx, ridx,
  input  logic               we,
  output logic [IdWidth:0]   rd_o
);
  localparam type id_t = logic [IdWidth-1:0];
  localparam int unsigned HtCapacity = (2**IdWidth <= Capacity) ? 2**IdWidth : Capacity;
  typedef struct packed {
    logic [IdWidth-1:0] id;
    logic               free;
  } ht_t;
  ht_t [HtCapacity-1:0] ht_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) ht_q <= '0;
    else if (we) begin
      ht_q[widx].id   <= id_i;
      ht_q[widx].free <= ~ht_q[widx].free;
    end
  end
  assign rd_o = {ht_q[ridx].id, ht_q[ridx].free};
endmodule
