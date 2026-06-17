// Exercise an index EXPRESSION (`2-2`, `2-1`, `2-0`) on a packed array of
// structs while driving/observing every element (no dead undriven-X bits).
module top(input int i0, input int i1, input int i2, output int o);
   typedef struct packed {
      int 	  nonce;
   } sram_otp_key_rsp_t;

   sram_otp_key_rsp_t [2:0] sram_otp_key_o;

   assign sram_otp_key_o[2-2].nonce = i0;
   assign sram_otp_key_o[2-1].nonce = i1;
   assign sram_otp_key_o[2-0].nonce = i2;
   assign o = sram_otp_key_o[0].nonce
            ^ sram_otp_key_o[1].nonce
            ^ sram_otp_key_o[2].nonce;

endmodule // top
