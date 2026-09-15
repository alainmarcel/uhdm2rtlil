// {a[idx], b[idx]} = rhs with a dynamic index into packed 2-D arrays
// (OpenTitan otp_ctrl_ecc_reg p_write): each element write must land in its
// array, and the registers must capture it.
module comb_concat_lhs_dyn_packed_elem_write #(
  parameter int Depth = 3
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              wren_i,
  input  logic [1:0]        addr_i,
  input  logic [11:0]       wdata_i,
  output logic [Depth-1:0][3:0] ecc_o,
  output logic [Depth-1:0][7:0] data_o,
  output logic [7:0]        rdata_o,
  output logic [Depth-1:0][3:0] sh_a_o,
  output logic [Depth-1:0][7:0] sh_b_o
);
  logic [Depth-1:0][3:0] ecc_d, ecc_q;
  logic [Depth-1:0][7:0] data_d, data_q;

  always_comb begin : p_write
    data_d  = data_q;
    ecc_d   = ecc_q;
    rdata_o = '0;
    if (32'(addr_i) < Depth) begin
      rdata_o = data_q[addr_i];
      if (wren_i) begin
        {ecc_d[addr_i], data_d[addr_i]} = wdata_i;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_regs
    if (!rst_ni) begin
      ecc_q  <= {Depth{4'hA}};
      data_q <= '0;
    end else begin
      ecc_q  <= ecc_d;
      data_q <= data_d;
    end
  end

  // Unconditional concat write (no enclosing if) on top of the registers.
  always_comb begin : p_shadow
    sh_a_o = ecc_q;
    sh_b_o = data_q;
    {sh_a_o[addr_i], sh_b_o[addr_i]} = ~wdata_i;
  end

  assign ecc_o  = ecc_q;
  assign data_o = data_q;
endmodule
