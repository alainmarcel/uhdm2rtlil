// A `bit [W-1:0] RAM [D-1:0]` array (2-state element type) written with a
// dynamic index and read continuously, inside a named generate arm — cvw's
// generic ram1p1rwe.  is_memory_array recognised only a logic_typespec (or
// enum) element as a packed multi-bit element; a bit_typespec element with
// the same ranges was not a memory, so the array split into per-element
// wires, the dynamic `RAM[addr] <= din` was lost and every element read
// undriven (2816 undriven nets on ram1p1rwe, 69632 on ram2p1r1wbe).  A
// bit-typed packed element now infers a memory like a logic-typed one.
module bit_typed_memory_genscope #(
  parameter USE_SRAM = 0,
  parameter DEPTH = 16,
  parameter WIDTH = 8
) (
  input  logic                     clk,
  input  logic                     ce,
  input  logic                     we,
  input  logic [$clog2(DEPTH)-1:0] addr,
  input  logic [WIDTH-1:0]         din,
  output logic [WIDTH-1:0]         dout
);
  if (USE_SRAM == 1) begin
    assign dout = din;
  end else begin : ram
    bit [WIDTH-1:0]           RAM[DEPTH-1:0];
    logic [$clog2(DEPTH)-1:0] addrd;
    always_ff @(posedge clk) if (ce) addrd <= addr;
    assign dout = RAM[addrd];
    always @(posedge clk)
      if (ce & we)
        RAM[addr] <= din;
  end
endmodule
