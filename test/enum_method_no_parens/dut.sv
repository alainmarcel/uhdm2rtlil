// povik/sv-elab#158: enum built-in methods called WITHOUT parentheses
// (`color1.prev`; LRM 13.5.5 lets a call with no arguments omit them).
// Surelog keeps `color1.prev` a two-element hier_path whose tail is a bare
// ref_obj, so read_uhdm resolved it as a struct member, warned "Could not
// resolve struct member access 'color1.prev'" and drove X.
// Four members over a 2-bit base: every input value is a member, so the
// co-sim's random stimulus never reaches the out-of-range case.
typedef enum logic [1:0] {r, g, b, w} color_t;
module top(input color_t color1,
           output color_t p, output color_t n, output color_t f,
           output color_t l, output int k);
  always_comb begin
    p = color1.prev;
    n = color1.next;
    f = color1.first;
    l = color1.last;
    k = color1.num;
  end
endmodule
