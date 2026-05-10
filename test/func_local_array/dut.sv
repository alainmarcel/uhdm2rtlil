module foo
(
  output wire [1:0] out
);

  function [1:0] func1(input [1:0] a);
    reg [3:0] state[4];
    integer i;
    begin
      for (i = 0; i < 4; i = i + 1) begin
        state[i] = 2'b0;
        state[i][i] = 1'b1;
      end

      func1 = state[0] ^ a;
    end
  endfunction

  assign out = func1(2'd3);

endmodule
