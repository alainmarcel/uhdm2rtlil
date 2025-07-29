module unique_case ( input logic clock);
logic [2:0] state, random;
always_ff @(posedge clock) begin
for (int i=0;i<16;i++) begin // do it a bunch of times...
unique case (state)
0: if (random == 0) break;
1: if (random == 1) break;
endcase
end // for
end // always
endmodule
