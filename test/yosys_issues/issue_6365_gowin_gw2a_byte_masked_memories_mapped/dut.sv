// YosysHQ/yosys#6365 (open): Gowin GW2A: byte-masked memories mapped to DP with ADA[1:0] byte enables lose data on back-to-back writes
// https://github.com/YosysHQ/yosys/issues/6365
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// Standalone reproducer: GW2A-18C (Tang Nano 20K) DP block RAM with byte enables loses data when
// two byte-masked writes hit one address on consecutive cycles. No CPU, no other files.
//   A  1024 x 32 memory with 4 byte masks (yosys maps: 2 x DPX9B x18, byte enables on ADA[1:0])
//   B  the same data as four 1024 x 8 memories (4 x DPX9B x9, byte enables constant)
// Trial: write a random fill word (all masks), byte-write v1 to lane i, `gap` idle cycles,
// byte-write v2 to lane j, read back, compare. Per configuration (i != j, gap 0..2,
// r: port B also reads the trial's address every cycle, d: unmasked lanes' data pins carry the
// byte or its complement) 2^LOGN random trials. One line per configuration at 115200 baud
// (pin 69): bad words, bits cleared, bits set, for A then B. LEDs: run count, busy, A bad, B bad.
module top #(parameter LOGN = 14, parameter DIV = 234, parameter DLYW = 26) (   // 27 MHz / 115200, 2.5 s
    input  wire       clk,
    output wire       uart_tx,
    output wire [5:0] led
);
    // ---- the two RAMs, all inputs from flip-flops ----
    reg         we = 0;
    reg  [3:0]  mask = 0;
    reg  [9:0]  wa = 0, ra = 0;
    reg  [31:0] wd = 0;
    reg         re = 0;
    wire [31:0] qa, qb;

    reg  [31:0] mem_a [0:1023];
    reg  [31:0] q_a;
    integer k;
    always @(posedge clk)
        if (we) for (k = 0; k < 4; k = k + 1) if (mask[k]) mem_a[wa][8*k +: 8] <= wd[8*k +: 8];
    always @(posedge clk) if (re) q_a <= mem_a[ra];
    assign qa = q_a;

    genvar l;
    generate for (l = 0; l < 4; l = l + 1) begin : lane
        reg [7:0] mem [0:1023];
        reg [7:0] q;
        always @(posedge clk) if (we && mask[l]) mem[wa] <= wd[8*l +: 8];
        always @(posedge clk) if (re) q <= mem[ra];
        assign qb[8*l +: 8] = q;
    end endgenerate

    // ---- trial sequencer ----
    reg  [31:0] rng = 32'h1234_5678;
    function [31:0] xs(input [31:0] x);
        reg [31:0] y; begin y = x ^ (x << 13); y = y ^ (y >> 17); xs = y ^ (y << 5); end
    endfunction
    wire [31:0] r1 = xs(rng), r2 = xs(r1);

    reg  [3:0]  cp = 0;                           // configuration: lane pair (i, j), i != j
    reg  [1:0]  cg = 0;
    wire [1:0]  ci = cp / 3;
    wire [1:0]  cj = (cp % 3) >= ci ? (cp % 3) + 1 : (cp % 3);
    reg         cr = 0, cd = 0;
    reg  [31:0] fill = 0;
    reg  [7:0]  v1 = 0, v2 = 0;
    reg  [9:0]  addr = 0;
    reg  [3:0]  t = 0;
    reg  [LOGN:0] n = 0;
    reg  [19:0] abad = 0, aclr = 0, aset = 0, bbad = 0, bclr = 0, bset = 0;

    function [31:0] lanes(input [7:0] v, input [1:0] k, input inv);   // data pins for a byte store
        lanes = inv ? ~({4{v}}) ^ ({24'b0, 8'hff} << 8 * k) : {4{v}};
    endfunction
    function [5:0] popc(input [31:0] x);
        integer b; begin popc = 0; for (b = 0; b < 32; b = b + 1) popc = popc + x[b]; end
    endfunction
    wire [31:0] want0 = (fill & ~(32'hff << 8 * ci)) | ({24'b0, v1} << 8 * ci);
    wire [31:0] want  = (want0 & ~(32'hff << 8 * cj)) | ({24'b0, v2} << 8 * cj);
    wire [3:0]  t_v2 = 4'd3 + cg, t_rd = 4'd6 + cg, t_ck = 4'd8 + cg;

    // ---- printer: one 65-character line ----
    localparam L = 65;
    reg  [8*L-1:0] line;
    reg  [6:0]  left = 0;
    reg         tx_go = 0;
    wire        tx_busy;
    reg  [7:0]  run = 0;
    function [7:0] hx(input [3:0] v); hx = v < 10 ? "0" + v : "a" + v - 10; endfunction
    function [39:0] h5(input [19:0] v);
        h5 = {hx(v[19:16]), hx(v[15:12]), hx(v[11:8]), hx(v[7:4]), hx(v[3:0])};
    endfunction

    localparam S_WAIT = 0, S_HEAD = 1, S_RUN = 2, S_LINE = 3, S_SEND = 4;
    reg  [2:0]  s = S_WAIT, s_after = S_RUN;
    reg  [DLYW-1:0] dly = 0;

    always @(posedge clk) begin
        tx_go <= 0;
        we <= 0; re <= cr;
        case (s)
        S_WAIT: begin                               // 2.5 s between runs, so a listener can start
            dly <= dly + 1;
            if (&dly) s <= S_HEAD;
        end
        S_HEAD: begin
            line <= {"bsram run ", hx(run[7:4]), hx(run[3:0]), "  i j g r d  A: bad   clr   set  B: bad   clr   set", 8'h0d, 8'h0a};
            left <= L; s <= S_SEND; s_after <= S_RUN;
            cp <= 0; cg <= 0; cr <= 0; cd <= 0; t <= 0; n <= 0;
            {abad, aclr, aset, bbad, bclr, bset} <= 0;
            fill <= r1; {v1, v2, addr} <= r2[25:0]; rng <= r2;
        end
        S_RUN: begin
            t <= t + 1;
            wa <= addr;                         // the read port has its own address logic, as in the
            ra <= (cr || t == t_rd) ? addr : 10'd0;   // cache (one shared register would make yosys build SP)
            if (t == 0)    begin we <= 1; mask <= 4'hf; wd <= fill; end
            if (t == 2)    begin we <= 1; mask <= 4'b1 << ci; wd <= lanes(v1, ci, cd); end
            if (t == t_v2) begin we <= 1; mask <= 4'b1 << cj; wd <= lanes(v2, cj, cd); end
            if (t == t_rd) re <= 1;
            if (t == t_ck) begin
                if (qa != want) abad <= abad + 1;
                if (qb != want) bbad <= bbad + 1;
                aclr <= aclr + popc(want & ~qa); aset <= aset + popc(qa & ~want);
                bclr <= bclr + popc(want & ~qb); bset <= bset + popc(qb & ~want);
                t <= 0; n <= n + 1;
                fill <= r1; {v1, v2, addr} <= r2[25:0]; rng <= r2;
                if (n == (1 << LOGN) - 1) s <= S_LINE;
            end
        end
        S_LINE: begin
            line <= {"              ", hx(ci), " ", hx(cj), " ", hx(cg), " ", hx(cr), " ", hx(cd), "  ",
                     h5(abad), " ", h5(aclr), " ", h5(aset), "  ", h5(bbad), " ", h5(bclr), " ", h5(bset), "  ", 8'h0d, 8'h0a};
            left <= L; s <= S_SEND; s_after <= S_RUN; t <= 0; n <= 0;
            {abad, aclr, aset, bbad, bclr, bset} <= 0;
            // next configuration: d, then r, then gap, then the lane pair
            if (!cd) cd <= 1;
            else begin cd <= 0;
                if (!cr) cr <= 1;
                else begin cr <= 0;
                    if (cg != 2) cg <= cg + 1;
                    else begin cg <= 0;
                        if (cp != 11) cp <= cp + 1;
                        else begin cp <= 0; s_after <= S_WAIT; run <= run + 1; end
                    end
                end
            end
        end
        S_SEND: if (!tx_busy && !tx_go) begin
            if (left == 0) s <= s_after;
            else begin tx_go <= 1; left <= left - 1; end
        end
        endcase
    end
    wire [7:0] tx_byte = line[8*left +: 8];         // left was just decremented: char index L-1-left

    uart_tx #(.DIV(DIV)) u (.clk(clk), .start(tx_go), .data(tx_byte), .tx(uart_tx), .busy(tx_busy));
    assign led = ~{run[1:0], s == S_RUN, abad != 0, bbad != 0, 1'b1};
endmodule

// 8 data bits, no parity, 1 stop bit.
module uart_tx #(parameter DIV = 234) (
    input  wire       clk,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx = 1,
    output wire       busy
);
    reg [9:0]  shift = 10'h3ff;
    reg [3:0]  bits  = 0;
    reg [15:0] cnt   = 0;
    assign busy = bits != 0;

    always @(posedge clk) begin
        if (bits == 0) begin
            tx <= 1;
            if (start) begin
                shift <= {1'b1, data, 1'b0};        // stop bit, data, start bit
                bits  <= 10;
                cnt   <= 0;
            end
        end else begin
            tx <= shift[0];
            if (cnt == DIV - 1) begin
                cnt   <= 0;
                shift <= {1'b1, shift[9:1]};
                bits  <= bits - 1;
            end else
                cnt <= cnt + 1;
        end
    end
endmodule

