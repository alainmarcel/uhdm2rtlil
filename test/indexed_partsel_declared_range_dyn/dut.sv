// A RUNTIME-indexed part-select (+: / -:) of a vector whose declared range is
// not [N-1:0]: ascending with a non-zero base (`[5:15]`, a localparam and a
// wire) and descending with a non-zero base (`[12:3]`).  The $shiftx was fed
// the raw source index, so every select read the wrong bits
// (YosysHQ/yosys#3689 `p[15 + x -: 5]`); a select running off the range must
// read X for the missing bits only.
module dut (input  logic [1:0]  x,
            input  logic [10:0] wv,
            input  logic [9:0]  dv,
            output logic [4:0]  yp, yw, yu,
            output logic [3:0]  yd, ye);
  localparam [5:15] p = 11'b10110011100;
  wire [5:15]  w = wv;
  wire [12:3]  d = dv;
  assign yp = p[11 + x -: 5];   // ascending localparam, -:
  assign yw = w[11 + x -: 5];   // ascending wire, -:
  assign yu = p[5 + x +: 5];    // ascending localparam, +:
  assign yd = d[3 + x +: 4];    // descending, non-zero base, +:
  assign ye = d[12 - x -: 4];   // descending, non-zero base, -:
endmodule
