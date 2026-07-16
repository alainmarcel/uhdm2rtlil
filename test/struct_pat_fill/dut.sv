// Struct assignment pattern with fill literals INSIDE A FUNCTION returning a
// struct. `dec.gpr = '{'1,'0,'0}` must assign each field (100), not replicate a
// fill across all fields. The return struct is deliberately wide AND its width
// is a multiple of the field count (idx[5:0]+gpr[2:0] = 9, 9%3==0) to exercise
// the same path as rp32's 306-bit dec_t (306%3==0). (rp32 dec32 gpr enable.)
module struct_pat_fill (
    input  logic [1:0] sel,
    output logic [2:0] out
);
    typedef struct packed { logic rd; logic rs1; logic rs2; } ena_t;
    typedef struct packed { logic [5:0] idx; ena_t gpr; } dec_t;

    function automatic dec_t decode (input logic [1:0] s);
        decode.idx = 6'd0;
        unique case (s)
            2'd0:    decode.gpr = '{'1, '0, '0};   // 100
            2'd1:    decode.gpr = '{'0, '1, '1};   // 011
            2'd2:    decode.gpr = '{'1, '1, '0};   // 110
            default: decode.gpr = '{'0, '0, '0};   // 000
        endcase
    endfunction

    dec_t d;
    assign d = decode(sel);
    assign out = d.gpr;
endmodule
