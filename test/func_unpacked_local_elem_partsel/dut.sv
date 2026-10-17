// A function-local UNPACKED array element written through a trailing
// part-select -- rggen_bit_field's get_hw_next_value:
//
//     logic [WIDTH-1:0] set_clear[2];
//     ...
//     else if (HW_SET_WIDTH == WIDTH) begin
//       set_clear[0][HW_SET_WIDTH-1:0] = set;
//     end
//
// The var_select LHS resolver took its dimensions only from a PACKED
// logic_typespec on the select's Actual_group; a function-local unpacked
// array carries no Actual_group and its dims live on the declaration
// (array_var over a logic_var), so the write was dropped with
// "var-select LHS set_clear: could not resolve constant slice" and the
// hardware-set path of every rggen bit field with HW_ACCESS[1] set never
// set anything (block_0, 282 diverging co-simulated cycles).
//
// The same array is also written whole (`set_clear[1] = {WIDTH{clear[0]}}`)
// and read bit-by-bit in the loop, which already worked -- so a wrong
// element offset here shows up as the wrong element being set.
module dut #(
  parameter int WIDTH       = 4,
  parameter int SET_WIDTH   = WIDTH,
  parameter int CLEAR_WIDTH = 1
) (
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic [SET_WIDTH-1:0]   set,
  input  logic [CLEAR_WIDTH-1:0] clear,
  input  logic                   we,
  input  logic [WIDTH-1:0]       wd,
  output logic [WIDTH-1:0]       q
);
  function automatic logic [WIDTH-1:0] next_value(
    logic [WIDTH-1:0]       cur,
    logic                   write_enable,
    logic [WIDTH-1:0]       write_data,
    logic [SET_WIDTH-1:0]   set,
    logic [CLEAR_WIDTH-1:0] clear
  );
    logic [WIDTH-1:0] set_clear[2];
    logic [WIDTH-1:0] value;

    if (SET_WIDTH == WIDTH) begin
      set_clear[0][SET_WIDTH-1:0] = set;
    end
    else begin
      set_clear[0] = {WIDTH{set[0]}};
    end

    if (CLEAR_WIDTH == WIDTH) begin
      set_clear[1][CLEAR_WIDTH-1:0] = clear;
    end
    else begin
      set_clear[1] = {WIDTH{clear[0]}};
    end

    for (int i = 0; i < WIDTH; ++i) begin
      if (set_clear[0][i]) begin
        value[i] = '1;
      end
      else if (set_clear[1][i]) begin
        value[i] = '0;
      end
      else if (write_enable) begin
        value[i] = write_data[i];
      end
      else begin
        value[i] = cur[i];
      end
    end

    return value;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= '0;
    else        q <= next_value(q, we, wd, set, clear);
  end
endmodule
