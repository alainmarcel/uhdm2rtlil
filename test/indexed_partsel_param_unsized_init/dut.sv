// A RUNTIME-indexed part-select of a vector PARAMETER whose initialiser is
// UNSIZED (`localparam [5:15] p = 1436;`): the value arrives as a 32/64-bit
// constant, so the declared-range mapping's width check failed and the raw
// index drove the $shiftx -- YosysHQ/yosys#3689's own snippet
// (`localparam [5:15] p = 51681708; p[15 + x -: 5]`) read the wrong bits for
// every x.  The value must take the DECLARED width first: truncated when the
// initialiser is wider (q), zero-extended when narrower.  The selects live in
// a CHILD module, as in the issue: at the top the value was already sized.
module sel (input  logic [1:0] x,
            output logic [4:0] yp, yq, yu,
            output logic [3:0] yr);
  localparam [5:15] p = 1436;       // 11'b10110011100
  localparam [5:15] q = 51681708;   // wider than 11 bits: truncated
  localparam [12:3] r = 813;        // descending, non-zero base
  assign yp = p[11 + x -: 5];
  assign yq = q[11 + x -: 5];
  assign yu = p[5 + x +: 5];
  assign yr = r[3 + x +: 4];
endmodule
module dut (input  logic [1:0] x,
            output logic [4:0] yp, yq, yu,
            output logic [3:0] yr);
  sel u_sel (.x, .yp, .yq, .yu, .yr);
endmodule
