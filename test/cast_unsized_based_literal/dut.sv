// A size cast of an UNSIZED BASED literal: `3'('b11)`.  Surelog gives
// VpiSize == -1 to every unsized literal, the based ones included, and the
// cast handler took that alone as "fill literal" and replicated the value's
// state to the cast width: `3'('b11)` became 3'b111, `4'('b11)` 4'b1111.  Only
// the unbased kind (`'1`, `'0`, `'x`, `'z`) self-replicates; a based unsized
// literal is an ordinary unsigned value, zero-extended (LRM 5.7.1).  VeeR EH2's
// eh2_lsu_lsc_ctl masks its address offset with exactly this shape,
// `({pt.BUS_ADDR_OFF{half}} & (pt.BUS_ADDR_OFF)'('b1)) | ({...{word}} &
// (pt.BUS_ADDR_OFF)'('b11)) | ...`, so every word access computed a
// double-word end address (213 diverging co-simulated cycles).
module dut (
    input  logic       h,
    input  logic       w,
    input  logic       d,
    output logic [2:0] off,
    output logic [3:0] mask4,
    output logic [2:0] sel,
    output logic [2:0] ones,
    output logic [2:0] zeros
);
    assign off   = ({3{h}} & 3'('b1)) | ({3{w}} & 3'('b11)) | ({3{d}} & 3'('b111));
    assign mask4 = {4{w}} & 4'('b11);
    assign sel   = w ? 3'('b11) : 3'('b0);
    assign ones  = 3'('1);      // the genuine fill literal must still replicate
    assign zeros = 3'('0);
endmodule
