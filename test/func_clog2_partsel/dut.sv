// Repro of r5p_soc_memory's address slice: a module localparam initialized with
// $clog2 used as a PART-SELECT bound in an expression (not just a width).
module func_clog2_partsel #(
    parameter int unsigned SIZE = 4096
) (
    input  logic [31:0] in,
    output logic [11:0] a
);
    localparam int unsigned ADR = $clog2(SIZE);   // 12
    assign a = in[ADR-1:0];                        // in[11:0]
endmodule
