// povik/sv-elab#204 (closed): Issues with handling of interfaces
// https://github.com/povik/sv-elab/issues/204
// Code block(s) from the issue (variant s0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
interface myBus;
    logic       ready;
    logic [3:0] data;

    modport sender(
        input ready,
        output data
    );

    modport receiver(
        input data,
        output ready
    );
endinterface

`define connect(lhs, rhs)\
    assign lhs.ready = rhs.ready;\
    assign rhs.data = lhs.data;\

module bus_receiver(
    myBus.receiver port,
    output logic is_zero
);
    assign port.ready = 1'b1;
    assign is_zero = (port.data == 4'd0);
endmodule

module bus_wrapper(
    myBus.receiver out_sig,
    myBus.sender in_sig
);
    myBus m0();

    `connect(out_sig, m0);
    `connect(m0, in_sig);
endmodule

module top(
    input logic clk,
    myBus.receiver out_sig,
    output logic is_zero
);
    
    myBus rport();
    bus_wrapper b0(out_sig, rport.sender);
    bus_receiver r0(rport.receiver, is_zero);
endmodule

