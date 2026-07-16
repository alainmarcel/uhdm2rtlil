// An unpacked-array (memory) declaration initializer `= '{default: '0}` must
// initialize every word to 0 (rp32 r5p_gpr register file — else x0 reads X and
// the whole datapath goes X). Reading an un-written word must give 0, not X.
module array_default_init #(
    parameter int unsigned AW = 5,
    parameter int unsigned DW = 32
)(
    input  logic          clk,
    input  logic          we,
    input  logic [AW-1:0] wa, ra,
    input  logic [DW-1:0] wd,
    output logic [DW-1:0] rd
);
    logic [DW-1:0] mem [0:(1<<AW)-1] = '{default: '0};
    always_ff @(posedge clk) if (we) mem[wa] <= wd;
    assign rd = mem[ra];
endmodule
