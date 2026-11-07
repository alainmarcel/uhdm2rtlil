// YosysHQ/yosys#5946 (closed): opt_clean misidentifies live latch-feeding mux logic as dead, causes simulation mismatch
// https://github.com/YosysHQ/yosys/issues/5946
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv

module top(clkin_data, in_data, out_data);
  input [95:0] clkin_data;
  input [191:0] in_data;
  output [191:0] out_data;
  wire [95:0] clkin_data; wire [191:0] in_data; wire [191:0] out_data;
  wire celloutsig_0_11z, celloutsig_0_12z, celloutsig_0_13z, celloutsig_0_145z, celloutsig_0_14z, celloutsig_0_24z, celloutsig_0_27z, celloutsig_0_281z, celloutsig_0_28z, celloutsig_0_2z;
  wire celloutsig_0_31z, celloutsig_0_33z, celloutsig_0_38z, celloutsig_0_4z, celloutsig_0_59z, celloutsig_0_5z, celloutsig_0_6z, celloutsig_0_8z, celloutsig_1_19z, celloutsig_1_5z;
  wire [2:0] celloutsig_0_135z, celloutsig_0_280z; wire [3:0] celloutsig_0_19z, celloutsig_0_20z, celloutsig_0_7z; wire [4:0] celloutsig_0_0z, celloutsig_0_32z;
  wire [5:0] celloutsig_0_18z, celloutsig_0_30z, celloutsig_0_41z, celloutsig_0_50z, celloutsig_0_68z; wire [6:0] celloutsig_0_9z; wire [7:0] celloutsig_0_17z; wire [8:0] celloutsig_0_3z;
  wire [10:0] celloutsig_0_21z; wire [11:0] celloutsig_1_18z, celloutsig_1_1z; wire [12:0] celloutsig_1_0z; wire [14:0] celloutsig_0_1z;
  wire [17:0] celloutsig_0_37z; wire [21:0] celloutsig_0_10z; wire [22:0] celloutsig_0_15z; wire [23:0] celloutsig_0_16z; wire [29:0] celloutsig_1_2z;
  reg [7:0] celloutsig_0_48z; reg [2:0] celloutsig_1_7z;
  assign celloutsig_0_5z = celloutsig_0_0z[0] ^ celloutsig_0_2z;
  assign celloutsig_0_11z = celloutsig_0_7z[0] ^ celloutsig_0_10z[16];
  assign celloutsig_0_8z = ~(celloutsig_0_0z[2] ^ celloutsig_0_0z[4]);
  assign celloutsig_0_0z = in_data[65:61] / { 1'h1, in_data[13:10] };
  assign celloutsig_0_1z = in_data[30:16] / { 1'h1, celloutsig_0_0z[3:0], celloutsig_0_0z, celloutsig_0_0z };
  assign celloutsig_0_15z = { celloutsig_0_10z[17:0], celloutsig_0_5z, celloutsig_0_7z } / { 1'h1, celloutsig_0_0z[3:1], celloutsig_0_14z, celloutsig_0_1z, celloutsig_0_8z, celloutsig_0_13z, celloutsig_0_4z };
  assign celloutsig_0_18z = celloutsig_0_10z[7:2] / { 1'h1, celloutsig_0_0z };
  assign celloutsig_0_280z = { celloutsig_0_135z[1], celloutsig_0_145z, celloutsig_0_27z } / { 1'h1, celloutsig_0_32z[1:0] };
  assign celloutsig_0_32z = celloutsig_0_30z[5:1] / { 1'h1, celloutsig_0_20z };
  assign celloutsig_0_6z = celloutsig_0_0z[4] & ~(celloutsig_0_2z);
  assign celloutsig_0_13z = celloutsig_0_6z & ~(celloutsig_0_6z);
  assign celloutsig_0_50z = { celloutsig_0_41z[4:0], 1'h1 } % { 1'h1, celloutsig_0_0z[3:1], celloutsig_0_38z, celloutsig_0_31z };
  assign celloutsig_0_21z = { celloutsig_0_3z[7:1], celloutsig_0_20z } % { 1'h1, celloutsig_0_7z[2:0], celloutsig_0_5z, celloutsig_0_6z, celloutsig_0_19z, celloutsig_0_12z };
  assign celloutsig_0_41z = { celloutsig_0_1z[3:2], celloutsig_0_20z } % { 1'h1, celloutsig_0_3z[4:0] };
  assign celloutsig_0_7z = celloutsig_0_3z[7:4] % { 1'h1, celloutsig_0_1z[7:5] };
  assign celloutsig_0_19z = { celloutsig_0_10z[20:18], celloutsig_0_8z } % { 1'h1, celloutsig_0_9z[3:1] };
  assign celloutsig_0_10z = - { celloutsig_0_1z[11:9], celloutsig_0_6z, celloutsig_0_5z, celloutsig_0_5z, celloutsig_0_0z, celloutsig_0_2z, celloutsig_0_6z, celloutsig_0_9z, celloutsig_0_2z, celloutsig_0_6z };
  assign celloutsig_0_9z = ~ { in_data[62:57], celloutsig_0_6z };
  assign celloutsig_0_16z = ~ { in_data[74], celloutsig_0_11z, celloutsig_0_9z, celloutsig_0_2z, celloutsig_0_13z, celloutsig_0_3z, celloutsig_0_7z };
  assign celloutsig_0_3z = { in_data[55:48], celloutsig_0_2z } | { in_data[39:33], celloutsig_0_2z, celloutsig_0_2z };
  assign celloutsig_0_68z = celloutsig_0_18z | { celloutsig_0_37z[12:8], celloutsig_0_59z };
  assign celloutsig_1_1z = in_data[143:132] | in_data[157:146];
  assign celloutsig_0_38z = & celloutsig_0_10z[19:2];
  assign celloutsig_0_4z = & { in_data[89:85], celloutsig_0_0z };
  assign celloutsig_0_59z = & { celloutsig_0_21z[9], celloutsig_0_20z, celloutsig_0_0z };
  assign celloutsig_0_145z = & { celloutsig_0_19z, celloutsig_0_11z };
  assign celloutsig_0_24z = & { celloutsig_0_14z, celloutsig_0_3z, in_data[89:85], celloutsig_0_0z };
  assign celloutsig_0_281z = & celloutsig_0_68z[4:1];
  assign celloutsig_0_27z = & celloutsig_0_3z[7:3];
  assign celloutsig_1_19z = & { celloutsig_1_5z, in_data[187:186] };
  assign celloutsig_0_31z = & { celloutsig_0_19z, celloutsig_0_15z[14:2] };
  assign celloutsig_0_33z = & { celloutsig_0_30z, celloutsig_0_16z[8] };
  assign celloutsig_0_14z = celloutsig_0_2z & celloutsig_0_13z;
  assign celloutsig_0_2z = celloutsig_0_0z[4] & in_data[14];
  assign celloutsig_1_5z = celloutsig_1_0z[0] & celloutsig_1_2z[11];
  assign celloutsig_0_28z = celloutsig_0_17z[1] & celloutsig_0_4z;
  assign celloutsig_0_135z = celloutsig_0_50z[5:3] - celloutsig_0_48z[6:4];
  assign celloutsig_0_20z = celloutsig_0_7z - { celloutsig_0_1z[12:11], celloutsig_0_13z, celloutsig_0_5z };
  assign celloutsig_1_2z = in_data[191:162] - { in_data[147:130], celloutsig_1_1z };
  assign celloutsig_0_37z = { celloutsig_0_32z[4:2], celloutsig_0_18z, celloutsig_0_12z, celloutsig_0_9z, celloutsig_0_8z } ~^ { celloutsig_0_19z[2:1], celloutsig_0_20z, celloutsig_0_5z, celloutsig_0_17z, celloutsig_0_28z, celloutsig_0_33z, celloutsig_0_14z };
  assign celloutsig_0_17z = celloutsig_0_10z[15:8] ~^ { celloutsig_0_1z[3:0], celloutsig_0_11z, celloutsig_0_13z, celloutsig_0_5z, celloutsig_0_8z };
  assign celloutsig_1_0z = in_data[145:133] ~^ in_data[173:161];
  assign celloutsig_1_18z = { celloutsig_1_2z[10:2], celloutsig_1_7z } ~^ celloutsig_1_0z[11:0];
  assign celloutsig_0_30z = celloutsig_0_10z[13:8] ~^ celloutsig_0_18z;
  assign celloutsig_0_12z = ~((celloutsig_0_6z & celloutsig_0_2z) | celloutsig_0_10z[7]);
  always_latch
    if (!clkin_data[32]) celloutsig_0_48z = 8'h00;
    else if (celloutsig_1_18z[0]) celloutsig_0_48z = { celloutsig_0_3z[5], 1'h1, celloutsig_0_27z, celloutsig_0_7z, celloutsig_0_24z };
  always_latch
    if (clkin_data[64]) celloutsig_1_7z = 3'h0;
    else if (clkin_data[0]) celloutsig_1_7z = celloutsig_1_0z[6:4];
  assign out_data = {52'b0, celloutsig_1_18z, 31'b0, celloutsig_1_19z, 61'b0, celloutsig_0_280z, 31'b0, celloutsig_0_281z};
endmodule

