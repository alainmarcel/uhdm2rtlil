// povik/sv-elab#72 (open): Simpler sourcing of technology libraries in FPGA flows
// https://github.com/povik/sv-elab/issues/72
// Code block(s) from the issue (variant s2); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
(* blackbox *)
module SB_RGBA_DRV(
	input CURREN,
	input RGBLEDEN,
	input RGB0PWM,
	input RGB1PWM,
	input RGB2PWM,
	output RGB0,
	output RGB1,
	output RGB2
);
parameter CURRENT_MODE = "0b0";
parameter RGB0_CURRENT = "0b000000";
parameter RGB1_CURRENT = "0b000000";
parameter RGB2_CURRENT = "0b000000";
endmodule

