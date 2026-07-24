module child (input logic [95:0] data_i, output logic [63:0] o);
    assign o = data_i[63:0] ^ data_i[95:64];
endmodule
module packed_array_struct_port_sel #(parameter type T = logic) (
    input  T [1:0] arr_i,
    output logic [63:0] o
);
    child c (.data_i(arr_i[0]), .o(o));
endmodule
module tb;
    typedef struct packed { logic [63:0] x; logic [31:0] y; } my_t;  // 96-bit
    my_t [1:0] arr;
    logic [63:0] o;
    packed_array_struct_port_sel #(.T(my_t)) d (.arr_i(arr), .o(o));
endmodule
