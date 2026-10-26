// Attributes written on a MEMORY declaration must reach the RTLIL memory, as
// they do through read_verilog and read_slang:
//
//     (* no_rw_check, ram_style = "block" *) reg [31:0] banks_0 [0:1023];
//
// is how SpinalHDL / VexRiscv (and so every LiteX SoC) declares its caches.
// `no_rw_check` is not decoration: yosys's memory_dff reads it and marks a
// read-during-write collision on that memory as don't-care
// (RD_COLLISION_X_MASK), so a reader that drops it produces a memory with
// DIFFERENT formal semantics -- the read_slang side of the miter had a free
// value where ours returned the old word, and the InstructionCache row read
// `differs` on a design whose co-simulation agreed on every cycle.
//
// One memory per declaration path: a Verilog `reg` array (array_net) and a
// SystemVerilog `logic` array (array_var).
module dut(
  input             clk,
  input             we,
  input             re,
  input      [3:0]  waddr,
  input      [3:0]  raddr,
  input      [7:0]  wdata,
  output reg [7:0]  rdata_a,
  output reg [7:0]  rdata_b
);
  (* no_rw_check, ram_style = "block" *) reg   [7:0] mem_a [0:15];
  (* no_rw_check, ram_style = "block" *) logic [7:0] mem_b [0:15];

  always @(posedge clk) begin
    if (we) mem_a[waddr] <= wdata;
    if (re) rdata_a <= mem_a[raddr];
  end

  always_ff @(posedge clk) begin
    if (we) mem_b[waddr] <= ~wdata;
    if (re) rdata_b <= mem_b[raddr];
  end
endmodule
