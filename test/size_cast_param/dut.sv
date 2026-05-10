// Reproduction of a synlig bug on parameterized size-cast in arithmetic
// expressions — `WIDTH'(ena)` (1-bit -> 16-bit) and `WIDTH'(1)` (32-bit
// int -> 16-bit) were not extending/truncating to the LHS width on the
// UHDM frontend, producing the wrong-width adder.
//
// Adapted from
// https://github.com/jeras/synthesis-primitives/tree/main/bugreport/yosys/techmap_ha
// counter_wrap.sv (kept the WIDTH'(ena) and WIDTH'(1) idioms; added a
// synthesizable top wrapper).

module counter_wrap #(
    // size parameters
    parameter  int unsigned WIDTH = 16,
    // implementation
    parameter  int unsigned IMPLEMENTATION = 0
    // 0 - carry in
    // 1 - multiplexer
)(
    // system signals
    input  logic             clk,
    input  logic             rst,
    // counter
    input  logic             ena,
    output logic [WIDTH-1:0] cnt
);

    generate
    case (IMPLEMENTATION)
        0:  // carry in
        begin
            always_ff @(posedge clk, posedge rst)
            if (rst)  cnt <= '0;
            else      cnt <= cnt + WIDTH'(ena);
        end
        1:  // multiplexer
        begin
            always_ff @(posedge clk, posedge rst)
            if (rst)       cnt <= '0;
            else if (ena)  cnt <= cnt + WIDTH'(1);
        end
    endcase
    endgenerate

endmodule: counter_wrap

module top (
    input  logic        clk,
    input  logic        rst,
    input  logic        ena,
    output logic [15:0] cnt0,
    output logic [15:0] cnt1
);
    counter_wrap #(.WIDTH(16), .IMPLEMENTATION(0))
        u0 (.clk(clk), .rst(rst), .ena(ena), .cnt(cnt0));
    counter_wrap #(.WIDTH(16), .IMPLEMENTATION(1))
        u1 (.clk(clk), .rst(rst), .ena(ena), .cnt(cnt1));
endmodule
