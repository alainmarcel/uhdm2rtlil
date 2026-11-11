// Narrow lowering of $shiftx / $shift cells whose shift amount is SIGNED.
//
// write_verilog spells such a cell `A[$signed(B) +: W]`, which Verilator reads
// as 0 for a negative base (verilator/verilator#8657), so the co-sim scripts
// lower them before writing (#1542).  The generic +/techmap.v expansion is a
// barrel shifter over EVERY bit of B: an `int` index (32 bits) over a 4608-bit
// vector (OpenTitan keymgr's key shares) becomes ~150k cells per cell and the
// netlist 97 MB -- "netlist unbuildable" on the runner.  Only clog2(A_WIDTH)+1
// bits of B can select anything; every larger magnitude is out of range.
//
// Semantics kept exactly:
//   $shiftx: Y = A >> B with X shifted in; B < 0 shifts A LEFT by -B with X
//            shifted in (a part-select whose base is below 0).  |B| beyond the
//            vector is all X.
//   $shift:  same with 0 shifted in.
// The unsigned residual shifts stay $shiftx/$shift cells with B_SIGNED = 0,
// which write_verilog spells `A[B +: W]` / `A >> B`, read correctly by Verilator.
(* techmap_celltype = "$shiftx" *)
module _uhdm2rtlil_signed_shiftx (A, B, Y);
    parameter A_SIGNED = 0;
    parameter B_SIGNED = 0;
    parameter A_WIDTH = 1;
    parameter B_WIDTH = 1;
    parameter Y_WIDTH = 1;
    input [A_WIDTH-1:0] A;
    input [B_WIDTH-1:0] B;
    output [Y_WIDTH-1:0] Y;
    // enough bits for any in-range magnitude (plus one guard bit)
    localparam integer NB = (A_WIDTH + Y_WIDTH) > 1 ? $clog2(A_WIDTH + Y_WIDTH) + 1 : 2;
    localparam integer KB = (NB < B_WIDTH) ? NB : B_WIDTH;
    wire neg = B_SIGNED ? B[B_WIDTH-1] : 1'b0;
    wire [B_WIDTH-1:0] mag = neg ? (~B + 1'b1) : B;          // |B|
    wire big = (B_WIDTH > KB) ? |mag[B_WIDTH-1:KB] : 1'b0;   // |B| beyond any in-range index
    wire [KB-1:0] amt = mag[KB-1:0];
    // right shift with X fill: a $shiftx with an UNSIGNED amount
    wire [Y_WIDTH-1:0] yr;
    \$shiftx #(.A_SIGNED(0), .B_SIGNED(0), .A_WIDTH(A_WIDTH), .B_WIDTH(KB), .Y_WIDTH(Y_WIDTH)) sr (.A(A), .B(amt), .Y(yr));
    // left shift with X fill: shift A left by |B|, X in the vacated low bits
    wire [A_WIDTH+Y_WIDTH-1:0] axl = {{Y_WIDTH{1'bx}}, A} << amt;
    wire [Y_WIDTH-1:0] yl = axl[Y_WIDTH-1:0];
    assign Y = big ? {Y_WIDTH{1'bx}} : (neg ? yl : yr);
    generate if (B_SIGNED == 0) begin : _not_signed
        // only signed cells are selected by the callers; keep the generic map for others
        wire _TECHMAP_FAIL_ = 1;
    end endgenerate
endmodule

(* techmap_celltype = "$shift" *)
module _uhdm2rtlil_signed_shift (A, B, Y);
    parameter A_SIGNED = 0;
    parameter B_SIGNED = 0;
    parameter A_WIDTH = 1;
    parameter B_WIDTH = 1;
    parameter Y_WIDTH = 1;
    input [A_WIDTH-1:0] A;
    input [B_WIDTH-1:0] B;
    output [Y_WIDTH-1:0] Y;
    localparam integer NB = (A_WIDTH + Y_WIDTH) > 1 ? $clog2(A_WIDTH + Y_WIDTH) + 1 : 2;
    localparam integer KB = (NB < B_WIDTH) ? NB : B_WIDTH;
    wire neg = B_SIGNED ? B[B_WIDTH-1] : 1'b0;
    wire [B_WIDTH-1:0] mag = neg ? (~B + 1'b1) : B;
    wire big = (B_WIDTH > KB) ? |mag[B_WIDTH-1:KB] : 1'b0;
    wire [KB-1:0] amt = mag[KB-1:0];
    wire [Y_WIDTH-1:0] yr;
    \$shift #(.A_SIGNED(A_SIGNED), .B_SIGNED(0), .A_WIDTH(A_WIDTH), .B_WIDTH(KB), .Y_WIDTH(Y_WIDTH)) sr (.A(A), .B(amt), .Y(yr));
    wire [A_WIDTH+Y_WIDTH-1:0] axl = {{Y_WIDTH{1'b0}}, A} << amt;
    wire [Y_WIDTH-1:0] yl = axl[Y_WIDTH-1:0];
    wire [Y_WIDTH-1:0] ybig = A_SIGNED && !neg ? {Y_WIDTH{A[A_WIDTH-1]}} : {Y_WIDTH{1'b0}};
    assign Y = big ? ybig : (neg ? yl : yr);
    generate if (B_SIGNED == 0) begin : _not_signed
        wire _TECHMAP_FAIL_ = 1;
    end endgenerate
endmodule
