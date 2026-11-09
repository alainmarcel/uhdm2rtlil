// YosysHQ/yosys#5366 (closed): Interface and modport support bug ?
// https://github.com/YosysHQ/yosys/issues/5366
// Code block(s) from the issue (variant h1); harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): inputs / outputs are ports of simple_interface_test (inputs was the constant 2'b10 and the module had no ports); the interface + modport connections are unchanged

// ---- b0.sv
interface simple_if;
    logic data;
    modport driver(output data);
    modport receiver(input data);
endinterface

module driver_mod(simple_if.driver intf, input logic in);
    assign intf.data = in;
endmodule

module receiver_mod(simple_if.receiver intf, output logic out);
    assign out = intf.data;
endmodule

module simple_interface_test(input logic [1:0] inputs, output logic [1:0] outputs);
    

        

    simple_if intf0();
    simple_if intf1();

    driver_mod d0(intf0, inputs[0]);
    driver_mod d1(intf1, inputs[1]);

    receiver_mod r0(intf0, outputs[0]);
    receiver_mod r1(intf1, outputs[1]);


    always_comb assert(outputs[0] == 1'b0); // inputs[0] = 0, so outputs[0] should be 0
    always_comb assert(outputs[1] == 1'b1); // inputs[1] = 1, so outputs[1] should be 1
    always_comb assert(outputs == 2'b10);   // Overall: outputs should equal inputs (2'b10)
endmodule

