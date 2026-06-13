`timescale 1ns/1ps

module noc_tni_buffer #(
    parameter int DEPTH = 16,
    parameter int FLIT_WIDTH = 64,
    parameter int SRC_START = FLIT_WIDTH - 19,
    parameter int ID_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    
    input  logic                  rx_valid,
    input  logic [FLIT_WIDTH-1:0] rx_payload,
    output logic                  rx_ready,
    
    input  logic                  depack_read,
    output logic                  depack_valid,
    output logic [FLIT_WIDTH-1:0] depack_payload,
    
    output logic [ID_WIDTH-1:0]   credit_return_src,
    output logic                  credit_return
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    logic [FLIT_WIDTH-1:0] mem [DEPTH];
    logic [ADDR_WIDTH:0]   write_ptr;
    logic [ADDR_WIDTH:0]   read_ptr;
    
    logic full;
    logic empty;
    
    assign full  = (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH]) && 
                   (write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]);
    assign empty = (write_ptr == read_ptr);
    
    assign rx_ready = !full;
    assign depack_valid = !empty;
    assign depack_payload = mem[read_ptr[ADDR_WIDTH-1:0]];
    
    logic push;
    logic pop;
    assign push = rx_valid && rx_ready && rst_n;
    assign pop  = depack_read && depack_valid && rst_n;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            read_ptr  <= 0;
            credit_return <= 1'b0;
            credit_return_src <= '0;
        end else begin
            if (push) begin
                mem[write_ptr[ADDR_WIDTH-1:0]] <= rx_payload;
                write_ptr <= write_ptr + 1'b1;
            end
            if (pop) begin
                read_ptr <= read_ptr + 1'b1;
                credit_return <= 1'b1;
                credit_return_src <= depack_payload[SRC_START +: ID_WIDTH];
            end else begin
                credit_return <= 1'b0;
            end
        end
    end

endmodule
