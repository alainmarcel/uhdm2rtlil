// YosysHQ/yosys#27 (closed): problem with HLS generated code
// https://github.com/YosysHQ/yosys/issues/27
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module lshift_expr_FU(in1, in2, out1);
  parameter BITSIZE_in1=1, BITSIZE_in2=1, BITSIZE_out1=1, PRECISION=32;
  // IN
  input signed [BITSIZE_in1-1:0] in1;
  input [BITSIZE_in2-1:0] in2;
  // OUT
  output signed [BITSIZE_out1-1:0] out1;
  `ifndef __ICARUS__
    function integer log2;
       input integer value;
       integer temp_value;
      begin
        temp_value = value-1;
        for (log2=0; temp_value>0; log2=log2+1)
          temp_value = temp_value>>1;
      end
    endfunction
  `endif
  `ifdef __ICARUS__
    parameter arg2_bitsize = $clog2(PRECISION);
  `else
    parameter arg2_bitsize = log2(PRECISION);
  `endif
  assign out1 = in1 <<< in2[arg2_bitsize-1:0];
endmodule

