// A compound XOR on a PART-SELECT of a function-local variable
// (RSD Gshare's ToPHT_Index_Global: `phtIndex[HI:LO] ^= gh; return phtIndex;`).
function automatic logic [9:0] to_index(input logic [15:0] addr, input logic [3:0] gh);
    logic [9:0] idx;
    idx = addr[11:2];
    idx[9:6] ^= gh;
    return idx;
endfunction
module func_local_compound_partselect (input logic [15:0] addr, input logic [3:0] gh, output logic [9:0] o);
    always_comb o = to_index(addr, gh);
endmodule
