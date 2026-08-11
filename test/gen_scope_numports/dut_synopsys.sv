// Inner "simulation-only" model, like CVA6 tc_sram, with [NumPorts-1:0] ports.
module tc_sram #(
    parameter int unsigned NumPorts = 2,
    parameter int unsigned DataWidth = 128,
    parameter type data_t = logic [DataWidth-1:0]
) (
    input  logic  [NumPorts-1:0] req_i,
    input  logic  [NumPorts-1:0] we_i,
    input  data_t [NumPorts-1:0] wdata_i,
    output data_t [NumPorts-1:0] rdata_o
);
    assign rdata_o = wdata_i;
endmodule

module tc_sram_wrapper #(
    parameter int unsigned NumWords  = 1024,
    parameter int unsigned DataWidth = 128,
    parameter int unsigned NumPorts  = 2,
    parameter type         data_t    = logic [DataWidth-1:0]
) (
    input  logic  [NumPorts-1:0] req_i,
    input  logic  [NumPorts-1:0] we_i,
    input  data_t [NumPorts-1:0] wdata_i,
    output data_t [NumPorts-1:0] rdata_o
);
// synopsys translate_off
    tc_sram #(.NumPorts(NumPorts), .DataWidth(DataWidth)) i_tc_sram (
        .req_i(req_i), .we_i(we_i), .wdata_i(wdata_i), .rdata_o(rdata_o)
    );
// synopsys translate_on
endmodule

module gen_scope_numports #(parameter int DATA_WIDTH = 128) (
    input  logic req_i, we_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    output logic [DATA_WIDTH-1:0] rdata_o
);
    for (genvar k = 0; k < (DATA_WIDTH+63)/64; k++) begin : gen_cut
        tc_sram_wrapper #(.DataWidth(64), .NumPorts(1)) i_tc_sram_wrapper (
            .req_i(req_i), .we_i(we_i),
            .wdata_i(wdata_i[k*64 +: 64]), .rdata_o(rdata_o[k*64 +: 64])
        );
    end
endmodule

module tb;
    logic req_i, we_i;
    logic [127:0] wdata_i, rdata_o;
    gen_scope_numports #(.DATA_WIDTH(128)) t (.*);
endmodule
