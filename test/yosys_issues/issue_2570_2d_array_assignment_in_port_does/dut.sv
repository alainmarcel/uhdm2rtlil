// YosysHQ/yosys#2570 (closed): 2D Array assignment in port does not work
// https://github.com/YosysHQ/yosys/issues/2570
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module intermediate
(    
    output logic [3:0] out
);
    assign out = 4'hA;
endmodule

module broken
(
    output logic [3:0] out
); 
    // Works - out is assigned 4'hA
    //logic [3:0] vec [0:0];
    //assign vec[0] = 4'hA;
    //assign out = vec[0];

    // Works - out is assigned 4'hA
    //logic [3:0] vec;
    //intermediate inst (.out(vec[3:0]));
    //assign out = vec[3:0];

    // Doesn't work - out is assigned 4'hX
    logic [3:0] vec [0:0];
    intermediate inst (.out(vec[0]));
    assign out = vec[0];
endmodule

