// RSD StoreQueue shape: a struct-field write at a DYNAMIC element index
// (the index itself an unpacked-array element under the loop variable)
// inside an always_ff for loop.
typedef struct packed {
    logic        regValid;
    logic        finished;
    logic [7:0]  address;
    logic [1:0]  wordWE;
} entry_t;
module sync_loop_dyn_elem_field_write (
    input  logic clk, rst,
    input  logic       we   [2],
    input  logic [2:0] ptr  [2],
    input  logic [7:0] addr [2],
    input  logic       fin  [2],
    input  logic [2:0] rptr,
    output logic [7:0] out_addr,
    output logic       out_fin
);
    entry_t q[7:0];
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 8; i++) begin
                q[i].finished <= 1'b0;
                q[i].address  <= '0;
                q[i].wordWE   <= '0;
            end
        end else begin
            for (int i = 0; i < 2; i++) begin
                if (we[i]) begin
                    q[ptr[i]].regValid <= 1'b1;
                    q[ptr[i]].finished <= fin[i];
                    q[ptr[i]].address  <= addr[i];
                    q[ptr[i]].wordWE   <= addr[i][1:0];
                end
            end
        end
    end
    always_comb begin
        out_addr = q[rptr].address;
        out_fin  = q[rptr].finished;
    end
endmodule
