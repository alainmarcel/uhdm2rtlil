// MikePopoloski/slang#1120 (closed): [slang-tidy] Internal generate variables of always_ff incorrectly triggers RegisterHasNoReset warning
// https://github.com/MikePopoloski/slang/issues/1120
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test (__i_clk_i, __i_rst_ni, __o_k);
    logic [7:0] k;
    logic clk_i;
    logic rst_ni;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if(~rst_ni) begin
        k <= '{default: '0};
      end else begin
        for(int i = 0; i < 8; i += 1) begin
          if (i % 2) k[i] <= i[0];
          else k[i] <= i[1];
        end
      end
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk_i;
  assign clk_i = __i_clk_i;
  input logic __i_rst_ni;
  assign rst_ni = __i_rst_ni;
  output logic [7:0] __o_k;
  assign __o_k = k;
endmodule

