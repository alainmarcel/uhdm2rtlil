// Instance OUTPUT port connected to an ELEMENT of a generate-scope unpacked
// struct array (ibex_cs_registers' g_pmp_csrs[i].u_pmp_cfg_csr:
// `.rd_data_o(pmp_cfg[i])`) — the connection imported as a constant X
// ("Output port ... is connected to constants: 6'x") and hierarchy -check
// errored out.
package oea_pk;
  typedef struct packed {
    logic [1:0] m;
    logic [3:0] v;
  } s_t;
endpackage

module oea_sub (
  input  logic [5:0]  d_i,
  output oea_pk::s_t  q_o
);
  assign q_o = d_i ^ 6'h15;
endmodule

module inst_out_elem_array import oea_pk::*; (
  input  logic [23:0] d_i,
  output logic [11:0] m_o
);
  if (1) begin : g_regs
    s_t arr [4];
    for (genvar i = 0; i < 4; i++) begin : g_csr
      oea_sub u_csr (
        .d_i (d_i[i*6 +: 6]),
        .q_o (arr[i])
      );
    end
    for (genvar i = 0; i < 4; i++) begin : g_rd
      assign m_o[i*3 +: 3] = {arr[i].m, ^arr[i].v};
    end
  end
endmodule
