// Very simple test without structs
module struct_array (
    input  logic [47:0] packets_in,
    output logic [47:0] packets_out
);
    // Simple assignment
    always_comb begin
        packets_out = packets_in;
    end
endmodule