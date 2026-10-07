// A conditional WHOLE-signal write followed by unconditional FIELD writes, and
// then one more conditional field write.  This is how VeeR EH1's
// dec_decode_ctl builds its trap packet (dec_tlu_packet_e4), and the ordering
// is the whole point: RTLIL applies a case's `actions` before its `switches`,
// so field writes hoisted into the root case are overwritten by the
// whole-signal arms unless the arms give those bits up.
//
// Every field is observable and the three writes land on DIFFERENT bits, so a
// single surviving clobber shows up:
//   .legal  (bit 7)   -- `|` with div_finish, so it differs from src in the
//                        div_finish arm, where the whole-signal write is '0
//   .trig   (6:3)     -- 4'hA under div_finish, and re-written under freeze
//                        AFTER the unconditional write, so the later
//                        conditional write must still win
//   .divide (bit 2)   -- exactly div_finish, which the '0 arm would zero
typedef struct packed {
    logic       legal;
    logic [3:0] trig;
    logic       divide;
    logic [1:0] tag;
} pkt_t;

module comb_field_write_after_switch (
    input  logic       div_finish,
    input  logic       freeze,
    input  pkt_t       src,
    input  logic [3:0] frz_trig,
    output pkt_t       pkt_o
);

    always_comb begin
        if (div_finish)
            pkt_o = '0;
        else
            pkt_o = src;

        pkt_o.legal  = src.legal | div_finish;
        pkt_o.trig   = div_finish ? 4'hA : src.trig;
        pkt_o.divide = div_finish;

        if (freeze)
            pkt_o.trig = frz_trig;
    end

endmodule
