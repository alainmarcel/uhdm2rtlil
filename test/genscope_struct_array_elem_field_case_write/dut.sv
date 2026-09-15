// Per-element FIELD writes into an unpacked array of packed structs from a
// genvar loop nested in an if-generate (ibex's `if (PMPEnable)`), one field from an always_comb CASE and the others from
// continuous assigns (lowRISC ibex_cs_registers' PMP config write data,
// `pmp_cfg_wdata[i].mode = PMP_MODE_TOR;` for PMPEnable=1 — the OpenTitan
// Egret top): read_uhdm segfaulted in emit_dynamic_array_elem_field_write.
package genscope_struct_array_elem_field_case_write_pkg;
  typedef enum logic [1:0] { MODE_OFF = 2'b00, MODE_TOR = 2'b01, MODE_NA4 = 2'b10, MODE_NAPOT = 2'b11 } mode_e;
  typedef struct packed { logic lock; mode_e mode; logic exec; logic write; logic read; } cfg_t;
endpackage
module genscope_struct_array_elem_field_case_write
  import genscope_struct_array_elem_field_case_write_pkg::*;
#(parameter bit En = 1, parameter int unsigned N = 4, parameter int unsigned G = 0) (
  input  logic [31:0]  wdata_i,
  output logic [6*4-1:0] cfg_o
);
  localparam int unsigned W = 8;
  if (En) begin : g_pmp
  cfg_t cfg_wdata [N];
  for (genvar i = 0; i < N; i++) begin : g_cfg
    assign cfg_wdata[i].lock = wdata_i[(i%4)*W+7];
    always_comb begin
      unique case (wdata_i[(i%4)*W+3+:2])
        2'b00   : cfg_wdata[i].mode = MODE_OFF;
        2'b01   : cfg_wdata[i].mode = MODE_TOR;
        2'b10   : cfg_wdata[i].mode = (G == 0) ? MODE_NA4 : MODE_OFF;
        2'b11   : cfg_wdata[i].mode = MODE_NAPOT;
        default : cfg_wdata[i].mode = MODE_OFF;
      endcase
    end
    assign cfg_wdata[i].exec  = wdata_i[(i%4)*W+2];
    assign cfg_wdata[i].write = wdata_i[(i%4)*W+1];
    assign cfg_wdata[i].read  = wdata_i[(i%4)*W];
    assign cfg_o[i*6 +: 6] = cfg_wdata[i];
  end
  end else begin : g_no_pmp
    assign cfg_o = '0;
  end
endmodule
