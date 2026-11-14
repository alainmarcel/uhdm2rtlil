// povik/sv-elab#108 (closed): Unhelpful message on interfaces w/o modports in kept hierarchy mode
// https://github.com/povik/sv-elab/issues/108
// Code block(s) from the issue (variant s0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
interface bus();
	logic w;
endinterface

module m1(bus intf);
	assign intf.w = 0;
endmodule

module top(__o_intf1_w, __o_intf2_w);
	bus intf1();
	bus intf2();

	m1 a(.intf(intf1));
	m1 b(.intf(intf2));

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_intf1_w;
  output logic __o_intf2_w;
  assign __o_intf1_w = intf1.w;
  assign __o_intf2_w = intf2.w;
endmodule

