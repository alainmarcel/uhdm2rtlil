// Power-up memory initializer written as `initial for (int k...) mem[k] = P;`
// where the RHS is a *parameter* (not a literal).  The inline `int k`
// declaration routes the initial block to the interpreter path, which used to
// drop the $meminit — leaving the RAM X at power-up while the Verilog frontend
// initialized it.  Mirrors Ibex ibex_register_file_fpga's mem[k]=WordZeroVal.
module mem_init_for_param #(
    parameter int              Depth   = 8,
    parameter logic [31:0]     InitVal = 32'hDEAD_BEEF
) (
    input  logic        clk,
    input  logic        we,
    input  logic [2:0]  waddr,
    input  logic [31:0] wdata,
    input  logic [2:0]  raddr,
    output logic [31:0] rdata
);
    logic [31:0] mem [Depth];

    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];

    initial begin
        for (int k = 0; k < Depth; k++) begin
            mem[k] = InitVal;
        end
    end
endmodule
