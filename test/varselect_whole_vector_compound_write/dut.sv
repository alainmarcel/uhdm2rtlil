module dut #(parameter int NT = 1, parameter int DEPTH = 8)
  (input logic [DEPTH-1:0] vld, input logic [DEPTH-1:0] tid, output logic [NT-1:0][3:0] num);
  always_comb begin
    num[NT-1:0] = '0;
    for (int i = 0; i < NT; i++) begin
      for (int j = 0; j < DEPTH; j++) begin
        num[i][3:0] += {3'b0, (vld[j] & (tid[j] == 1'(i)))};
      end
    end
  end
endmodule
