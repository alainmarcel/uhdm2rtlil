package p; typedef struct packed { logic valid; logic [63:0] data; logic [7:0] strb; } req_t; endpackage
module struct_array_elem_field_read(input logic [3*73-1:0] af, input logic [1:0] app_id, input logic sel, output logic [63:0] mask_o, output logic [63:0] mask2_o);
  p::req_t app_i [3];
  for (genvar k = 0; k < 3; k++) begin : g
    assign app_i[k] = af[k*73 +: 73];
  end
  always_comb begin
    mask_o = '0;
    mask2_o = '0;
    if (sel) begin
      for (int i = 0 ; i < $bits(app_i[app_id].strb) ; i++) begin
        mask_o[8*i+:8] = {8{app_i[app_id].strb[i]}};
      end
      for (int i = 0 ; i < 8 ; i++) begin
        mask2_o[8*i+:8] = {8{app_i[1].strb[i]}};
      end
    end
  end
endmodule
