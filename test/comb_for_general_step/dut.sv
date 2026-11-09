// A combinational for loop whose step is a GENERAL function of the loop
// variable (`n = n - (n/3)`, NVDLA's NV_DW02_tree carry-save reduction, used
// by every NV_NVDLA_CMAC multiplier).  Unpatched read_uhdm accepted only
// `++`/`--` and `n +/- const` steps, warned "Cannot unroll for loop in comb
// context (complex bounds)" and dropped the loop entirely.
// n = 20, 14, 10, 7, 5, 4, 3 (then 2 fails `n > 2`): sum 63, post-loop n = 2.
module dut (
    input  logic [7:0] a,
    input  logic [5:0] b,
    output logic [7:0] y,
    output logic [7:0] z,
    output logic [7:0] w
);
    integer n;
    logic [7:0] acc;
    logic [5:0] lanes [0:5];
    always @* begin
        acc = 0;
        for (n = 20; n > 2; n = n - (n / 3))
            acc = acc + n[7:0];
        y = acc ^ a;
        z = n[7:0];
    end
    // The tree's own shape: an array reduced in place, the live count
    // shrinking by num/3 each round.
    integer num, i;
    always @* begin
        for (i = 0; i < 6; i = i + 1) lanes[i] = b ^ i[5:0];
        for (num = 6; num > 2; num = num - (num / 3)) begin
            for (i = 0; i < num / 3; i = i + 1)
                lanes[i] = lanes[i * 3] ^ lanes[i * 3 + 1] ^ lanes[i * 3 + 2];
        end
        w = {2'b0, lanes[0]};
    end
endmodule
