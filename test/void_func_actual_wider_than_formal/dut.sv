// A void function called with an INPUT actual WIDER than its formal: RSD
// StoreQueue's `GenerateStoreData(sqWriteStoreData[i], port.executedStoreData[i],
// port.executedStoreVectorData[i], ...)` hands the 128-bit VectorPath member
// to the 32-bit `LSQ_BlockDataPath blockDataIn`.  SV sizes the actual to the
// formal like an assignment; unpatched read_uhdm pushed the unsized
// `formal = actual` action and the read died on `Assert size() ==
// other->size()` when the interface expansion's wire removal rewrote the
// process (the row was a read-fail).
interface ifc; logic [127:0] vec [1]; logic [31:0] d; logic [1:0] sel; logic [31:0] y; modport m(input vec, d, sel, output y); endinterface
module leaf(ifc.m p);
  function automatic void Gen(output logic [31:0] dataOut, input logic [31:0] dataIn, input logic [31:0] blockDataIn, input logic [1:0] s);
    dataOut = (blockDataIn ^ dataIn) + {30'b0, s};
  endfunction
  always_comb begin
    for (int i = 0; i < 1; i++) Gen(p.y, p.d, p.vec[i], p.sel);
  end
endmodule
module void_func_actual_wider_than_formal(input logic [127:0] vec, input logic [31:0] d, input logic [1:0] sel, output logic [31:0] y);
  ifc i();
  leaf l(.p(i.m));
  assign i.vec[0] = vec; assign i.d = d; assign i.sel = sel; assign y = i.y;
endmodule
