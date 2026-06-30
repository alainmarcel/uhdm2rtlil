// gpio_t layer: an UNPACKED ARRAY written in an always_ff with whole-array
// reset, element write, and array slice-shift — like tcb_dev_gpio_cdc's
// `logic [DAT-1:0] gpio_t [CDC-1:0]`.  Triggered "Signal gpio_t not found".
module dut #(parameter int W = 8, parameter int N = 2) (
    input  logic           clk,
    input  logic           rst,
    input  logic [W-1:0]   din,
    output logic [W-1:0]   dout
);
    logic [W-1:0] arr [N-1:0];           // unpacked array (CDC stages)
    always_ff @(posedge clk, posedge rst)
    if (rst) begin
        arr <= '{default: '0};           // whole-array reset
    end else begin
        arr[0]      <= din;              // element write
        arr[N-1:1]  <= arr[N-2:0];       // array slice-shift
    end
    assign dout = arr[N-1];
endmodule
