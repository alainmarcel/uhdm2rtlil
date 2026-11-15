// An ABSOLUTE hierarchical reference through generate scopes
// (`top.dut.g[0].genblk1.i.innermost`, MikePopoloski/slang#1433) reads the
// signal inside the instance.  read_uhdm left it unresolved (X): the path
// starts with the module's own name, an element is an indexed generate scope,
// and the cell inside the scope is named `g[0].genblk1.i`.
module inner(input logic [3:0] d);
  wire [3:0] innermost = ~d;
endmodule
module example(input logic [3:0] d);
  for (genvar g = 0; g < 2; g++) begin : gg
    if (g == 0) begin
      inner i(.d(d));
    end else begin
      inner i(.d(d ^ 4'hf));
    end
  end
endmodule
module top(input logic [3:0] d, output logic [3:0] y0, output logic [3:0] y1);
  example dut(.d(d));
  assign y0 = top.dut.gg[0].genblk1.i.innermost;   // ~d
  assign y1 = dut.gg[1].genblk1.i.innermost;       // relative form: d
endmodule
