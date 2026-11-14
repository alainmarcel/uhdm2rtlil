// MikePopoloski/slang#1169 (closed): Syntax error when Enum is declared on the portlist
// https://github.com/MikePopoloski/slang/issues/1169
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module mod(output  reg[3:0] out, input  logic[1:0] in, output  enum logic[3:0]{STATE_A=4'd1,STATE_B=4'd2,STATE_C=4'd4,STATE_D=4'd8} state);


    always @(*) begin
        case (in)
            2'b00: state = STATE_A;
            2'b01: state = STATE_B;
            2'b10: state = STATE_C;
            2'b11: state = STATE_D;
            default: state = STATE_A;
        endcase
    
        out = state;
    end
endmodule

