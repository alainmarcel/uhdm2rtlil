// Simple FSM for testing UHDM vs Verilog equivalence
module simple_fsm (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire done,
    output reg  busy,
    output reg  [1:0] state
);

// State encoding
localparam IDLE  = 2'b00;
localparam WORK  = 2'b01;
localparam WAIT  = 2'b10;
localparam DONE = 2'b11;

reg [1:0] next_state;

// State register
always_ff @(posedge clk or posedge reset) begin
    if (reset)
        state <= IDLE;
    else
        state <= next_state;
end

// Next state logic
always_comb begin
    case (state)
        IDLE: begin
            if (start)
                next_state = WORK;
            else
                next_state = IDLE;
        end
        WORK: begin
            next_state = WAIT;
        end
        WAIT: begin
            if (done)
                next_state = DONE;
            else
                next_state = WAIT;
        end
        DONE: begin
            next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

// Output logic
always_comb begin
    case (state)
        IDLE: busy = 1'b0;
        WORK: busy = 1'b1;
        WAIT: busy = 1'b1;
        DONE: busy = 1'b0;
        default: busy = 1'b0;
    endcase
end

endmodule