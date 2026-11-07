// YosysHQ/yosys#5906 (closed): synth_nexus: DSP techmap should fuse MAC/preadd/dot-tree
// https://github.com/YosysHQ/yosys/issues/5906
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
  module mac (
      input  bit         clk, rst,
      input  bit [17:0]  a, b,
      input  bit         clear,
      output bit [47:0]  p
  );
      bit [17:0] a_r, b_r; bit clear_r; bit [47:0] p_r;
      always_ff @(posedge clk) begin
          if (rst) begin a_r<=0; b_r<=0; clear_r<=0; p_r<=0; end
          else begin
              a_r<=a; b_r<=b; clear_r<=clear;
              p_r <= clear_r ? 48'(a_r*b_r) : 48'(p_r + 48'(a_r*b_r));
          end
      end
      assign p = p_r;
  endmodule

// ---- b1.sv
  module madd_pre (
      input  bit         clk, rst,
      input  bit [17:0]  a, b, c, d,
      output bit [47:0]  p
  );
      bit [17:0] a_r, b_r, c_r, d_r; bit [47:0] m_r, p_r;
      always_ff @(posedge clk) begin
          if (rst) begin a_r<=0; b_r<=0; c_r<=0; d_r<=0; m_r<=0; p_r<=0; end
          else begin
              a_r<=a; b_r<=b; c_r<=c; d_r<=d;
              m_r <= 48'((a_r - d_r) * b_r);
              p_r <= 48'(m_r + 48'(c_r));
          end
      end
      assign p = p_r;
  endmodule

// ---- b2.sv
  module dot4 (
      input  bit         clk, rst,
      input  bit [8:0]   a0, b0, a1, b1, a2, b2, a3, b3,
      output bit [19:0]  p
  );
      bit [8:0]  a0_r, b0_r, a1_r, b1_r, a2_r, b2_r, a3_r, b3_r;
      bit [19:0] p_r;
      always_ff @(posedge clk) begin
          if (rst) begin
              a0_r<=0; b0_r<=0; a1_r<=0; b1_r<=0;
              a2_r<=0; b2_r<=0; a3_r<=0; b3_r<=0;
              p_r<=0;
          end else begin
              a0_r<=a0; b0_r<=b0; a1_r<=a1; b1_r<=b1;
              a2_r<=a2; b2_r<=b2; a3_r<=a3; b3_r<=b3;
              p_r <= 20'(20'(a0_r*b0_r) + 20'(a1_r*b1_r)
                       + 20'(a2_r*b2_r) + 20'(a3_r*b3_r));
          end
      end
      assign p = p_r;
  endmodule

