// Two elements of a packed 2-D register (`logic [1:0][1:0] r_ds`) written in
// DIFFERENT case arms of one async-reset always_ff -- core-v-mcu udma_filter_reg_if
// (every per-channel register: TX_CH0_CFG writes r_filter_tx_datasize[0],
// TX_CH1_CFG writes [1]).  The first entry recorded its slice and the sync
// update covered only that one, so element 1 was written into the `$0` temp
// and never updated: formal `differs`, co-sim PASS at 6 active cycles.
module dut (
    input  logic        clk_i,
    input  logic        rstn_i,
    input  logic        valid_i,
    input  logic [4:0]  addr_i,
    input  logic [31:0] data_i,
    output logic [3:0]  ds_o,
    output logic [3:0]  mode_o
);
    logic [1:0][1:0] r_ds;
    logic [1:0][1:0] r_mode;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (~rstn_i) begin
            r_ds[0]   <= 0;
            r_mode[0] <= 0;
            r_ds[1]   <= 0;
            r_mode[1] <= 0;
        end else begin
            if (valid_i) begin
                case (addr_i)
                5'b00001: begin
                    r_ds[0]   <= data_i[1:0];
                    r_mode[0] <= data_i[9:8];
                end
                5'b00110: begin
                    r_ds[1]   <= data_i[1:0];
                    r_mode[1] <= data_i[9:8];
                end
                default: ;
                endcase
            end
        end
    end
    assign ds_o = r_ds;
    assign mode_o = r_mode;
endmodule
