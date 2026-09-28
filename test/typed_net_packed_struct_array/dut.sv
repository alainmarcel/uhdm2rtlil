// A `wire`-keyworded net of a typedef'd packed struct with an extra packed
// dimension -- `wire req_t [2:0] arr_net` -- the shape of caliptra-ss
// lc_ctrl's three KMAC application-interface request slots
// (`wire app_req_t [2:0] app_req; assign app_req[1] = kmac_data_o;`).
//
// Surelog's ELABORATED net carries only the named element type (`req_t`);
// the [2:0] survives on the definition view alone, as a packed_array_typespec
// (the implicit-var form `req_t [2:0] arr_imp` is a packed_array_var and was
// already right).  read_uhdm measured the net 9 bits instead of 27 and
// treated `arr_net[1]` as a 1-BIT select, so `arr_net[1] = r` connected one
// bit and 71 of the 74 bits of lc_ctrl's app port were undriven.
package p;
  typedef struct packed { logic v; logic [7:0] d; } req_t;
endpackage
module dut import p::*; (
  input  logic [7:0]  a,
  output logic [26:0] y_net,
  output logic [26:0] y_imp
);
  req_t r;
  assign r = '{v: 1'b1, d: a};
  wire  req_t [2:0] arr_net;
  req_t [2:0] arr_imp;
  assign arr_net[0] = '0; assign arr_net[1] = r; assign arr_net[2] = '0;
  assign arr_imp[0] = '0; assign arr_imp[1] = r; assign arr_imp[2] = '0;
  assign y_net = arr_net;
  assign y_imp = arr_imp;
endmodule
