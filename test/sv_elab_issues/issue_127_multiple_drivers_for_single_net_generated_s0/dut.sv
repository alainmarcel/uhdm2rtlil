// povik/sv-elab#127 (open): Multiple drivers for single net generated when using functions
// https://github.com/povik/sv-elab/issues/127
// Code block(s) from the issue (variant s0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module error_1
(
    input clk,
    output logic x_out
);

function f1(input x1);
    return x1;
endfunction

// Using initalization of signal changes the error to different one
//logic x = 0;
logic x;

always_ff @(posedge clk) begin
    x = 0;
end

// Commenting out this process removes the error
always_comb
begin
    if (f1(x))
    begin
    end
end

always_ff @(posedge clk)
    x_out <= f1(x);

endmodule

