// YosysHQ/yosys#2677: SV arrays of structs
// https://github.com/YosysHQ/yosys/issues/2677
// A packed array of packed structs inside a struct, selected by a runtime index and read whole.

typedef struct packed { logic unsigned [4:0] p_value; } ch_struct_t;
typedef struct packed { ch_struct_t [7:0] channels; } ch_set_t;
module dut(input ch_set_t s, input logic [2:0] i, output logic [4:0] y, output logic [39:0] all);
  assign y = s.channels[i].p_value;
  assign all = s;
endmodule
