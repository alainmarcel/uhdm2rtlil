// RSD DCacheMissHandler: a void function with its own `for (int i ...)` loop
// (MergeStoreDataToLine) is called from one arm of a `case` inside the
// process's own `for (int i ...)` loop.  The inlined loop's exit value of `i`
// leaked into the enclosing iteration: every statement imported after the
// call -- the whole `default:` arm, which is emitted last -- indexed the
// 2-entry arrays with i == 2 and the MSHR never allocated.
typedef enum logic [4:0] { P_INVALID = 0, P_FLUSH = 1, P_VICTIM_REQ = 7, P_MISS_REQ = 13, P_DONE = 18 } phase_t;
typedef struct packed {
  logic valid; phase_t phase; logic [7:0] addr; logic canBeInvalid; logic flushed; logic byStore; logic unc; logic [3:0] alptr;
} ent_t;
function automatic logic Det(input logic range, input logic [3:0] h, input logic [3:0] t, input logic all, input logic [3:0] op);
  if (!range) return 1'b0;
  else if (all) return 1'b1;
  else if (range && t >= h) begin
    if (op >= h && op < t) return 1'b1; else return 1'b0;
  end
  else if (range && t < h) begin
    if (op >= h && op > t) return 1'b1;
    else if (op < h && op < t) return 1'b1;
    else return 1'b0;
  end
  else return 1'b0;
endfunction
function automatic void Merge(output logic [7:0] dst, input logic [7:0] a, input logic [7:0] b, input logic [1:0] dirty);
  for (int i = 0; i < 2; i++) begin
    for (int k = 0; k < 4; k++) begin
      dst[i*4 + k] = dirty[i] ? b[i*4 + k] : a[i*4 + k];
    end
  end
endfunction
module comb_task_loop_var_shadows_outer_loop(input logic clk, input logic rst,
  input logic [1:0] init, input logic [15:0] initAddr, input logic [7:0] initPtr, input logic [1:0] byStore, input logic [1:0] unc,
  input logic toRecovery, input logic [3:0] head, input logic [3:0] tail, input logic flushAll, input logic flushing, input logic [1:0] grant, input logic [1:0] canInv, input logic [15:0] stored, input logic [3:0] dirty,
  output logic [1:0] valid_o, output logic [9:0] phase_o, output logic [15:0] addr_o, output logic [1:0] flushed_o, output logic [1:0] cbi_o);
  ent_t mshr [2];
  ent_t nextMSHR [2];
  logic flushAlloc [2];
  logic flushEntry [2];
  logic [7:0] m8;
  always_comb begin
    m8 = '0;
    for (int i = 0; i < 2; i++) begin
      nextMSHR[i] = mshr[i];
      if (canInv[i]) nextMSHR[i].canBeInvalid = 1'b1;
      flushAlloc[i] = Det(toRecovery, head, tail, flushAll, initPtr[i*4 +: 4]);
      flushEntry[i] = Det(toRecovery, head, tail, flushAll, mshr[i].alptr);
      if (flushEntry[i] && !mshr[i].byStore) begin
        nextMSHR[i].flushed = 1'b1;
        nextMSHR[i].canBeInvalid = 1'b1;
      end
      case (mshr[i].phase)
        default: begin
          if (init[i] && !flushAlloc[i]) begin
            nextMSHR[i].valid = 1'b1;
            nextMSHR[i].addr = initAddr[i*8 +: 8];
            nextMSHR[i].canBeInvalid = 1'b0;
            nextMSHR[i].flushed = 1'b0;
            nextMSHR[i].byStore = byStore[i];
            nextMSHR[i].unc = unc[i];
            if (unc[i]) nextMSHR[i].phase = P_MISS_REQ;
            else nextMSHR[i].phase = P_VICTIM_REQ;
            nextMSHR[i].alptr = initPtr[i*4 +: 4];
          end
          else if (flushing && (i == 0)) begin
            nextMSHR[i].valid = 1'b1;
            nextMSHR[i].addr = '0;
            nextMSHR[i].canBeInvalid = 1'b0;
            nextMSHR[i].flushed = 1'b0;
            nextMSHR[i].byStore = 1'b0;
            nextMSHR[i].unc = 1'b0;
            nextMSHR[i].phase = P_FLUSH;
            nextMSHR[i].alptr = initPtr[i*4 +: 4];
          end
        end
        P_FLUSH: nextMSHR[i].phase = grant[i] ? P_DONE : P_FLUSH;
        P_VICTIM_REQ: nextMSHR[i].phase = grant[i] ? P_MISS_REQ : P_VICTIM_REQ;
        P_MISS_REQ: nextMSHR[i].phase = grant[i] ? P_DONE : P_MISS_REQ;
        P_DONE: begin
          Merge(m8, mshr[i].addr, stored[i*8 +: 8], dirty[i*2 +: 2]);
          nextMSHR[i].addr = m8;
          if (mshr[i].canBeInvalid || mshr[i].flushed) begin
            nextMSHR[i].valid = 1'b0;
            nextMSHR[i].phase = P_INVALID;
          end
        end
      endcase
      valid_o[i] = mshr[i].valid;
      phase_o[i*5 +: 5] = mshr[i].phase;
      addr_o[i*8 +: 8] = mshr[i].addr;
      flushed_o[i] = mshr[i].flushed;
      cbi_o[i] = mshr[i].canBeInvalid;
    end
  end
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 2; i++) begin
        mshr[i].valid <= 1'b0;
        mshr[i].phase <= P_INVALID;
        mshr[i].canBeInvalid <= 1'b0;
        mshr[i].flushed <= 1'b0;
        mshr[i].byStore <= 1'b0;
      end
    end
    else begin
      mshr <= nextMSHR;
    end
  end
endmodule
