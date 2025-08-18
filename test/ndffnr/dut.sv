module ndffnr( input d, clk, pre, clr, output reg q );
`ifndef NO_INIT
    initial begin
      q = 0;
    end
`endif
    always @( negedge clk )
      if ( !clr )
        q <= 1'b0;
      else
        q <= d;
endmodule
