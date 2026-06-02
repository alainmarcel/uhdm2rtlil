// Reproducer extracted from picorv32.v lines 1533-1561 — the dead-branch
// if-else chain that wraps the count_instr increment:
//
//   if (ENABLE_IRQ && (... complex stuff ...)) begin
//     ... // dead with ENABLE_IRQ=0
//   end else
//   if (decoder_trigger) begin
//     ...
//     if (ENABLE_COUNTERS) begin
//       count_instr <= count_instr + 1;
//     end
//   end
//
// With ENABLE_IRQ=0 the first branch is dead code, but the UHDM
// frontend's if-else chain lowering retains the (now-constant) branch
// condition in the mux fabric.  Verilog frontend produces
// `EN = decoder_trigger AND NOT skip_condition`; UHDM frontend
// produces `EN = condition AND (decoder_trigger OR _04442_)` where
// `_04442_` is rooted in the dead branch.  Equiv proves 8800/8926
// cells but leaves count_cycle/count_instr's 126 bits unproven.
module counter_ifelse_chain #(
    parameter [0:0] ENABLE_IRQ      = 0,
    parameter [0:0] ENABLE_COUNTERS = 1
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        decoder_trigger,
    input  wire        irq_active,
    input  wire        irq_delay,
    input  wire        irq_state,
    input  wire [31:0] irq_pending,
    input  wire [31:0] irq_mask,
    output reg  [63:0] count_instr
);
    always @(posedge clk) begin
        if (!resetn) begin
            if (ENABLE_COUNTERS)
                count_instr <= 0;
        end else
        if (ENABLE_IRQ && ((decoder_trigger && !irq_active && !irq_delay && |(irq_pending & ~irq_mask)) || irq_state)) begin
            count_instr <= count_instr;
        end else
        if (decoder_trigger) begin
            if (ENABLE_COUNTERS) begin
                count_instr <= count_instr + 1;
            end
        end
    end
endmodule
