// A struct-typed parameter with a field WIDER than 32 bits whose value has bit
// 31 set: VeeR EH2's `eh2_param_t pt` carries eight 36-bit DATA_ACCESS_ADDRn /
// MASKn windows (ADDR2 = 36'h0A0000000), tested as
//     (addr | pt.MASKn) == (pt.ADDRn | pt.MASKn)
// The field was resolved through a 32-bit `int` and rebuilt at its declared
// width, so 36'h0A0000000 became 36'hFA0000000 and every window whose base
// address has bit 31 set failed the compare -- eh2_lsu_addrcheck flagged an
// access fault on every non-DCCM access (116 diverging co-simulated cycles).
// read_verilog cannot parse a struct parameter, so the read_slang miter is the
// formal gate; the structural check pins the folded constant itself.
typedef struct packed {
    bit [4:0]  EN;
    bit [35:0] ADDR;
    bit [35:0] MASK;
    bit [63:0] WIDE;
} win_t;
module dut #(
    parameter win_t W = '{EN: 5'h01, ADDR: 36'h0A0000000, MASK: 36'h01FFFFFFF,
                          WIDE: 64'hC000_0000_8000_0001}
) (
    input  logic [31:0] addr,
    output logic        in_window,
    output logic [35:0] base,
    output logic [63:0] wide,
    output logic        wide_hi
);
    assign in_window = W.EN[0] & (((addr | W.MASK)) == (W.ADDR | W.MASK));
    assign base      = W.ADDR | W.MASK;
    assign wide      = W.WIDE;
    assign wide_hi   = W.WIDE[63] & W.WIDE[62] & W.WIDE[31] & ~W.WIDE[32];
endmodule
