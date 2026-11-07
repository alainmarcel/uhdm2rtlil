// YosysHQ/yosys#5366 (closed): Interface and modport support bug ?
// https://github.com/YosysHQ/yosys/issues/5366
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

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

module simple_interface_mod(
    input logic [1:0] inputs,
    output logic [1:0] outputs
);
    simple_if intf0();
    simple_if intf1();

    driver_mod d0(intf0, inputs[0]);
    driver_mod d1(intf1, inputs[1]);

    receiver_mod r0(intf0, outputs[0]);
    receiver_mod r1(intf1, outputs[1]);
endmodule

