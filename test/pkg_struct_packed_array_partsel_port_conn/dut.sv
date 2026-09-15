// A packed array of packed STRUCTS whose type comes from a package, sliced
// per instance with a `[k:k]` / `[hi:lo]` part-select in the port connection
// (OpenTitan top_egret: `prim_alert_pkg::alert_tx_t [NAlerts-1:0] alert_tx;
// ... .alert_tx_o(alert_tx[1:1])`).  The slice was not scaled by the 2-bit
// element width: uart1's alert flop drove a bit of uart0's slice (conflicting
// drivers) and the alert handler's receiver inputs were left undriven.
package pkg_struct_packed_array_partsel_port_conn_pkg;
  typedef struct packed { logic alert_p; logic alert_n; } alert_tx_t;
endpackage

module pkg_struct_packed_array_partsel_port_conn_src #(parameter int N = 1) (
  input  logic [N-1:0] p_i,
  output pkg_struct_packed_array_partsel_port_conn_pkg::alert_tx_t [N-1:0] alert_tx_o
);
  for (genvar k = 0; k < N; k++) begin : g
    assign alert_tx_o[k].alert_p = p_i[k];
    assign alert_tx_o[k].alert_n = ~p_i[k];
  end
endmodule

module pkg_struct_packed_array_partsel_port_conn_sink #(parameter int N = 4) (
  input  pkg_struct_packed_array_partsel_port_conn_pkg::alert_tx_t [N-1:0] alert_tx_i,
  output logic [2*N-1:0] flat_o
);
  assign flat_o = alert_tx_i;
endmodule

module pkg_struct_packed_array_partsel_port_conn (
  input  logic [3:0] p_i,
  output logic [7:0] flat_o
);
  pkg_struct_packed_array_partsel_port_conn_pkg::alert_tx_t [3:0] alert_tx;
  pkg_struct_packed_array_partsel_port_conn_src #(.N(1)) u_a (.p_i(p_i[0]),   .alert_tx_o(alert_tx[0:0]));
  pkg_struct_packed_array_partsel_port_conn_src #(.N(1)) u_b (.p_i(p_i[1]),   .alert_tx_o(alert_tx[1:1]));
  pkg_struct_packed_array_partsel_port_conn_src #(.N(2)) u_c (.p_i(p_i[3:2]), .alert_tx_o(alert_tx[3:2]));
  pkg_struct_packed_array_partsel_port_conn_sink #(.N(4)) u_sink (.alert_tx_i(alert_tx), .flat_o);
endmodule
