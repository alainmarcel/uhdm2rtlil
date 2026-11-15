// An unsized integer literal in a concatenation is 32 bits wide (LRM 5.7.1);
// Surelog sizes it 64.  {1, 2} into 64 bits must be 64'h0000_0001_0000_0002,
// not 64'h2 (MikePopoloski/slang#2082).
module dut(input logic [3:0] foo,
           output logic [63:0] c,
           output logic [35:0] e,
           output logic [15:0] a);
  assign c = {1, 2};
  assign e = {foo, 0};
  assign a = {{4}{foo}};
endmodule
