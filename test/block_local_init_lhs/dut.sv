// A block-local DECLARATION WITH AN INITIALISER at the top of a begin block
// (snitch spatz_vsldu: `automatic int unsigned delta = spatz_req.vl -
// vreg_counter_q;`).  Surelog lowers the initialiser into an assignment whose
// LHS is the variable itself, not a reference to it; unpatched read_uhdm
// dropped it ("Unsupported expression type: int_var") and every read of the
// local saw an undriven wire.  One local per variable kind; all AUTOMATIC -- a static local's initialiser runs
// once before time 0 (LRM 6.21) and is deliberately left alone.
module dut (
    input  logic [9:0] vl,
    input  logic [9:0] cnt,
    input  logic       v,
    output logic       last,
    output logic [9:0] d_int,
    output logic [9:0] d_logic,
    output logic [9:0] d_integer,
    output logic [9:0] d_bit
);
    always_comb begin : p
        automatic int unsigned delta = vl - cnt;
        last  = v && (delta <= (64 - cnt[5:0]));
        d_int = '0;
        if (v) d_int = delta;
    end : p
    always_comb begin
        automatic logic [31:0] dl = vl + cnt;
        d_logic = dl;
    end
    always_comb begin
        automatic integer di = vl ^ cnt;
        d_integer = di;
    end
    always_comb begin
        automatic bit [31:0] db = vl & cnt;
        d_bit = db;
    end
endmodule
