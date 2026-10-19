// A packed array whose element type is a TYPEDEF ALIAS of a packed array
// (`typedef InsnPath [3:0] LineT`), used as the element of an UNPACKED
// array written by instance outputs, read with a DYNAMIC outer index and a
// DYNAMIC element index: `readLineInsnList[hitWay][wordPtr[i]]` must select a
// 32-bit instruction word, not one bit (RSD ICache, 39 co-sim divergences).
// Surelog stores LineT as a logic_typespec whose Elem_typespec is the
// anonymous `InsnPath [3:0]` typespec and whose own Range REPEATS the inner
// one; the definition-view var_select carries no Actual_group.
typedef logic [31:0] InsnPath;
typedef InsnPath [3:0] LineT;
typedef logic [1:0] WordIdx;

module way (input logic [6:0] seed, output LineT readLineData, output logic hit);
  assign readLineData = {{25'd0, seed}, {25'd1, seed}, {25'd2, seed}, {25'd3, seed}};
  assign hit = seed[0];
endmodule

module top (input logic [6:0] seedA, seedB, input logic [1:0] addr,
            output InsnPath out0, out1, output logic [1:0] hits);
  logic [0:0] hitWay;
  logic [1:0] hitArray;
  WordIdx wordPtr [2];
  LineT readLineInsnList [2];
  InsnPath icReadDataOut [2];
  for (genvar i = 0; i < 2; i++) begin : g
    way array (.seed(i == 0 ? seedA : seedB), .readLineData(readLineInsnList[i]), .hit(hitArray[i]));
  end
  always_comb begin
    hitWay = '0;
    for (int i = 0; i < 2; i++) if (hitArray[i]) hitWay = i;
  end
  always_comb begin
    wordPtr[0] = addr;
    for (int i = 1; i < 2; i++) wordPtr[i] = wordPtr[0] + i;
    for (int i = 0; i < 2; i++) icReadDataOut[i] = readLineInsnList[hitWay][ wordPtr[i] ];
  end
  assign out0 = icReadDataOut[0];
  assign out1 = icReadDataOut[1];
  assign hits = hitArray;
endmodule
