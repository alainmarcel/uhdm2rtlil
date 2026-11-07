// YosysHQ/yosys#5688 (closed): gowin: $_GOWIN_DP brams_map uses PORT_B_WR_BE for ADA byte enables instead of PORT_A_WR_BE, silently disabling   writes
// https://github.com/YosysHQ/yosys/issues/5688
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// Minimal reproduction of $__GOWIN_DP_ byte-enable bug in yosys brams_map.v
//
// Bug: In gowin/brams_map.v line 208, the $__GOWIN_DP_ template computes:
//   wire [13:0] ADA = `addrbe(PORT_A_WIDTH, PORT_A_ADDR, PORT_B_WR_BE);
// This should be PORT_A_WR_BE. Because PORT_B_WR_BE is used, the byte
// enables for the write port (Port A) are taken from the read port (Port B),
// which are always 0. This silently disables all writes to the BSRAM.
//
// To reproduce:
//   yosys -p "read_verilog yosys_dp_byte_enable_bug.v; synth_gowin -top top; write_verilog post_synth.v"
//
// Then inspect post_synth.v: the DPX9B instance will have ADA[1:0] tied to
// constant 0 (byte enables disabled), meaning writes never take effect.
//
// Expected: ADA[1:0] should be driven by the write-enable condition so that
// byte lanes are enabled when a write occurs.

`default_nettype none

module top (
    input  wire        clk,
    input  wire [9:0]  rd_addr,
    output reg  [15:0] rd_data,
    input  wire [9:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire        wr_en
);

    (* ram_style = "block" *) reg [15:0] mem [0:1023];

    // Read port — separate always block
    always @(posedge clk) begin
        rd_data <= mem[rd_addr];
    end

    // Write port — separate always block
    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

endmodule

