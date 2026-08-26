// Byte-enable register bank with an asynchronous reset that clears the whole
// unpacked memory array (hpdcache_regbank_wbyteenable_1rw pattern).
//
// An RTLIL $memwr port is clocked, so the reset fill cannot be a memory write
// at all — the array must be demoted to registers, exactly as read_verilog
// ("Replacing memory \mem with list of registers") and read_slang do.  Before
// that demotion the fill was dropped (its port emitted with EN tied to 0) and
// the memory never cleared.
//
// NOTE the suite's equivalence check cannot see this class of bug: equiv_make
// will not pair a $mem against a list of registers, so the induction is vacuous
// over the memory and the test passes either way.  Adjudicate with an explicit
// reset-toggling miter:
//     read_uhdm ...; flatten; proc; memory; opt -fast; async2sync
//     (same for read_slang / read_verilog); miter -equiv -make_assert
//     sat -prove-asserts -seq 4 -set-init-zero
module dut #(
    parameter int unsigned DATA_SIZE = 16,
    parameter int unsigned ADDR_SIZE = 1,
    parameter int unsigned DEPTH     = 2
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     cs,
    input  logic                     we,
    input  logic [ADDR_SIZE-1:0]     addr,
    input  logic [DATA_SIZE/8-1:0]   wbyteenable,
    input  logic [DATA_SIZE-1:0]     wdata,
    output logic [DATA_SIZE-1:0]     rdata
);
    typedef logic [DATA_SIZE-1:0] mem_t [DEPTH];
    mem_t mem;

    always_ff @(posedge clk or negedge rst_n) begin : mem_update_ff
        if (!rst_n) begin
            for (int unsigned i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
        end else begin
            if (cs) begin
                if (we) begin
                    for (int unsigned i = 0; i < DATA_SIZE/8; i++) begin
                        if (wbyteenable[i]) mem[addr][i*8 +: 8] <= wdata[i*8 +: 8];
                    end
                end
                rdata <= mem[addr];
            end
        end
    end
endmodule
