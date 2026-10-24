// A flop with TWO asynchronous controls: `posedge clk or negedge rst_n or
// negedge set_n`.  Surelog nests the three-way `or` as `(a or b) or c`, an
// inner vpiEventOrOp under the outer one; a flat walk over the outer operands
// saw only the LAST edge, took the SET as the clock, found no reset and
// aborted the read ("Reset signal is empty in async reset handling") --
// aib-protocols levelsync_sr and the AIB 2.0 PHY's aibio_dll_top with its six
// parents up to aib_phy_top.  read_slang refuses this shape outright
// ("multiple asynchronous loads unsupported"), so read_verilog is the
// reference: proc lowers both frontends' processes to the same set/reset flops.
module dut #(
    parameter RESET_VALUE = 1'b0,
    parameter SET_VALUE   = 1'b1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic set_n,
    input  logic d,
    output logic q
);
    logic ff0, ff1;
    always_ff @(posedge clk or negedge rst_n or negedge set_n)
        if (!rst_n) begin
            ff0 <= RESET_VALUE;
            ff1 <= RESET_VALUE;
        end else if (!set_n) begin
            ff0 <= SET_VALUE;
            ff1 <= SET_VALUE;
        end else begin
            ff0 <= d;
            ff1 <= ff0;
        end
    assign q = ff1;
endmodule
