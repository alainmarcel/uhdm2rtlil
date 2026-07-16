// Mirror of r5p_soc_memory: registered read into a STRUCT-FIELD of an interface
// signal (sub.rsp.rdt <= mem[adr]) + byte-enable memory writes. rsp is a packed
// struct like TCB. Read must stay REGISTERED (1-cycle latency).
package p;
    typedef struct packed {
        logic [31:0] rdt;
        logic        sts;
        logic        err;
        logic        pad;
    } rsp_t;
    typedef struct packed {
        logic        ren;
        logic        wen;
        logic [3:0]  byt;
        logic [3:0]  adr;
        logic [31:0] wdt;
    } req_t;
endpackage

interface mem_if;
    import p::*;
    logic clk, trn;
    req_t req;
    rsp_t rsp;
    modport sub (input clk, input trn, input req, output rsp);
endinterface

module mem_core (mem_if.sub sub);
    import p::*;
    logic [31:0] mem [0:15];
    always_ff @(posedge sub.clk) begin
        if (sub.trn) begin
            if (sub.req.ren) sub.rsp.rdt <= mem[sub.req.adr];
            if (sub.req.byt[0]) mem[sub.req.adr][ 7: 0] <= sub.req.wdt[ 7: 0];
            if (sub.req.byt[1]) mem[sub.req.adr][15: 8] <= sub.req.wdt[15: 8];
            if (sub.req.byt[2]) mem[sub.req.adr][23:16] <= sub.req.wdt[23:16];
            if (sub.req.byt[3]) mem[sub.req.adr][31:24] <= sub.req.wdt[31:24];
        end
    end
endmodule

module mem_read_reg (input logic clk, trn, input logic [41:0] reqbits, output logic [34:0] rspbits);
    import p::*;
    mem_if intf();
    assign intf.clk = clk; assign intf.trn = trn;
    assign intf.req = reqbits;
    assign rspbits = intf.rsp;
    mem_core u (.sub(intf));
endmodule
