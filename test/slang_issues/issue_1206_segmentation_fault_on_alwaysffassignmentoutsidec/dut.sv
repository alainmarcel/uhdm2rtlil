// MikePopoloski/slang#1206 (closed): Segmentation fault on AlwaysFFAssignmentOutsideConditional slang-tidy checker
// https://github.com/MikePopoloski/slang/issues/1206
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test(output reg out);
    always_ff @ (*) begin
        convert(out);
    end

    task convert;
        output out1;
    endtask
endmodule

