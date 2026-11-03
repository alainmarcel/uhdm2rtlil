// A dynamic-index element write to an unpacked array declared INSIDE a
// generate scope.  The array's element wires live under the scoped name
// (`\BP.arr[0]`) while the bit_select names it bare (`arr`); the element
// writer probed the module for `\arr[0]`, found nothing, and the write fell
// through to the generic LHS import -- onto a dangling temp, so the array
// never changed.  biriscv_npc's branch-target buffer (allocated on a miss
// inside `if (SUPPORT_BRANCH_PREDICTION) begin: BRANCH_PREDICTION`) was looked
// up as empty forever: riscv_core diverged from cycle 40 on its fetch PC.
// The same array at module level was always written correctly.
module dut #(parameter EN = 1) (
    input         clk,
    input         rst,
    input         we,
    input  [4:0]  wa,
    input  [31:0] wd,
    input  [4:0]  ra,
    output [31:0] rd,
    output reg    hit
);
generate
if (EN) begin: BP
    reg [31:0] arr [31:0];
    integer i;
    always @(posedge clk or posedge rst)
    if (rst) begin
        for (i = 0; i < 32; i = i + 1) arr[i] <= 32'b0;
    end
    else if (we)
        arr[wa] <= wd;
    assign rd = arr[ra];
    integer j;
    always @* begin
        hit = 1'b0;
        for (j = 0; j < 32; j = j + 1)
            if (arr[j] == wd) hit = 1'b1;
    end
end
endgenerate
endmodule
