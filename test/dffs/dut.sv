module dffs( input d, clk, pre, clr, output reg q );
`ifndef NO_INIT
    initial begin
      q = 0;
    end
`endif
    always @( posedge clk )
      if ( pre )
        q <= 1'b1;
      else
        q <= d;
endmodule
