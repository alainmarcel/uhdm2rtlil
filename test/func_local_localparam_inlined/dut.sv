// Function-local localparams referenced inside a RUNTIME (inlined) function
// -- rggen_bit_field_counter's calc_count_next:
//
//   localparam int             COUNT_NEXT_WIDTH = WIDTH + 1;
//   localparam bit [WIDTH-1:0] MIN_VALUE        = '0;
//   ...
//   logic [COUNT_NEXT_WIDTH-1:0] count_next;
//   ... return MIN_VALUE;
//
// Surelog does not bind those references to the parameters: it fabricates
// an implicit 1-bit logic_net of each name on the module and points the ref
// there, although the function's own Param_assigns carry the values.
// read_uhdm then read MIN_VALUE / MAX_VALUE / COUNT_NEXT_WIDTH /
// UP_DOWN_VALUE_WIDTH as undriven module wires ("Reference to unknown
// signal"), and rggen block_0's counter bit fields diverged.  Reading the
// value from the enclosing function's param_assign is the fix.
package clip_pkg;
  function automatic int clip_width(int width);
    return (width > 0) ? width : 1;
  endfunction
endpackage

module dut #(parameter int WIDTH = 8, parameter int UP_WIDTH = 3, parameter int DOWN_WIDTH = 2) (
  input  logic [WIDTH-1:0]      i_count,
  input  logic [UP_WIDTH-1:0]   i_up,
  input  logic [DOWN_WIDTH-1:0] i_down,
  output logic [WIDTH-1:0]      o_next
);
  import clip_pkg::*;
  function automatic logic [WIDTH-1:0] calc_count_next(
    logic [WIDTH-1:0]      count,
    logic [UP_WIDTH-1:0]   up,
    logic [DOWN_WIDTH-1:0] down
  );
    localparam int             UP_DOWN_WIDTH       = (UP_WIDTH > DOWN_WIDTH) ? UP_WIDTH : DOWN_WIDTH;
    localparam int             UP_DOWN_VALUE_WIDTH = clip_width($clog2(UP_DOWN_WIDTH + 1)) + 1;
    localparam int             COUNT_NEXT_WIDTH    = WIDTH + 1;
    localparam bit [WIDTH-1:0] MAX_VALUE           = '1;
    localparam bit [WIDTH-1:0] MIN_VALUE           = '0;
    logic [UP_DOWN_VALUE_WIDTH-1:0] up_down_value;
    logic [COUNT_NEXT_WIDTH-1:0]    count_next;
    up_down_value = UP_DOWN_VALUE_WIDTH'(0);
    for (int i = 0; i < UP_DOWN_WIDTH; ++i) begin
      logic [1:0] up_down;
      up_down[1] = (i < UP_WIDTH) && up[i];
      up_down[0] = (i < DOWN_WIDTH) && down[i];
      case (up_down)
        2'b10:   up_down_value = up_down_value + UP_DOWN_VALUE_WIDTH'(1);
        2'b01:   up_down_value = up_down_value - UP_DOWN_VALUE_WIDTH'(1);
        default: up_down_value = up_down_value;
      endcase
    end
    count_next = COUNT_NEXT_WIDTH'(count) +
                 {{(COUNT_NEXT_WIDTH-UP_DOWN_VALUE_WIDTH){up_down_value[UP_DOWN_VALUE_WIDTH-1]}}, up_down_value};
    if (!count_next[COUNT_NEXT_WIDTH-1])            return count_next[0+:WIDTH];
    else if (up_down_value[UP_DOWN_VALUE_WIDTH-1])  return MIN_VALUE;
    else                                            return MAX_VALUE;
  endfunction
  always_comb o_next = calc_count_next(i_count, i_up, i_down);
endmodule
