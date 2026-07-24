module child (
    input  logic [95:0] data_i,
    output logic [63:0] o
);
    assign o = data_i[63:0] ^ data_i[95:64];
endmodule

module packed_array_elem_select (
    input  logic [95:0] a0,
    input  logic [95:0] a1,
    output logic [63:0] o
);
    typedef struct packed { logic [63:0] x; logic [31:0] y; } my_t;  // 96-bit
    my_t [1:0] arr;
    assign arr[0] = a0;
    assign arr[1] = a1;
    child c (.data_i(arr[0]), .o(o));
endmodule
