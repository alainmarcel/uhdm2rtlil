// Converted from chipsalliance/sv-tests (escaped-identifiers).
// Upstream declares six ESCAPED identifiers and never drives or reads any of them, so nothing confirms the escaping survived into a usable signal.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module identifiers(input logic [5:0] x, output logic [5:0] y);
  reg \busa+index ;
  reg \-clock ;
  reg \***error-condition*** ;
  reg \net1/\net2 ;
  reg \{a,b} ;
  reg \a*(b+c) ;
  // Every escaped name is driven and read back, so an escaping that collapsed two
  // names together, or lost one, shows up as a wrong bit.
  always_comb begin
    \busa+index            = x[0];
    \-clock                = x[1];
    \***error-condition*** = x[2];
    \net1/\net2            = x[3];
    \{a,b}                 = x[4];
    \a*(b+c)               = x[5];
  end
  assign y = {\a*(b+c) , \{a,b} , \net1/\net2 , \***error-condition*** ,
              \-clock , \busa+index };
endmodule
