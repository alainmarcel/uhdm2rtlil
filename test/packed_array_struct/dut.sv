// Reproducer: a packed array of a `localparam type` struct (a TYPE PARAMETER,
// as CVA6 uses: cva6.sv:83 `localparam type fetch_entry_t = struct packed {…}`
// then cva6.sv:418 `fetch_entry_t [NrIssuePorts-1:0] fetch_entry_if_id;`).
// The packed array collapsed to a 1-bit wire, so a connected submodule port
// (id_stage.fetch_entry_i, 366 bits) was resized from 1 bit at flatten.
module packed_array_struct (
    input  logic clk,
    output logic [63:0] sum
);
    localparam type my_t = struct packed {
        logic [31:0] a;
        logic [15:0] b;
        logic [7:0]  c;
    };                            // 56-bit struct type-param

    my_t        scalar_sig;       // 56 bits
    my_t [2:0]  arr;              // 3*56 = 168 bits (collapses to 1 in CVA6)

    assign scalar_sig = '0;
    assign arr        = '0;
    assign sum = scalar_sig.a + arr[0].a + arr[2].b;
endmodule
