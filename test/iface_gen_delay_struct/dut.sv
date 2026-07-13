// Struct-array variant of the interface generate-scope delay line, mirroring
// the jeras/rp32 tcb_lite_if handshake/request delay line where the delayed
// signal is a PACKED STRUCT unpacked array (`req_t req_dly [0:DLY]`).
//
// Surelog leaves such an interface array signal only in Array_nets() (no scalar
// Nets() entry), so the frontend must materialize the flattened
// `\<iface>.req_dly` wire (element_width * count) itself, then drive each
// element `req_dly[i]` (an element-width slice) from the gen-scope regs.

package pkg;
    typedef struct packed {
        logic [7:0] adr;
        logic       wen;
    } req_t;                       // 9-bit packed struct
endpackage

interface delay_if #(parameter int DLY = 2) (input logic clk, input logic rst);
    import pkg::*;
    req_t din;
    req_t dly [0:DLY];             // struct unpacked array [0:2] -> 3*9 bits

    assign dly[0] = din;

    generate
        for (genvar i = 1; i <= DLY; i++) begin : dstage
            req_t tmp;
            assign dly[i] = tmp;
            always_ff @(posedge clk or posedge rst)
                if (rst) tmp <= '0;
                else     tmp <= dly[i-1];
        end
    endgenerate
endinterface

module top (
    input  logic       clk,
    input  logic       rst,
    input  pkg::req_t  din,
    output logic [7:0] dout_adr,
    output logic       dout_wen
);
    delay_if #(.DLY(2)) intf (.clk(clk), .rst(rst));
    assign intf.din = din;
    // Read the 2-cycle-delayed element's fields (the SoC's `req_dly[DLY].field`
    // access pattern) so the delay line is observable at the top port.
    assign dout_adr = intf.dly[2].adr;
    assign dout_wen = intf.dly[2].wen;
endmodule
