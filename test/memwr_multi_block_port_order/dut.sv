// Four SEPARATE always_ff blocks write one memory -- the shape a generate-for
// over the write ports produces (RSD RegisterMultiPortRAM / BlockMultiPortRAM /
// BlockTrueDualPortRAM).  Each block becomes its own RTLIL process with its own
// `sync posedge clk`, and `proc_memwr` numbers the resulting write ports by
// walking `module->processes` -- which yosys's `dict` iterates in REVERSE
// insertion order.  So the ports came out numbered backwards, and since the
// LAST write port is the one that takes a same-address collision (write_verilog
// emits one `always` block per port, in port order), block 0 won where the RTL
// simulator and read_slang let block 3 win.
module dut (
    input  logic       clk,
    input  logic       we0, we1, we2, we3,
    input  logic [2:0] wa0, wa1, wa2, wa3,
    input  logic [7:0] wv0, wv1, wv2, wv3,
    input  logic [2:0] ra,
    output logic [7:0] rv
);
    logic [7:0] array [8];

    always_ff @(posedge clk) if (we0) array[wa0] <= wv0;
    always_ff @(posedge clk) if (we1) array[wa1] <= wv1;
    always_ff @(posedge clk) if (we2) array[wa2] <= wv2;
    always_ff @(posedge clk) if (we3) array[wa3] <= wv3;

    assign rv = array[ra];
endmodule
