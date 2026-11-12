// povik/sv-elab#78 (closed): Width cast of expression not propagating
// https://github.com/povik/sv-elab/issues/78
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
 module testcase
  #(localparam width_gp = 8
    , localparam lg_width_gp = $clog2(width_gp)
    )
   (input logic [lg_width_gp-1:0] in
    , output logic [width_gp-1:0] out
    );

   wire [width_gp-1:0] lo;
   wire [lg_width_gp-1:0] li;
   assign li = in;
   assign lo = (width_gp) ' (1'b1 << li);
   assign out = lo;

 endmodule

