// IEEE 1800-2023 11.3 / Table 11-1: every synthesizable operator on UNSIGNED
// 8-bit operands.  Each result is a separate output so a wrong operator shows
// up on its own port.  The shift amount comes from an input, so shifts by the
// full width and beyond are reached by stimulus.  (** is tested in
// lrm_power_variable_exponent: read_slang's $pow cell has no SAT model.)
module dut(input  logic [7:0] a, b, input logic [3:0] sh,
           output logic [7:0] add, sub, mul, div, rem, shl2,
           output logic [7:0] band, bor, bxor, bxnor1, bxnor2, bnot, uneg, upos,
           output logic       rand_, rnand, ror_, rnor, rxor, rxnor1, rxnor2,
           output logic       lnot, land, lor, limp, leqv,
           output logic       lt, le, gt, ge, eq, ne, ceq, cne, weq, wne,
           output logic [7:0] shl, shr, ashl, ashr,
           output logic [15:0] cat, output logic [23:0] rep,
           output logic [7:0] cond, output logic in_set,
           output logic [7:0] strm_l, strm_r,
           output logic [7:0] inc, dec, cadd, csub, cmul, cand, cor, cxor,
           output logic [7:0] cshl, cshr, cashl, cashr, cdiv, crem);
  // An odd divisor is never 0: x / 0 is X by 11.4.2, but a 2-state simulator
  // returns 0, so the co-sim could not check it.
  logic [7:0] bnz;
  assign bnz = {b[7:1], 1'b1};
  assign add = a + b;   assign sub = a - b;   assign mul = a * b;
  assign div = a / bnz; assign rem = a % bnz;   assign shl2 = a << 2;
  assign band = a & b;  assign bor = a | b;   assign bxor = a ^ b;
  assign bxnor1 = a ~^ b; assign bxnor2 = a ^~ b;
  assign bnot = ~a;     assign uneg = -a;     assign upos = +a;
  assign rand_ = &a;    assign rnand = ~&a;   assign ror_ = |a;
  assign rnor = ~|a;    assign rxor = ^a;     assign rxnor1 = ~^a;
  assign rxnor2 = ^~a;
  assign lnot = !a;     assign land = a && b; assign lor = a || b;
  assign limp = a -> b; assign leqv = a <-> b;
  assign lt = a < b;    assign le = a <= b;   assign gt = a > b;
  assign ge = a >= b;   assign eq = a == b;   assign ne = a != b;
  assign ceq = a === b; assign cne = a !== b;
  assign weq = a ==? 8'b1x1x_0zz1;
  assign wne = b !=? 8'bz1z1_xx00;
  assign shl = a << sh;  assign shr = a >> sh;
  assign ashl = a <<< sh; assign ashr = a >>> sh;   // unsigned: logical
  assign cat = {a, b};   assign rep = {3{a ^ b}};
  assign cond = (a > b) ? a - b : b - a;
  assign in_set = a inside {8'd3, [8'd10:8'd20], 8'b1???_0000, [b:8'd250]};
  assign strm_l = {<<{a}};
  assign strm_r = {<<4{b}};
  always_comb begin
    inc = a; inc++;
    dec = a; --dec;
    cadd = a; cadd += b;   csub = a; csub -= b;   cmul = a; cmul *= b;
    cand = a; cand &= b;   cor  = a; cor  |= b;   cxor = a; cxor ^= b;
    cshl = a; cshl <<= sh; cshr = a; cshr >>= sh;
    cashl = a; cashl <<<= sh; cashr = a; cashr >>>= sh;
    cdiv = a; cdiv /= (b | 8'd1);  crem = a; crem %= (b | 8'd1);
  end
endmodule
