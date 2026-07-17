package p;
    typedef struct packed { logic [4:0] opc; logic [2:0] fn3; logic [4:0] rd; } dec_t;
    typedef struct packed { logic wen; logic [1:0] siz; logic [7:0] wdt; } req_t;
endpackage
interface bus_if;
    import p::*;
    req_t req;
    modport man (output req);
endinterface
module lsu (bus_if.man tcb, input p::dec_t dec, input logic st, input logic [7:0] wd);
    // A PROCESS drives one field (wen) so tcb.req is assembled via $0\tcb.req,
    // matching the SoC r5p_lsu (always_comb case for wen/ren + cont_assign siz).
    always_comb begin
        if (st) tcb.req.wen = 1'b1;
        else    tcb.req.wen = 1'b0;
    end
    assign tcb.req.siz = dec.fn3[1:0];  // the 2-bit struct-field part-select
    assign tcb.req.wdt = wd;
endmodule
module iface_field_partsel (input p::dec_t dec, input logic st, input logic [7:0] wd,
                            output logic [10:0] reqbits);
    bus_if bi();
    assign reqbits = bi.req;
    lsu u (.tcb(bi), .dec(dec), .st(st), .wd(wd));
endmodule
