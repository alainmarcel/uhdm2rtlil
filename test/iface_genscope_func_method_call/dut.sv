// A function declared in an interface's GENERATE SCOPE, called through one of
// its methods (`return g.__onehot(bits)`): tnoc's tbcm_onehot.  Surelog elaborates
// only the taken `begin : g` arm, which holds the function; Function() on the
// call is null.  The method is reached both from an inlined module function
// (comb inlining, where the nested call's argument is the ENCLOSING method's
// formal) and from a continuous assign.
interface oh #(parameter int WIDTH = 2);
  if (WIDTH > 2) begin : g
    function automatic logic [WIDTH-1:0] __onehot(logic [WIDTH-1:0] bits);
      return bits & ~(bits - 1);
    endfunction
  end
  else if (WIDTH == 2) begin : g
    function automatic logic [WIDTH-1:0] __onehot(logic [WIDTH-1:0] bits);
      if (bits == 2'b10) return bits; else return {1'b0, bits[0]};
    endfunction
  end
  else begin : g
    function automatic logic [WIDTH-1:0] __onehot(logic [WIDTH-1:0] bits);
      return bits;
    endfunction
  end
  function automatic logic [WIDTH-1:0] to_onehot(logic [WIDTH-1:0] bits);
    return g.__onehot(bits);
  endfunction
endinterface

module top (input logic [1:0] req, input logic [2:0] req3, output logic [1:0] gnt, output logic [2:0] gnt3);
  oh #(.WIDTH(2)) u2();
  oh #(.WIDTH(3)) u3();
  function automatic logic [1:0] pick(logic [1:0] r);
    return u2.to_onehot(r);
  endfunction
  assign gnt  = pick(req);
  assign gnt3 = u3.to_onehot(req3);
endmodule
