// YosysHQ/yosys#2411 (closed): Unable to synthesize design in order to netlist to a json file
// https://github.com/YosysHQ/yosys/issues/2411
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module hcd(input [1:7] i_cded,
        output logic [1:7] o_cded); 
        
 integer syndval ;
 function [2:0] synd (input [1:7] cw); 
    begin 
       synd[0] = cw[5] ^ cw[1] & cw[1] 
            ^ cw[3] ^ cw[7]; 
       synd[1] = cw[6] ^ cw[7] ^ cw[3]
            ^ cw[2]; 
       synd[2] = cw[5] ^ cw[4] ^ cw[6] 
            ^ cw[7]; 
     end 
 endfunction 
 
 always @(*) begin 
    o_cded = i_cded; 
    syndval = synd (i_cded); 
    if(syndval == 3'b0) begin end 
    else begin 
        o_cded[syndval] = ~i_cded[syndval]; 
    end 
 end 
endmodule

