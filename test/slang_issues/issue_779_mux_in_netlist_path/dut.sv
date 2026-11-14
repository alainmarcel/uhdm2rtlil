// MikePopoloski/slang#779 (closed): Mux in netlist path
// https://github.com/MikePopoloski/slang/issues/779
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module mux(input a, input b, input sel, output reg f);

always @(*) begin
  if (sel == 1'b0) begin
    f = a;
  end else begin
    f = b;
  end
end

endmodule

