// Two writes to ONE memory from TWO processes of the same module: an
// `initial` for-loop that clears it, and an always block with a direct
// constant-index write plus a loop-unrolled shift (`data_reg[i+1] <=
// data_reg[i]`).  This is verilog-ethernet's axis_srl_register, which aborted
// read_uhdm with
//   ERROR: Assert `count_id(wire->name) == 0' failed in kernel/rtlil.cc:2872
// because the `$memwr$<mem>$<i>` aux wires were named by the write's index
// WITHIN one emit_pending_memory_writes call, and `i` restarts at 0 on every
// call -- the always block's first write asked yosys for the wire the initial
// block's first write had already created.
module memwr_two_writes_one_block #(parameter WIDTH = 8) (
    input  logic             clk,
    input  logic [WIDTH-1:0] s_data,
    input  logic             s_valid,
    input  logic             m_ready,
    output logic [WIDTH-1:0] m_data,
    output logic             m_valid,
    output logic             s_ready
);
    reg [WIDTH-1:0] data_reg [1:0];
    reg             valid_reg [1:0];
    reg             ptr_reg  = 0;
    reg             full_reg = 0;
    integer i;

    assign m_data  = data_reg[ptr_reg];
    assign m_valid = valid_reg[ptr_reg];
    assign s_ready = !full_reg;

    initial begin
        for (i = 0; i < 2; i = i + 1) begin
            data_reg[i]  <= 0;
            valid_reg[i] <= 0;
        end
    end

    always @(posedge clk) begin
        full_reg <= !m_ready && m_valid;
        if (s_ready) begin
            data_reg[0]  <= s_data;
            valid_reg[0] <= s_valid;
            for (i = 0; i < 1; i = i + 1) begin
                data_reg[i+1]  <= data_reg[i];
                valid_reg[i+1] <= valid_reg[i];
            end
            ptr_reg <= valid_reg[0];
        end
    end
endmodule
