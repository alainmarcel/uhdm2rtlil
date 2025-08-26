module lut_map_cmp(
	input [3:0] a,
	output o1_1, o1_2, o1_3, o1_4, o1_5, o1_6,
	output o2_1, o2_2, o2_3, o2_4, o2_5, o2_6,
	output o3_1, o3_2, o3_3, o3_4, o3_5, o3_6,
	output o4_1, o4_2, o4_3, o4_4
);
	parameter LUT_WIDTH = 4; // Multiples of 2 only

	// First set: constant on left (unsigned)
	assign o1_1 = 4'b1010 <= a;
	assign o1_2 = 4'b1010 <  a;
	assign o1_3 = 4'b1010 >= a;
	assign o1_4 = 4'b1010 >  a;
	assign o1_5 = 4'b1010 == a;
	assign o1_6 = 4'b1010 != a;

	// Second set: constant on right (unsigned)
	assign o2_1 = a <= 4'b1010;
	assign o2_2 = a <  4'b1010;
	assign o2_3 = a >= 4'b1010;
	assign o2_4 = a >  4'b1010;
	assign o2_5 = a == 4'b1010;
	assign o2_6 = a != 4'b1010;

	// Third set: different constant comparisons (unsigned)
	assign o3_1 = 4'b0101 <= a;
	assign o3_2 = 4'b0101 <  a;
	assign o3_3 = 4'b0101 >= a;
	assign o3_4 = 4'b0101 >  a;
	assign o3_5 = 4'b0101 == a;
	assign o3_6 = 4'b0101 != a;

	// Fourth set: comparisons with zero (unsigned)
	assign o4_1 = a <= 4'b0000;
	assign o4_2 = a <  4'b0000;
	assign o4_3 = a >= 4'b0000;
	assign o4_4 = a >  4'b0000;
endmodule