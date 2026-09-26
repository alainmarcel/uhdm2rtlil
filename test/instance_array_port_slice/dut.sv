// An INSTANCE ARRAY whose vector actuals are split one bit per member:
//   mux2 #(1) LRUMuxes[NUMWAYS-3:0](CurrLRU[NUMWAYS-3:0], ~WayExpanded[NUMWAYS-3:0],
//                                   LRUUpdate[NUMWAYS-3:0], NextLRU[NUMWAYS-3:0]);
// (cvw cacheLRU).  Surelog elaborates the array into LRUMuxes[0], LRUMuxes[1]
// and hands EVERY member the full 2-bit actual; the importer connected it
// whole to each 1-bit port, so both members drove NextLRU[1:0] and flatten
// reported the second member's mux driving the first's ("Y port signal
// already driven").  LRM 28.3.5: an actual as wide as port width x member
// count is sliced, member k taking slice k (lowest index at the LSBs).
module mux2 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y
);
  assign y = s ? d1 : d0;
endmodule

module instance_array_port_slice #(
  parameter NUMWAYS = 4
) (
  input  logic [NUMWAYS-2:0] CurrLRU,
  input  logic [NUMWAYS-2:0] WayExpanded,
  input  logic [NUMWAYS-2:0] LRUUpdate,
  output logic [NUMWAYS-2:0] NextLRU
);
  assign NextLRU[NUMWAYS-2] = ~WayExpanded[NUMWAYS-2];
  if (NUMWAYS > 2)
    mux2 #(1) LRUMuxes[NUMWAYS-3:0](CurrLRU[NUMWAYS-3:0], ~WayExpanded[NUMWAYS-3:0],
                                    LRUUpdate[NUMWAYS-3:0], NextLRU[NUMWAYS-3:0]);
endmodule
