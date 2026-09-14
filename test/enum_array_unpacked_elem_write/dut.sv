// Unpacked array of PACKED ENUM arrays written element-by-element from
// generate loops (OpenTitan aes_control's `sp2v_e [NumRegsKey-1:0]
// key_init_we_o [NumSharesKey]`, `assign key_init_we_o[s][i] = sp2v_e'(...)`).
// Surelog elaborates the element as a packed_array_var carrying the packed
// dims itself with an enum_var element (no packed_array_typespec), so the
// second index fell to the bit-select path and each 3-bit write landed on ONE
// bit: key_init_we_o read 0 instead of {NumRegsKey{SP2V_LOW}}.
module enum_array_unpacked_elem_write (
  input  logic [7:0][2:0] x,
  output logic [47:0]     flat_o
);
  localparam int NS = 2, NR = 8, W = 3;
  typedef enum logic [W-1:0] { Q_HIGH = 3'b011, Q_LOW = 3'b100 } q_e;
  logic [W-1:0][NS-1:0][NR-1:0] int_we;
  logic [NS-1:0][NR-1:0][W-1:0] log_we;
  q_e   [NR-1:0]               we [NS];
  for (genvar j = 0; j < W; j++) begin : g_j
    for (genvar s = 0; s < NS; s++) begin : g_s
      for (genvar i = 0; i < NR; i++) begin : g_i
        assign int_we[j][s][i] = x[i][j] ^ s[0];
      end
    end
  end
  for (genvar s = 0; s < NS; s++) begin : c_s
    for (genvar i = 0; i < NR; i++) begin : c_i
      for (genvar j = 0; j < W; j++) begin : c_j
        assign log_we[s][i][j] = int_we[j][s][i];
      end
      assign we[s][i] = q_e'(log_we[s][i]);
    end
    assign flat_o[s*24 +: 24] = we[s];
  end
endmodule
