module mem2reg_test6 (din, dout);
        input   wire    [3:0] din;
        output  reg     [3:0] dout;

        reg [1:0] din_array  [1:0];
        reg [1:0] dout_array [1:0];

        always @* begin
		din_array[0] = din[0 +: 2];
		din_array[1] = din[2 +: 2];

		dout_array[0] = din_array[0];
		dout_array[1] = din_array[1];

		{dout_array[0][1], dout_array[0][0]} = dout_array[0][0] + dout_array[1][0];

		dout[0 +: 2] = dout_array[0];
		dout[2 +: 2] = dout_array[1];
        end
endmodule
