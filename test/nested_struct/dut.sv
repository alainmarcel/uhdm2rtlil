// First package with base struct
package base_pkg;
    typedef struct packed {
        logic [7:0] addr;
        logic [31:0] data;
        logic valid;
    } base_struct_t;
endpackage

// Second package that uses struct from first package
package main_pkg;
    import base_pkg::*;

    typedef struct packed {
        base_struct_t base;
        logic [15:0] id;
        logic [3:0] cmd;
        logic ready;
    } nested_struct_t;
endpackage

// Top module using nested struct as ports.
//
// Two output forms are exposed:
//   - `out_data` keeps the original packed-struct port (the actual
//     subject of the test — exercising nested-struct typedefs from
//     two packages on a module boundary).
//   - `out_*_o` are flat scalar outputs that forward the individual
//     fields of the produced struct.  The flat outputs let the
//     co-sim compare RTL vs netlist without depending on packed-
//     struct field-ordering matching the synth-side flat packing.
module nested_struct (
    input  main_pkg::nested_struct_t in_data,
    output main_pkg::nested_struct_t out_data,
    input  logic clk,
    input  logic rst,
    // Flat scalar mirror of `out_data` for co-sim comparison.
    output logic [7:0]  out_addr_o,
    output logic [31:0] out_dbits_o,
    output logic        out_valid_o,
    output logic [15:0] out_id_o,
    output logic [3:0]  out_cmd_o,
    output logic        out_ready_o
);
    import main_pkg::*;
    import base_pkg::*;

    // Internal signal
    nested_struct_t processed_data;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            out_data <= '0;
        end else begin
            out_data <= processed_data;
        end
    end

    // Combinational processing
    always_comb begin
        processed_data = in_data;

        // Modify nested struct fields
        processed_data.base.addr = in_data.base.addr + 8'd1;
        processed_data.base.data = in_data.base.data ^ 32'hDEADBEEF;
        processed_data.base.valid = in_data.base.valid & in_data.ready;

        // Modify top-level fields
        processed_data.id = in_data.id + 16'd100;
        processed_data.cmd = in_data.cmd | 4'b1010;
        processed_data.ready = in_data.base.valid;
    end

    // Mirror the output struct fields as flat scalars.
    assign out_addr_o  = out_data.base.addr;
    assign out_dbits_o = out_data.base.data;
    assign out_valid_o = out_data.base.valid;
    assign out_id_o    = out_data.id;
    assign out_cmd_o   = out_data.cmd;
    assign out_ready_o = out_data.ready;

endmodule
