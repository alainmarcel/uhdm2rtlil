// Reproducer extracted from picorv32.v lines 1427-1433 (count_cycle/count_instr).
// The structure is:
//   always @(posedge clk) begin
//     if (ENABLE_COUNTERS) begin
//       count_cycle <= resetn ? count_cycle + 1 : 0;
//       if (!ENABLE_COUNTERS64) count_cycle[63:32] <= 0;
//     end else begin
//       count_cycle <= 'bx;     // unreachable when ENABLE_COUNTERS=1
//       count_instr <= 'bx;
//     end
//   end
// With ENABLE_COUNTERS=1 the else branch is dead but the
// `<= 'bx` assignment shows up in the elaborated UHDM tree and
// the UHDM frontend produces a `$sdff` whose `equiv_induct` cannot
// match the Verilog frontend's `$sdff` — the 64-bit counter pair
// is the only thing left unproven (126/8929 cells) in picorv32.
module counter_xpath(
    input  wire        clk,
    input  wire        resetn,
    output reg  [63:0] count_cycle,
    output reg  [63:0] count_instr
);
    parameter [0:0] ENABLE_COUNTERS   = 1;
    parameter [0:0] ENABLE_COUNTERS64 = 1;

    always @(posedge clk) begin
        if (ENABLE_COUNTERS) begin
            count_cycle <= resetn ? count_cycle + 1 : 0;
            if (!ENABLE_COUNTERS64) count_cycle[63:32] <= 0;
        end else begin
            count_cycle <= 'bx;
            count_instr <= 'bx;
        end

        if (!resetn) begin
            if (ENABLE_COUNTERS)
                count_instr <= 0;
        end else if (ENABLE_COUNTERS) begin
            count_instr <= count_instr + 1;
            if (!ENABLE_COUNTERS64) count_instr[63:32] <= 0;
        end
    end
endmodule
