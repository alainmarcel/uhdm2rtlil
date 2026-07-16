// A `unique case` with an EXPLICIT default clause: unlisted selects must take
// the default expression (c), NOT x. (rp32 r5p_degu ifu_pcn next-PC case.)
module unique_case_default (
    input  logic [1:0] sel,
    input  logic [7:0] a, b, c,
    output logic [7:0] y
);
    always_comb
        unique case (sel)
            2'b00:   y = a;
            2'b01:   y = b;
            default: y = c;
        endcase
endmodule
