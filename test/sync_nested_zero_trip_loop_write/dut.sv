// RSD WakeupPipelineRegister: a WHOLE-ELEMENT write with TWO indices on a 2-D
// unpacked array of structs (`intPipeReg[i][LATENCY-1] <= nextIntPipeReg[i]`)
// inside an always_ff else-branch under an unrolled loop.  The per-FIELD
// two-index writes of the reset branch (`.valid`, `.depVector`) land, but the
// whole-element write is dropped: `ptr` and `activeListPtr` of every element
// get no driver (and the output that reads `ptr` goes undriven with them).
typedef struct packed { logic valid; logic [3:0] ptr; logic [7:0] depVector; logic [5:0] activeListPtr; } preg_t;
module sync_nested_zero_trip_loop_write(input logic clk, input logic rst, input logic stall,
  input logic [1:0] selValid, input logic [7:0] selPtr, input logic [15:0] selVec, input logic [11:0] selAlPtr,
  output logic [7:0] releasePtr, output logic [1:0] validOut, output logic [11:0] alPtrOut);
  preg_t intPipeReg [2][1];
  preg_t nextIntPipeReg [2];
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      nextIntPipeReg[i].valid = selValid[i];
      nextIntPipeReg[i].ptr = selPtr[i*4 +: 4];
      nextIntPipeReg[i].depVector = selVec[i*8 +: 8];
      nextIntPipeReg[i].activeListPtr = selAlPtr[i*6 +: 6];
    end
  end
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 2; i++) begin
        for (int j = 0; j < 1; j++) begin
          intPipeReg[i][j].valid <= 1'b0;
          intPipeReg[i][j].depVector <= '0;
        end
      end
    end
    else if (!stall) begin
      for (int i = 0; i < 2; i++) begin
        for (int j = 1; j < 1; j++) begin
          intPipeReg[i][j-1] <= intPipeReg[i][j];
        end
        intPipeReg[i][ 0 ] <= nextIntPipeReg[i];
      end
    end
  end
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      releasePtr[i*4 +: 4] = intPipeReg[i][0].ptr;
      validOut[i] = intPipeReg[i][0].valid;
      alPtrOut[i*6 +: 6] = intPipeReg[i][0].activeListPtr;
    end
  end
endmodule
