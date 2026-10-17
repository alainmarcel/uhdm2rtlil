// Ports declared with the `var` keyword and a packed range --
// rggen_bit_field_counter: `input var [UP_PORT_WIDTH-1:0] i_up`.
//
// Surelog had no typespec case for `var_data_type` with a packed range and
// rejected the port ([ERR:UH0705] Unsupported data type), leaving it without
// a typespec: every consumer saw a 1-bit port and rggen block_0's counter
// bit field came out `o_count` resized 8 -> 1.  Fixed upstream
// (chipsalliance/Surelog#4217); this pins the bump.
module dut #(
  parameter int UP_PORT_WIDTH   = 3,
  parameter int DOWN_PORT_WIDTH = 2,
  parameter int WIDTH           = 8
)(
  input   var                       i_clk,
  input   var                       i_rst_n,
  input   var                       i_clear,
  input   var [UP_PORT_WIDTH-1:0]   i_up,
  input   var [DOWN_PORT_WIDTH-1:0] i_down,
  output  var [WIDTH-1:0]           o_count
);
  logic [WIDTH-1:0] count;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)      count <= '0;
    else if (i_clear)  count <= '0;
    else               count <= count + WIDTH'(i_up) - WIDTH'(i_down);
  end
  assign o_count = count;
endmodule
