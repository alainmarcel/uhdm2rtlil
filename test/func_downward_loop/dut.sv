// A function with a downward for-loop `for (i=N-1; i>0; i--)` carrying a
// loop dependency (dec_tmp[i-1] reads dec_tmp[i] written the prior iter), plus
// an operation-valued init (PTR_WIDTH-1).  Both the downward direction and the
// non-constant init were previously unsupported by the function-inliner
// unroller, so the loop body was dropped and the result collapsed to 0.
module func_downward_loop #(parameter int Depth = 8) (
  input  logic [$clog2(Depth):0] grayval,
  output logic [$clog2(Depth):0] dec);
  localparam int PTR_WIDTH = $clog2(Depth) + 1;
  function automatic [PTR_WIDTH-1:0] gray2dec(input [PTR_WIDTH-1:0] grayval);
    logic [PTR_WIDTH-1:0] dec_tmp;
    begin
      dec_tmp = '0;
      for (int unsigned i = PTR_WIDTH-1; i > 0; i--)
        dec_tmp[i-1] = dec_tmp[i] ^ grayval[i-1];
      gray2dec = dec_tmp;
    end
  endfunction
  assign dec = gray2dec(grayval);
endmodule
