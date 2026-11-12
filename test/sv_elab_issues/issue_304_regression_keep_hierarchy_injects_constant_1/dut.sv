// povik/sv-elab#304 (closed): Regression: `--keep-hierarchy` injects constant `1'x` driver on interface-array modport bits (first bad: 712830fe)
// https://github.com/povik/sv-elab/issues/304
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
interface bus_if ();
    logic        valid;
    logic [7:0]  data;
    logic        ready;
    modport master (output valid, output data, input  ready);
    modport slave  (input  valid, input  data, output ready);
endinterface

// Leaf: drives the master-modport output bits on a single interface instance.
module leaf (
    input  wire       clk,
    input  wire       fire,
    input  wire [7:0] din,
    bus_if.master     out_if
);
    reg       v_q;
    reg [7:0] d_q;
    always @(posedge clk) begin
        if (fire) begin v_q <= 1'b1; d_q <= din; end
        else if (out_if.ready) v_q <= 1'b0;
    end
    assign out_if.valid = v_q;
    assign out_if.data  = d_q;
endmodule

// Parent: master-modport interface-array port `arr[N]`; drives each arr[i]
// ONLY through a child cell via a single-element array-slice connection.
// The parent itself has no direct assign to arr[i].valid / arr[i].data.
module producer #(parameter N = 2) (
    input  wire            clk,
    input  wire [N-1:0]    fires,
    input  wire [N*8-1:0]  dins,
    bus_if.master          arr[N]
);
    for (genvar i = 0; i < N; ++i) begin : g
        leaf u_leaf (
            .clk    (clk),
            .fire   (fires[i]),
            .din    (dins[8*i +: 8]),
            .out_if (arr[i])
        );
    end
endmodule

module top (
    input  wire          clk,
    input  wire [1:0]    fires,
    input  wire [15:0]   dins,
    input  wire [1:0]    readies,
    output wire [1:0]    valids,
    output wire [15:0]   datas
);
    bus_if ifs[2]();

    for (genvar i = 0; i < 2; ++i) begin : g_ext
        assign valids[i]       = ifs[i].valid;
        assign datas[8*i +: 8] = ifs[i].data;
        assign ifs[i].ready    = readies[i];
    end

    producer #(.N(2)) u_prod (
        .clk   (clk), .fires (fires), .dins  (dins), .arr   (ifs)
    );
endmodule

