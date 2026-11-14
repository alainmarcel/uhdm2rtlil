// MikePopoloski/slang#1510 (closed): Possibly incomplete driver information
// https://github.com/MikePopoloski/slang/issues/1510
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface I;
    logic l;
    modport mst ( output l );
    modport slv ( input l );
endinterface

module m(I.slv i);
    logic x;
    assign x = i.l;
endmodule

module n(I.mst i);
    assign i.l = 1 ;
endmodule 

module top (__o_i_l);
    I i();
    m u_m(i);
    n u_n(i);

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_i_l;
  assign __o_i_l = i.l;
endmodule

