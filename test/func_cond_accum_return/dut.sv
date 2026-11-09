// A function local that is RETURNED at the end and READ in an `if` condition
// that guards its own update -- a running maximum, NVDLA's NV_DW_minmax
// (every NV_NVDLA_CMAC exponent comparator):
//     if (a_v >= value_v) value_v = a_v;   ...   max_unsigned_value = value_v;
// Unpatched read_uhdm aliased value_v onto the call's result wire, so each
// comparison read the FINAL result: a combinational loop and an arbitrary
// element instead of the maximum.
module dut (
    input  logic [15:0] a,
    output logic [3:0]  v
);
    function [3:0] mx;
        input [15:0] a;
        reg [3:0] a_v;
        reg [3:0] value_v;
        reg [2:0] k;
        begin
            value_v = 4'b0;
            for (k = 0; k < 4; k = k + 1) begin
                a_v = a[3:0];
                a = a >> 4;
                if (a_v >= value_v) value_v = a_v;
            end
            mx = value_v;
        end
    endfunction
    always @(*) v = mx(a);
endmodule
