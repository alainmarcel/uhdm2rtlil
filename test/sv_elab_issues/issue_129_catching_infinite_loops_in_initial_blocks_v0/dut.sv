// povik/sv-elab#129 (closed): Catching infinite loops in initial blocks
// https://github.com/povik/sv-elab/issues/129
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module m();
  initial
  begin
    forever begin
      #1;
    end
  end
endmodule

