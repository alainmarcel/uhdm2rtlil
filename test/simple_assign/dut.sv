module simple_assign (
    input wire a,
    input wire b, 
    input wire c,
    input wire d,
    input wire e,
    output wire out_and,
    output wire out_or,
    output wire out_not,
    output wire out_complex
);

    // Continuous assignments with various logic operations
    assign out_and = a & b & c;           // 3-input AND
    assign out_or = a | b | c | d;        // 4-input OR  
    assign out_not = ~(a & b);            // NOT of 2-input AND
    assign out_complex = (a & b) | (c & d & e);  // Complex: (a AND b) OR (c AND d AND e)

endmodule