// MikePopoloski/slang#662 (closed): Hexadecimal literals are treated as TokenKind::Identifier
// https://github.com/MikePopoloski/slang/issues/662
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module a (__i_ia, __i_ic, __o_ib);
    localparam b = 4'hd;
    localparam c = 12'hffa;
    localparam d = 32'hffaaffff;
    localparam e = 32'd123;

    logic ia;
    logic ib;
    logic ic;

    always_ff @(posedge ia) begin
        ib <= ic;
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_ia;
  assign ia = __i_ia;
  input logic __i_ic;
  assign ic = __i_ic;
  output logic __o_ib;
  assign __o_ib = ib;
endmodule

