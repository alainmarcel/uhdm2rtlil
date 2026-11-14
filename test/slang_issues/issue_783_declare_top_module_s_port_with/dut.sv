// MikePopoloski/slang#783 (closed): declare top module's port with interface
// https://github.com/MikePopoloski/slang/issues/783
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface itf;
    logic a;
    logic b;
    modport mp(input a,output b);
endinterface

module tc(itf.mp x);
assign x.b=x.a;
endmodule

