// A memory write whose index is WIDER than the memory it addresses (a 9-bit
// address into 128 entries, cvw cacheLRU at its defaults): the LRM (7.4.6)
// ignores an out-of-range write and read_slang drops it, but the always_ff
// pending-write emitter truncated the address to the port width, so set 259
// landed in set 3.  The reset loop over every entry is what routes the write
// through that emitter rather than the case-arm one #1446 guarded.
module dut (
    input  logic       clk,
    input  logic       reset,
    input  logic       we,
    input  logic [8:0] waddr,
    input  logic [6:0] raddr,   // reads stay in range: an out-of-range READ is X by the LRM and a Verilator wrap (#1469)
    input  logic [2:0] wdata,
    output logic [2:0] rdata
);
    logic [2:0] mem [127:0];
    always_ff @(posedge clk)
        if (reset)
            for (int set = 0; set < 128; set++) mem[set] <= '0;
        else if (we) mem[waddr] <= wdata;
    assign rdata = mem[raddr];
endmodule
