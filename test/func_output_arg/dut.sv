// Reproducer for chipsalliance/synlig#554 — a `function automatic
// void` whose first formal is `output` and whose body assigns to the
// output via mixed forms:
//   * full-wire assignment (`new_lru = old_lru`)
//   * constant bit-select (`new_lru[6] = ~old_lru[6]`)
//   * if-else over a const bit-select (`new_lru[5]` / `new_lru[4]`)
//   * *dynamic* bit-select with a slice as the index
//     (`new_lru[way_id[2:1]] = ~old_lru[way_id[2:1]]`)
// The dynamic-bit-select LHS is what the original orv64 source hit
// hardest — the plugin used to abort while elaborating the function
// body.
module func_output_arg (
    input  logic [6:0] old_lru,
    input  logic [2:0] way_id,
    output logic [6:0] new_lru
);
    function automatic void lru8_update_lru(
        output logic [6:0] new_lru,
        input  logic [6:0] old_lru,
        input  logic [2:0] way_id
    );
        new_lru = old_lru;
        new_lru[6] = ~old_lru[6];
        if (way_id[2])
            new_lru[5] = ~old_lru[5];
        else
            new_lru[4] = ~old_lru[4];
        new_lru[way_id[2:1]] = ~old_lru[way_id[2:1]];
    endfunction

    always_comb
        lru8_update_lru(new_lru, old_lru, way_id);
endmodule
