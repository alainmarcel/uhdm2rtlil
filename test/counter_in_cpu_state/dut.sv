// Tighter picorv32-like reproducer: wraps the count_instr if-else chain
// inside an outer `case (cpu_state)` like picorv32.v lines 1397-1572.
module counter_in_cpu_state #(
    parameter [0:0] ENABLE_IRQ      = 0,
    parameter [0:0] ENABLE_COUNTERS = 1
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
    output reg  [63:0] count_instr
);
    localparam [7:0] cpu_state_trap   = 8'b10000000;
    localparam [7:0] cpu_state_fetch  = 8'b01000000;
    localparam [7:0] cpu_state_ld_rs1 = 8'b00100000;
    localparam [7:0] cpu_state_ld_rs2 = 8'b00010000;
    localparam [7:0] cpu_state_exec   = 8'b00001000;
    localparam [7:0] cpu_state_shift  = 8'b00000100;
    localparam [7:0] cpu_state_stmem  = 8'b00000010;
    localparam [7:0] cpu_state_ldmem  = 8'b00000001;

    always @(posedge clk) begin
        if (!resetn) begin
            if (ENABLE_COUNTERS)
                count_instr <= 0;
        end else begin
            (* parallel_case, full_case *)
            case (cpu_state)
                cpu_state_trap:   ;
                cpu_state_fetch: begin
                    if (ENABLE_IRQ && ((decoder_trigger && !irq_active && !irq_delay && |(irq_pending & ~irq_mask)) || irq_state_bit)) begin
                        // dead with ENABLE_IRQ=0
                    end else
                    if (decoder_trigger) begin
                        if (ENABLE_COUNTERS) begin
                            count_instr <= count_instr + 1;
                        end
                    end
                end
                cpu_state_ld_rs1: ;
                cpu_state_ld_rs2: ;
                cpu_state_exec:   ;
                cpu_state_shift:  ;
                cpu_state_stmem:  ;
                cpu_state_ldmem:  ;
            endcase
        end
    end
endmodule
