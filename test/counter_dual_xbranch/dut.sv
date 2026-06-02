// Reproducer combining picorv32.v's count_cycle (line 1427) and
// count_instr (lines 1456 + 1559) in ONE always block, preserving:
//   * count_cycle's reset-via-ternary at the top of the block
//   * the dead `else count_cycle <= 'bx; count_instr <= 'bx;` branch
//     (ENABLE_COUNTERS=1 makes it unreachable, but it appears in UHDM)
//   * the dead `if (!ENABLE_COUNTERS64) count[63:32] <= 0;` partial
//     writes (ENABLE_COUNTERS64=1 makes them unreachable)
//   * count_instr's reset in the `if (!resetn)` block and increment
//     deep inside `case (cpu_state)` → decoder_trigger
// This mirrors the residual 126 unproven count_cycle/count_instr equiv
// cells in the full picorv32 build.
module counter_dual_xbranch #(
    parameter [0:0] ENABLE_IRQ        = 0,
    parameter [0:0] ENABLE_COUNTERS   = 1,
    parameter [0:0] ENABLE_COUNTERS64 = 1
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        decoder_trigger,
    input  wire        irq_active,
    input  wire        irq_delay,
    input  wire        irq_state_bit,
    input  wire [31:0] irq_pending,
    input  wire [31:0] irq_mask,
    input  wire [7:0]  cpu_state,
    output reg  [63:0] count_cycle,
    output reg  [63:0] count_instr
);
    localparam [7:0] cpu_state_fetch = 8'b01000000;

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
        end else begin
            (* parallel_case, full_case *)
            case (cpu_state)
                cpu_state_fetch: begin
                    if (ENABLE_IRQ && ((decoder_trigger && !irq_active && !irq_delay && |(irq_pending & ~irq_mask)) || irq_state_bit)) begin
                        // dead with ENABLE_IRQ=0
                    end else
                    if (decoder_trigger) begin
                        if (ENABLE_COUNTERS) begin
                            count_instr <= count_instr + 1;
                            if (!ENABLE_COUNTERS64) count_instr[63:32] <= 0;
                        end
                    end
                end
            endcase
        end
    end
endmodule
