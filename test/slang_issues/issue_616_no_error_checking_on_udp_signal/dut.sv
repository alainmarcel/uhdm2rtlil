// MikePopoloski/slang#616 (closed): No error checking on UDP signal types
// https://github.com/MikePopoloski/slang/issues/616
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
primitive p (out2, in2);
    output out2;
    input in2;

    table
       //   in2     out2
            1   :   0;
            0   :   1;
            x   :   x;
            z   :   x;
            j   :   k;
    endtable
endprimitive

module top;
  wire o;
  p p_inst(o, 1'b0);
endmodule

