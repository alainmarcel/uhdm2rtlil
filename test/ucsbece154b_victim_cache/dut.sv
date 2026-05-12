module ucsbece154b_victim_cache(
    input   logic [7:0]  raddr_i
);

localparam OFFSET_WIDTH = 1;
localparam TAG_SIZE = 1;

logic [TAG_SIZE-1:0] rtag;
assign rtag = raddr_i[OFFSET_WIDTH +: TAG_SIZE];

integer i;

typedef logic [1:0] way_index_t;

struct packed {
    logic [TAG_SIZE-1:0] tag;
    way_index_t lru;
    way_index_t mru;
    logic valid;
} dll_d[4], dll_q[4];

way_index_t lru_d, lru_q, mru_d, mru_q;
way_index_t read_index;
always_comb begin
    read_index = 'x;
    lru_d = lru_q;
    mru_d = mru_q;
    dll_d = dll_q;

    for (i = 0; i < 4; i++) begin
        if (dll_d[i].valid && (rtag==dll_d[i].tag)) begin
            read_index = way_index_t'(i);
            break;
        end
    end
end
endmodule
