// MikePopoloski/slang#2079 (closed): Implicit return variable of a static function is given an automatic lifetime
// https://github.com/MikePopoloski/slang/issues/2079
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m;
  function [3:0] keep(input enable, input [3:0] value);
    logic [3:0] local_copy;
    local_copy = value;
    if (enable) keep = local_copy;
  endfunction
endmodule

