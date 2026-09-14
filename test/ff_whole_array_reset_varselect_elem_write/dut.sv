// Whole-array reset (`q <= '{default: '0}`) + nested-loop two-index element
// writes (`q[s][i] <= d[s][i]`, unpacked element + packed word) in one
// always_ff — OpenTitan aes_core's key_init_reg.  The async-reset assignment
// path derived no signal name for a var_select LHS, so the element write
// landed on the alias element wire \q[s] instead of the process's flat `$0\q`
// slice and the sync update overwrote it: the key shares stayed 0 and the
// assembled AES produced a wrong ciphertext (aes_wrap co-sim, cycle 139).
package k_pkg;
  typedef enum logic [2:0] { SP2V_HIGH = 3'b011, SP2V_LOW = 3'b100 } sp2v_e;
  typedef enum logic [4:0] { KEY_INIT_INPUT = 5'b10100, KEY_INIT_KEYMGR = 5'b01011, KEY_INIT_CLEAR = 5'b01110 } key_init_sel_e;
endpackage
module ff_whole_array_reset_varselect_elem_write import k_pkg::*; (
  input  logic clk_i, input logic rst_ni,
  input  logic [4:0] sel_raw,
  input  logic [2*4*8-1:0] a_flat, input logic [2*4*8-1:0] b_flat, input logic [2*4*8-1:0] c_flat,
  input  logic [2*4*3-1:0] we_flat,
  output logic [2*4*8-1:0] d_flat, output logic [2*4*8-1:0] q_flat
);
  localparam int NS = 2, NR = 4;
  logic [NR-1:0][7:0] a [NS]; logic [NR-1:0][7:0] b [NS]; logic [NR-1:0][7:0] c [NS];
  logic [NR-1:0][7:0] d [NS]; logic [NR-1:0][7:0] q [NS];
  sp2v_e [NR-1:0] we [NS];
  key_init_sel_e sel;
  assign sel = key_init_sel_e'(sel_raw);
  for (genvar s = 0; s < NS; s++) begin : g
    assign a[s] = a_flat[s*32 +: 32]; assign b[s] = b_flat[s*32 +: 32]; assign c[s] = c_flat[s*32 +: 32];
    assign d_flat[s*32 +: 32] = d[s]; assign q_flat[s*32 +: 32] = q[s];
    for (genvar i = 0; i < NR; i++) begin : gi
      assign we[s][i] = sp2v_e'(we_flat[(s*NR+i)*3 +: 3]);
    end
  end
  always_comb begin : key_init_mux
    unique case (sel)
      KEY_INIT_INPUT:  d = a;
      KEY_INIT_KEYMGR: d = b;
      KEY_INIT_CLEAR:  d = c;
      default:         d = c;
    endcase
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : key_init_reg
    if (!rst_ni) begin
      q <= '{default: '0};
    end else begin
      for (int s = 0; s < NS; s++) begin
        for (int i = 0; i < NR; i++) begin
          if (we[s][i] == SP2V_HIGH) begin
            q[s][i] <= d[s][i];
          end
        end
      end
    end
  end
endmodule
