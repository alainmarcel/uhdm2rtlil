// A struct FIELD of an unpacked-array element is written, then read back in the
// SAME comb block as a guard:
//     nxt[i] = cur[i];                     // whole-element prologue
//     nxt[i].dirty = src[i];               // FIELD write
//     if (nxt[i].dirty) nxt[i].phase = 4;  // IN-FLIGHT read of that field
//
// emit_dynamic_array_elem_field_write recorded the updated array in the comb
// in-flight map under the FLAT key only (`current_comb_values["nxt"]`), while
// the read path for `nxt[i].dirty` resolves the element through the PER-ELEMENT
// key (`current_comb_values["nxt[i]"]`) whenever the array has per-element
// wires -- falling back to the flat key only for a purely flat array.  So the
// field write was invisible to the read, which still saw what the prologue put
// there: the REGISTER, one cycle stale.
//
// RSD DCacheMissHandler has this shape in MSHR_PHASE_VICTIM_RECEIVE_DATA and
// took the clean-victim branch where the RTL takes the dirty one -- 272 of 301
// co-simulated cycles diverged while the bounded miter passed, because the
// sweep's miter does not run `memory_map` and read_slang infers a $mem for the
// array that read_uhdm expands (satgen then has no model for $mem_v2).
//
// The second `if` must therefore be driven by `src[i]` directly, NOT by the
// registered copy of `dirty`.
typedef struct packed {
    logic [4:0] phase;
    logic       dirty;
    logic [7:0] pad;
} E;

module comb_elem_field_write_inflight_read(
    input  logic       clk, rst,
    input  logic [1:0] start,
    input  logic [1:0] src,
    output logic [4:0] ph0, ph1,
    output logic       d0);

    E cur[2];
    E nxt[2];

    always_ff @(posedge clk)
        if (rst)
            cur <= nxt;

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            nxt[i] = cur[i];
            if (start[i])
                nxt[i].phase = 5'd3;
            nxt[i].dirty = src[i];
            if (nxt[i].dirty)
                nxt[i].phase = 5'd4;
        end
    end

    assign ph0 = cur[0].phase;
    assign ph1 = cur[1].phase;
    assign d0  = cur[0].dirty;
endmodule
