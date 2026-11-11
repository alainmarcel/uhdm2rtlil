// A for loop inside a function whose step is `ib += 8` (or `ib = ib + 8`)
// was unrolled with step 1: 32 overlapping byte writes instead of 4.  OpenTitan
// i3c_controller_fsm reverses the transmit word this way (revb / revh) and
// sent a scrambled word to the transceiver.
module dut #(parameter int DataWidth = 32) (input logic [DataWidth-1:0] wdata,
            output logic [DataWidth-1:0] o_b, o_l, o_h, o_d);
  function automatic logic [DataWidth-1:0] revb(logic [DataWidth-1:0] wdata);
    for (int unsigned ib = 0; ib < DataWidth; ib += 8) begin
      revb[DataWidth - ib - 8 +: 8] = wdata[ib +: 8];
    end
  endfunction
  function automatic logic [DataWidth-1:0] revb_local(logic [DataWidth-1:0] wdata);
    logic [DataWidth-1:0] r;
    for (int ib = 0; ib < DataWidth; ib = ib + 8) begin
      r[DataWidth - ib - 8 +: 8] = wdata[ib +: 8];
    end
    return r;
  endfunction
  function automatic logic [DataWidth-1:0] revh(logic [DataWidth-1:0] wdata);
    for (int unsigned ib = 0; ib < DataWidth; ib += 16) begin
      revh[DataWidth - ib - 16 +: 16] = wdata[ib +: 16];
    end
  endfunction
  function automatic logic [DataWidth-1:0] down(logic [DataWidth-1:0] wdata);
    for (int ib = DataWidth - 8; ib >= 0; ib -= 8) begin
      down[ib +: 8] = wdata[DataWidth - ib - 8 +: 8];
    end
  endfunction
  assign o_b = revb(wdata);
  assign o_l = revb_local(wdata);
  assign o_h = revh(wdata);
  assign o_d = down(wdata);
endmodule
