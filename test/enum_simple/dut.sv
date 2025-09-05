module enum_simple (
    input wire clk,
    input wire reset,
    output reg [1:0] state_out
);
    // Simple enum definition
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        ACTIVE = 2'b01,
        WAIT = 2'b10,
        DONE = 2'b11
    } state_t;
    
    state_t current_state, next_state;
    
    // State register
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: next_state = ACTIVE;
            ACTIVE: next_state = WAIT;
            WAIT: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Output assignment
    assign state_out = current_state;
    
endmodule