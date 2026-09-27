// A CDC synchroniser shift over an UNPACKED array of vectors, written the way
// jeras/tcb's tcb_dev_gpio_cdc writes it: the whole array reset by pattern,
// element 0 loaded, and the remaining elements shifted with an ARRAY SLICE
// non-blocking assignment `t[CDC-1:1] <= t[CDC-2:0]`.
//
// Because the process both resets the WHOLE array and writes elements, the
// reader materialises one flat wire with per-element alias wires.  The slice
// bounds are element indices: element k occupies bits [k*DAT +: DAT] of the
// flat wire.  Before the fix the slice was treated as a BIT range of the flat
// wire ([2:1] <= [1:0] on a 24-bit wire) and the element-0 write drove the
// alias wire directly against the flip-flop's whole-array update -- DAT driver
// conflicts on every rp32 SoC's GPIO block, and a synchroniser that never
// shifted.
module unpacked_array_slice_shift_ff #(
    parameter int unsigned DAT = 8,
    parameter int unsigned CDC = 3
)(
    input  logic           clk,
    input  logic           rst,
    input  logic [DAT-1:0] gpio_i,
    input  logic [DAT-1:0] gpio_e,
    output logic [DAT-1:0] gpio_r,
    output logic [DAT-1:0] stage1
);
    logic [DAT-1:0] gpio_t [CDC-1:0];
    always_ff @(posedge clk, posedge rst)
    if (rst) begin
        gpio_t <= '{default: '0};
    end else begin
        gpio_t[      0] <= gpio_i & gpio_e;
        gpio_t[CDC-1:1] <= gpio_t[CDC-2:0];
    end
    assign gpio_r = gpio_t[CDC-1];
    assign stage1 = gpio_t[1];
endmodule
