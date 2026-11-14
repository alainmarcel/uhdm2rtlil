// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r15); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r15
module r15sub(input [7:0] allbits, input [1:0] onebit, output bitout);
	assign bitout = allbits[onebit];
endmodule

module r15(__i_allbits, __i_onebit, __o_bitout);
	wire [17:10] bitout;
	reg [7:0] allbits;
	reg [15:0] onebit;
	r15sub sub [7:0] (allbits, onebit, bitout);

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [7:0] __i_allbits;
  assign allbits = __i_allbits;
  input logic [15:0] __i_onebit;
  assign onebit = __i_onebit;
  output logic [7:0] __o_bitout;
  assign __o_bitout = bitout;
endmodule

