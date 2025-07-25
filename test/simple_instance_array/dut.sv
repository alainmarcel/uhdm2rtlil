// Test case for instance arrays of primitive gates
module simple_instance_array (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [3:0] and_out,
    output wire [3:0] or_out,
    output wire [3:0] xor_out
);

// Instance array of AND gates
and and_gates[3:0] (and_out, a, b);

// Instance array of OR gates  
or or_gates[3:0] (or_out, a, b);

// Instance array of XOR gates
xor xor_gates[3:0] (xor_out, a, b);

// Also test with explicit indices
wire [3:0] nand_out;
nand nand_gates[0:3] (nand_out, a, b);

// Test with single bit connections
wire [3:0] not_out;
not not_gates[3:0] (not_out, a);

endmodule