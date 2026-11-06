// A loop-indexed write into an element of a per-element-wire array that also
// selects a slice of that element (`mem[k][l] = d[l]` under `for (k) for (l)`),
// in an always_latch -- the PULP latch_scm register files
// (register_file_1w_multi_port_read_be, register_file_1r_1w_all_test_wrap in
// pulpissimo and snitch).  The scan of assigned signals saw a var_select with a
// not-yet-unrolled first index and registered NOTHING, so no element got a
// `$0\` temp with a hold default: the unrolled byte writes landed on the element
// wires straight from the case tree and proc_dlatch inferred no latch at all.
// Every word then held its data only while its gated clock was high.
module dut (
    input  logic        clk_i,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic [1:0]  wa_i,
    input  logic [31:0] wd_i,
    input  logic [1:0]  ra_i,
    output logic [31:0] rd_o
);
    logic [3:0][7:0] mem [4];
    logic [3:0][3:0] clocks;
    int unsigned i, j, k, l;

    always_comb begin
        for (i = 0; i < 4; i++)
            for (j = 0; j < 4; j++)
                clocks[i][j] = clk_i & we_i & be_i[j] & (wa_i == i);
    end

    always_latch begin
        for (k = 0; k < 4; k++)
            for (l = 0; l < 4; l++)
                if (clocks[k][l] == 1'b1)
                    mem[k][l] = wd_i[8*l +: 8];
    end

    assign rd_o = mem[ra_i];
endmodule
