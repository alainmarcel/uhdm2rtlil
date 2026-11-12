// povik/sv-elab#112 (open): Functions internal variables are flagged as asynchronous value missing in always_ff
// https://github.com/povik/sv-elab/issues/112
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv

module mwe (
	
    input logic  i_clk,
    input logic  i_rst_n,    
    input  logic [7:0] in,
    output logic [8:0] o1
);

function logic [8:0] my_sum(logic [7:0] a, logic [7:0] b);
    logic [8:0] out;
    out = a + b;
    return out;
endfunction;


    logic [7:0] test;
    assign test = 7'd5;

    always_ff @( posedge i_clk or negedge i_rst_n ) begin : p_seq
        if (~i_rst_n) begin
            o1 <= 0;
        end else begin
            o1 <= my_sum(test,3);            
        end
    end    

endmodule

