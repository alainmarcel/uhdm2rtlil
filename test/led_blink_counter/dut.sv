module top
(
  input CLK,
  output [5:0] LED
);

reg [23:0] wait_counter = 'd0;
reg [5:0] ledCounter = 0;

assign LED = ~ledCounter;

always @(posedge CLK) begin
  if (wait_counter < 13500000) begin
    wait_counter <= wait_counter + 'd1;
  end
  else begin
    wait_counter <= 'd0;
    ledCounter <= ledCounter + 'd1;
  end
end

endmodule
