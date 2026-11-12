// povik/sv-elab#143 (open): `inout` ports unsupported if not using `--keep-hierarchy` option
// https://github.com/povik/sv-elab/issues/143
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module iocell_opendrain (
  inout  wire  pad,
  input  logic oe,
  output logic in
);
  assign in  = pad;
  assign pad = oe ? 1'b0 : 1'bz;
endmodule

module top (
  inout  wire  scl,
  input  logic drive_low,
  output logic sampled
);
  iocell_opendrain io_scl (
    .pad(scl),
    .oe (drive_low),
    .in (sampled)
  );
endmodule

