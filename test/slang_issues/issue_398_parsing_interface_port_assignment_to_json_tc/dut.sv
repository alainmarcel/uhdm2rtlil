// MikePopoloski/slang#398 (closed): Parsing interface port assignment to JSON fails
// https://github.com/MikePopoloski/slang/issues/398
// Code block(s) from the issue (variant tc); harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface my_ifc;

wire [7:0] data;

modport master 
(
    output data
);
endinterface

module test_marcos     
    (
        input  var  logic                  clk,        
        my_ifc                             my_if,
        my_ifc.master                      my_if_mod,                   
        output reg                         data_out_2
    );
    
    always_comb begin
        my_if_mod.data = 7'd0;
    end        
    

endmodule

