// povik/sv-elab#240 (closed): Segmentation fault while generating the netlist for SoomRV SoC as the top module
// https://github.com/povik/sv-elab/issues/240
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input logic clk, input logic [2:0] addr, input logic [7:0] data);

generate
for (genvar i = 0; i < 1; i=i+1) begin : gen
    (* ram_block *)
    logic [7:0] mem[7:0];
end
endgenerate

always_ff @(posedge clk)
    gen[0].mem[addr] <= data;

endmodule

