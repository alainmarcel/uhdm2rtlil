// An initial block's nonblocking assignment reads the values the block has
// set so far; only the write is deferred.  `a = 0; b = 1; a <= b; b <= a;`
// ends with a = 1, b = 0 (yosys#1400).  read_uhdm emitted `a := b`,
// `b := a`, two continuous connects aliasing a and b.
module dut(input logic [3:0] d, output logic [3:0] y, output logic [3:0] w);
  logic a, b;
  logic [3:0] c;
  initial begin
    a = 0;
    b = 1;
    a <= b;
    b <= a;
    c = 4'd5;
    c <= c + 4'd2;   // reads 5, writes 7
  end
  assign y = d ^ {2'b00, a, b};
  assign w = d ^ c;
endmodule
