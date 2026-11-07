// YosysHQ/yosys#2684: SV return statement and typename function return types
// https://github.com/YosysHQ/yosys/issues/2684
// A function whose return type and argument type are typedefs from two packages, returning through a 'return' statement.

package in_types_pkg; typedef struct packed { logic unsigned [1:0] m_v; } in_struct_t; endpackage
package out_types_pkg; typedef struct packed { logic unsigned [1:0] m_v; } out_struct_t; endpackage
module dut(input in_types_pkg::in_struct_t i, output out_types_pkg::out_struct_t o);
  function automatic out_types_pkg::out_struct_t conv(input in_types_pkg::in_struct_t x);
    out_types_pkg::out_struct_t r;
    r.m_v = x.m_v + 2'd1;
    return r;
  endfunction
  assign o = conv(i);
endmodule
