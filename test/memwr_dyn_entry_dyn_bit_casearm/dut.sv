// The same dynamic bit of a dynamically indexed memory entry, written from a
// CASE arm (`case (op) 2'd1: mem[idx][4+off] <= 1'b0;`) -- the shape of OpenPiton
// l15_hmc's flush arm.  The case-arm memory write handler had no dynamic-bit
// arm either: the bit index was computed and consumed by nothing, and the
// write fell out to the generic path.
module dut (input wire clk, input wire rst_n, input wire [1:0] op, input wire [1:0] idx, input wire [1:0] off,
            input wire [7:0] wdata, input wire [1:0] ridx, output wire [7:0] rdata);
    reg [7:0] mem [3:0];
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) mem[i] <= 8'h00;
        end else begin
            case (op)
            2'd1: mem[idx][4+off] <= 1'b0;
            2'd2: mem[idx] <= wdata;
            default: ;
            endcase
        end
    end
    assign rdata = mem[ridx];
endmodule
