// YosysHQ/yosys#2114: systemverilog typedef enum in package can not be used in interface
// https://github.com/YosysHQ/yosys/issues/2114
// A package enum typedef as an interface signal, driven and read through two modports.  The issue names the interface port after the interface type (my_if.out my_if), which crashes Surelog (infinite recursion in compileDatastructureTypespec); the port is called p here.

package pkg; typedef enum bit [1:0] { CODE_NOOP = 2'd0, CODE_PASS = 2'd1, CODE_FAIL = 2'd2, CODE_DONE = 2'd3 } status_code; endpackage
module dut(input [1:0] sin, output [1:0] sout);
    my_if u_my_if();
    a u_a(.sin, .p(u_my_if));
    b u_b(.sout, .p(u_my_if));
endmodule
interface my_if(); pkg::status_code status; modport in (input status); modport out (output status); endinterface
module a(input [1:0] sin, my_if.out p); assign p.status = pkg::status_code'(sin); endmodule
module b(output [1:0] sout, my_if.in p); assign sout = p.status; endmodule
