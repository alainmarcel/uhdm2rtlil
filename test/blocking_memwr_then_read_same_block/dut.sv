// A BLOCKING write to a memory followed by a read of the same memory in the
// same clocked block (biriscv's dcache_core_tag_ram):
//
//     if (wr1_i) ram[addr1_i] = data1_i;
//     ram_read0_q = ram[addr0_i];
//
// LRM 10.4.1: `=` takes effect before the next statement, so a read of the
// address just written must return the new data.  read_uhdm kept the $memwr on
// the sync rule and read the REGISTERED word, so a same-address read missed
// the write (formal `differs` against read_slang on the real RAM; read_verilog
// builds the bypass mux through mem2reg).  Non-blocking writes stay invisible.
module dut (
    input         clk,
    input  [3:0]  addr0_i,
    input  [3:0]  addr1_i,
    input  [7:0]  data1_i,
    input         wr1_i,
    output [7:0]  data0_o
);
reg [7:0] ram [15:0];
reg [7:0] ram_read0_q;
always @(posedge clk) begin
    if (wr1_i)
        ram[addr1_i] = data1_i;
    ram_read0_q = ram[addr0_i];
end
assign data0_o = ram_read0_q;
endmodule
