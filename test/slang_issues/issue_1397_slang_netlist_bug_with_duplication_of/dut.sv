// MikePopoloski/slang#1397 (closed): [slang-netlist] Bug with duplication of the same assignment
// https://github.com/MikePopoloski/slang/issues/1397
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module aes_key_mem1(input wire  key,
  output logic __o_key_mem_new);
 reg  key_mem_new;
   always_comb
     begin: round_key_gen
             key_mem_new   = key;
             key_mem_new   = key;
     end

  // controllable/observable ports added by test/yosys_issues/observe.py
  assign __o_key_mem_new = key_mem_new;
endmodule // aes_key_mem

