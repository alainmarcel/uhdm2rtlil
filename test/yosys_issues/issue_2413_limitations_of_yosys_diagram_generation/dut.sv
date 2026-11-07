// YosysHQ/yosys#2413 (closed): Limitations of Yosys Diagram Generation
// https://github.com/YosysHQ/yosys/issues/2413
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module mult #(parameter i_width=64, o_width=128)(input logic[i_width-1:0] multiplier, multiplicand, output logic [o_width-1:0] product ); 
 integer i; 
 always @(*) 
 begin 
 product = 1'b0; 
 for(i=0; i<i_width; i=i+1) begin 
 if(multiplicand [i] == 1'b1) 
 begin 
 product = product + (multiplier << (i)); 
 end 
 end 
 end 
 endmodule

