// A signal whose NAME merely contains the substring "memory" is not a memory.
//
// `UhdmMemoryAnalyzer::is_memory_declaration` used to return true for any
// vpiReg / vpiLogicNet whose name contained "memory", and extract_memory_info()
// then invented width=8 size=16 ("default values based on simple_memory test").
// Every select on such a signal was lowered to a $memrd of that phantom memory,
// i.e. to garbage.
//
// XiangShan's DeqModule has a 3-bit INPUT PORT `io_rdataDataEntries_0_memoryType`;
// `assign ... = ~(io_rdataDataEntries_0_memoryType[2])` therefore read a $memrd
// and the whole StoreQueue co-simulation diverged from cycle 0.
module dut(
  input  [2:0] memoryType,       // packed input port, NOT a memory
  input  [2:0] plain,            // the same thing under a neutral name
  input        clk,
  input  [3:0] addr,
  input  [7:0] wdata,
  input        we,
  output       o_not_bit2,       // the exact DeqModule shape
  output       o_plain_bit2,     // control: must be identical to o_not_bit2's logic
  output [2:0] o_whole,
  output [7:0] o_mem_rd
);
  // a REAL memory in the same module, so the fix cannot work by disabling
  // memory inference altogether
  reg [7:0] memory [0:15];
  reg [7:0] rdata;
  always @(posedge clk) begin
    if (we) memory[addr] <= wdata;
    rdata <= memory[addr];
  end

  assign o_not_bit2   = ~(memoryType[2]);
  assign o_plain_bit2 = ~(plain[2]);
  assign o_whole      = memoryType;
  assign o_mem_rd     = rdata;
endmodule
