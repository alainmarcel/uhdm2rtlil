// A constant part-select of a register declared with a NON-ZERO LSB
// (`reg [31:16] fill`), read while its value is IN FLIGHT inside the same
// combinational block, in a CHILD module.  In the module definition the
// part_select carries no Actual_group, so the declared range was never found:
// `fill[31:30]` was sliced at the declared indices of a 16-bit value and came
// back X.  biriscv's ALU (`shift_right_fill_r[31:24]`, the arithmetic-shift
// fill) lost every fill bit -- but only as a child of biriscv_exec; the ALU
// read on its own (top-level, elaborated, Actual_group present) was fine.
// SRA of 0xdea00812 by 10 must give 0xfff7a802, not 0x0037a802.
module alu (
    input  [31:0] a,
    input  [4:0]  b,
    input         arith,
    output reg [31:0] y
);
reg [31:16] fill;
reg [31:0]  s1, s2, s4, s8;
always @* begin
    fill = 16'b0; s1 = 32'b0; s2 = 32'b0; s4 = 32'b0; s8 = 32'b0;
    if (a[31] == 1'b1 && arith) fill = 16'hffff; else fill = 16'h0;
    if (b[0]) s1 = {fill[31], a[31:1]};        else s1 = a;
    if (b[1]) s2 = {fill[31:30], s1[31:2]};    else s2 = s1;
    if (b[2]) s4 = {fill[31:28], s2[31:4]};    else s4 = s2;
    if (b[3]) s8 = {fill[31:24], s4[31:8]};    else s8 = s4;
    if (b[4]) y  = {fill[31:16], s8[31:16]};   else y  = s8;
end
endmodule

module dut (
    input  [31:0] a,
    input  [4:0]  b,
    input         arith,
    output [31:0] y
);
    alu u_alu (.a(a), .b(b), .arith(arith), .y(y));
endmodule
