// A 2-D unpacked INTERFACE member written and read with two constant indices
// from modport modules (RSD DCacheIF `DCacheTagPath tagArrayDataOut[WAYS][PORTS]`,
// written by DCacheArray `port.tagArrayDataOut[way][p] = ...` and read by the
// port multiplexer).
interface ifc;
  logic [3:0] d [2][2];
  logic [3:0] a [2][2];
  logic [3:0] y [2];
  modport w(input a, output d);
  modport r(input d, output y);
endinterface
module writer(ifc.w p);
  always_comb begin
    for (int w = 0; w < 2; w++)
      for (int k = 0; k < 2; k++)
        p.d[w][k] = p.a[w][k] + 4'd1;
  end
endmodule
module reader(ifc.r p);
  always_comb begin
    for (int w = 0; w < 2; w++) p.y[w] = p.d[w][0] ^ p.d[w][1];
  end
endmodule
module iface_2d_member_elem_select(input logic [15:0] a_flat, output logic [7:0] y_flat);
  ifc i();
  writer wr(.p(i.w));
  reader rd(.p(i.r));
  for (genvar w = 0; w < 2; w++) begin : gw
    for (genvar k = 0; k < 2; k++) begin : gk
      assign i.a[w][k] = a_flat[(w*2+k)*4 +: 4];
    end
    assign y_flat[w*4 +: 4] = i.y[w];
  end
endmodule
