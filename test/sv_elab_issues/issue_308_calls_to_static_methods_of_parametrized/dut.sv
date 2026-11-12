// povik/sv-elab#308 (closed): Calls to static methods of parametrized classes trigger assertion in RTLIL
// https://github.com/povik/sv-elab/issues/308
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// content of /tmp/slang-class-static-method-issue.sv
class rotate #(
    parameter int unsigned DATA_WIDTH = 8
);
    static function logic[DATA_WIDTH-1:0] calc (
        logic[DATA_WIDTH-1:0] data
    );
        calc = {data[DATA_WIDTH-2:0], data[DATA_WIDTH-1]};
    endfunction
endclass

module test(in1, in2, out1, out2);
    input logic[7:0] in1;
    input logic[15:0] in2;

    output logic[7:0] out1;
    output logic[15:0] out2;

    assign out1 = rotate #(8)::calc(in1);
    assign out2 = rotate #(16)::calc(in2);
endmodule

