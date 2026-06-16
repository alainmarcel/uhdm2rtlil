package my_pkg;
   typedef struct packed {
      logic p;
   } ast_dif_t;

   typedef struct packed {
      ast_dif_t [1:0] alerts_ack;
   } ast_alert_rsp_t;
endpackage // my_pkg

// Exercise nested struct → packed-array-of-struct → field access
// (`ast_alert_o.alerts_ack[i].p`) with every element driven so the design is
// fully controllable/observable (no dead undriven-X bits).
module top(input [1:0] din, output [1:0] o);
   my_pkg::ast_alert_rsp_t ast_alert_o;
   always_comb begin
      for (int i = 0; i < 2; i++) begin
         ast_alert_o.alerts_ack[i].p = din[i];
      end
   end
   assign o = {ast_alert_o.alerts_ack[1].p, ast_alert_o.alerts_ack[0].p};
endmodule // top
