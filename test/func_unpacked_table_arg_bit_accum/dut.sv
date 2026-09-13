package func_unpacked_table_arg_pkg;
  localparam logic [7:0] A2X [8] = '{8'h98, 8'hf3, 8'hf2, 8'h48, 8'h09, 8'h81, 8'ha9, 8'hff};
  function automatic logic [7:0] aes_mvm(logic [7:0] vec_b, logic [7:0] mat_a [8]);
    logic [7:0] vec_c;
    vec_c = '0;
    for (int i = 0; i < 8; i++) begin
      for (int j = 0; j < 8; j++) begin
        vec_c[i] = vec_c[i] ^ (mat_a[j][i] & vec_b[7-j]);
      end
    end
    return vec_c;
  endfunction
endpackage
module func_unpacked_table_arg_bit_accum import func_unpacked_table_arg_pkg::*; (input logic [7:0] d, output logic [7:0] o, output logic [7:0] o2);
  logic [7:0] mat [8];
  assign mat[0] = d; assign mat[1] = ~d; assign mat[2] = {d[3:0], d[7:4]}; assign mat[3] = d ^ 8'h5a;
  assign mat[4] = d + 8'd1; assign mat[5] = d - 8'd3; assign mat[6] = d << 1; assign mat[7] = d >> 2;
  assign o = aes_mvm(d, A2X);
  assign o2 = aes_mvm(~d, mat);
endmodule
