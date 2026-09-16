// Port actuals that are FUNCTION CALLS (OpenTitan ascon_core:
// `.key_i(swap_endianess_byte(key_in))`).  read_uhdm left those child input
// ports undriven.
package inst_port_func_call_actual_pkg;
  function automatic logic [31:0] swap_bytes(logic [31:0] v);
    return {v[7:0], v[15:8], v[23:16], v[31:24]};
  endfunction
  function automatic logic [15:0] widen(logic [7:0] v);
    return {8'hA5, v};
  endfunction
endpackage

module inst_port_func_call_actual_child (
  input  logic [31:0] a_i,
  input  logic [15:0] b_i,
  input  logic [31:0] c_i,
  output logic [31:0] y_o
);
  assign y_o = a_i ^ {16'h0, b_i} ^ c_i;
endmodule

module inst_port_func_call_actual
  import inst_port_func_call_actual_pkg::*;
(
  input  logic [31:0] data_i,
  input  logic [7:0]  small_i,
  output logic [31:0] y_o
);
  inst_port_func_call_actual_child u_child (
    .a_i(swap_bytes(data_i)),
    .b_i(widen(small_i)),
    .c_i(swap_bytes(data_i ^ 32'h1234_5678)),
    .y_o(y_o)
  );
endmodule
