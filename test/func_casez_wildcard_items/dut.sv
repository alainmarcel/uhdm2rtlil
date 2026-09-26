// casez / casex items with wildcard bits inside a FUNCTION body.  The
// function-body case importer (SSA path) and the compile-time evaluator kept
// the literal z / x bits, so `keep2count`'s `8'bzzzzzzz0` items (verilog-
// ethernet udp_ip_tx_64) never matched: the function result was x, the
// early-termination error flag was undefined, and Verilator refused the
// netlist's tristate `==`.  Module-level casez was fixed earlier (#920);
// this covers the function paths: a runtime call in a comb block, a call on
// a constant (folded), and a casex twin.
module func_casez_wildcard_items (
  input  logic [7:0] tkeep,
  input  logic [4:0] want,
  output logic [3:0] cnt,
  output logic       early,
  output logic [3:0] cnt_const,
  output logic [1:0] cx
);
  function [3:0] keep2count;
    input [7:0] k;
    casez (k)
      8'bzzzzzzz0: keep2count = 4'd0;
      8'bzzzzzz01: keep2count = 4'd1;
      8'bzzzzz011: keep2count = 4'd2;
      8'bzzzz0111: keep2count = 4'd3;
      8'bzzz01111: keep2count = 4'd4;
      8'bzz011111: keep2count = 4'd5;
      8'bz0111111: keep2count = 4'd6;
      8'b01111111: keep2count = 4'd7;
      8'b11111111: keep2count = 4'd8;
    endcase
  endfunction
  function [1:0] top2;
    input [3:0] v;
    casex (v)
      4'b1xxx: top2 = 2'd3;
      4'b01xx: top2 = 2'd2;
      4'b001x: top2 = 2'd1;
      default: top2 = 2'd0;
    endcase
  endfunction
  always @* begin
    cnt   = keep2count(tkeep);
    early = 1'b0;
    if (keep2count(tkeep) < want) early = 1'b1;
    cx = top2(tkeep[3:0]);
  end
  assign cnt_const = keep2count(8'b00011111);
endmodule
