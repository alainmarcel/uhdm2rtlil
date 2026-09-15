#!/usr/bin/env python3
"""Generate wrappers/flat_usbdev_selftest.sv: a self-driving usbdev test top.

The plain usbdev co-sim drives random TL-UL and USB pins, which never enables
the device, never issues a bus reset and never forms a valid USB packet: the
USB datapath (usb_fs_rx / nb_pe / tx, packet buffer via the USB side, RX FIFO)
stayed idle and the NO_DIVERGENCE verdict said nothing about it.

usbdev_selftest_flat has only clk_i / rst_ni.  A TL-UL master (through
tlul_cmd_intg_gen) and a USB full-speed host model run one fixed program:
enable, bus reset, packet-buffer write/read through the SRAM window, endpoint
setup, SETUP + DATA0 (device ACKs), IN (device sends the configin_0 buffer,
host ACKs), OUT + DATA1 (device ACKs), then read back interrupts, both RX FIFO
entries, the received buffers and the IN status.  Host packets are NRZI
encoded, bit-stuffed and CRC'd HERE and stored as a J/K/SE0 symbol ROM; the
host holds each symbol for 4 clk_i cycles (usbdev's 48 MHz = 4x 12 Mbps).

Usage: gen_usbdev_selftest.py  (writes the wrapper next to the others)
"""
import os
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, 'wrappers', 'flat_usbdev_selftest.sv')

J, K, SE0 = 0, 1, 2

def bits_of(byte, n=8):
    return [(byte >> i) & 1 for i in range(n)]          # LSB first

def crc5(bits):
    crc = 0x1F
    for b in bits:
        fb = ((crc >> 4) & 1) ^ b
        crc = ((crc << 1) & 0x1F) ^ (0x05 if fb else 0)
    crc ^= 0x1F
    return [(crc >> (4 - i)) & 1 for i in range(5)]      # register MSB first

def crc16(bits):
    crc = 0xFFFF
    for b in bits:
        fb = ((crc >> 15) & 1) ^ b
        crc = ((crc << 1) & 0xFFFF) ^ (0x8005 if fb else 0)
    crc ^= 0xFFFF
    return [(crc >> (15 - i)) & 1 for i in range(16)]

def pid_bits(pid):
    return bits_of(pid | ((~pid & 0xF) << 4))

def token(pid, addr, ep):
    f = bits_of(addr, 7) + bits_of(ep, 4)
    return pid_bits(pid) + f + crc5(f)

def data(pid, payload):
    d = [b for byte in payload for b in bits_of(byte)]
    return pid_bits(pid) + d + crc16(d)

def handshake(pid):
    return pid_bits(pid)

def line(bits):
    """SYNC + bit-stuffed NRZI + EOP -> list of symbols."""
    stream = bits_of(0x80)                               # SYNC 00000001 (LSB first)
    ones = 0
    out = []
    for i, b in enumerate(stream + bits):
        out.append(b)
        if i >= 8:                                       # stuff only after SYNC
            ones = ones + 1 if b else 0
            if ones == 6:
                out.append(0); ones = 0
        elif b:
            ones = 1
        else:
            ones = 0
    sym, cur = [], J
    for b in out:
        if b == 0:
            cur = K if cur == J else J
        sym.append(cur)
    return sym + [SE0, SE0, J]

# Self-checks against well-known packets.
assert crc5(bits_of(0, 7) + bits_of(0, 4)) == [0, 1, 0, 0, 0]   # SETUP 0.0 -> CRC5 field 0x02
assert crc16([]) == [0] * 16                                      # zero-length DATA -> 0x0000

PID = dict(OUT=0x1, IN=0x9, SETUP=0xD, DATA0=0x3, DATA1=0xB, ACK=0x2)
REG = dict(INTR_STATE=0x0, INTR_ENABLE=0x4, USBCTRL=0x10, EP_OUT_ENABLE=0x14, EP_IN_ENABLE=0x18,
           USBSTAT=0x1c, AVOUTBUFFER=0x20, AVSETUPBUFFER=0x24, RXFIFO=0x28,
           RXENABLE_SETUP=0x2c, RXENABLE_OUT=0x30, IN_SENT=0x38,
           CONFIGIN_0=0x44, COUNT_ERRORS=0xa8, BUFFER=0x800)
BUF = lambda b, w=0: REG['BUFFER'] + b * 64 + 4 * w

OP_DONE, OP_W, OP_R, OP_BUS, OP_IDLE, OP_SE0, OP_WAITTX = range(7)
prog, syms = [], []
def W(a, d): prog.append((OP_W, a, d))
def R(a):    prog.append((OP_R, a, 0))
def IDLE(n): prog.append((OP_IDLE, n, 0))
def SE0R(n): prog.append((OP_SE0, n, 0))
def WAITTX(n): prog.append((OP_WAITTX, n, 0))
def BUS(bits):
    s = line(bits); prog.append((OP_BUS, len(syms), len(s))); syms.extend(s)

IDLE(40)
W(REG['USBCTRL'], 0x1)                       # enable: pull-up on
IDLE(200)                                    # sense filter + link Powered
SE0R(400); IDLE(100)                         # bus reset -> LinkActiveNoSOF
W(BUF(0, 0), 0x44332211); W(BUF(0, 1), 0x88776655)
R(BUF(0, 0)); R(BUF(0, 1))                   # packet buffer through the SRAM window
W(REG['AVSETUPBUFFER'], 1)
W(REG['AVOUTBUFFER'], 2); W(REG['AVOUTBUFFER'], 3)
W(REG['EP_OUT_ENABLE'], 1); W(REG['EP_IN_ENABLE'], 1)
W(REG['RXENABLE_SETUP'], 1); W(REG['RXENABLE_OUT'], 1)
W(REG['INTR_ENABLE'], 0x1FFFF)            # interrupt outputs follow intr_state
IDLE(40)
BUS(token(PID['SETUP'], 0, 0)); IDLE(12)
BUS(data(PID['DATA0'], [0x80, 0x06, 0x00, 0x01, 0x00, 0x00, 0x40, 0x00]))
WAITTX(400); IDLE(60)
# Arm IN ep0 AFTER the SETUP: a SETUP cancels a pending IN on that endpoint
# (configin.pend), and the IN token would only be NAKed.
W(REG['CONFIGIN_0'], (1 << 31) | (5 << 8) | 0)   # buffer 0, 5 bytes, rdy
IDLE(20)
BUS(token(PID['IN'], 0, 0))
WAITTX(600); IDLE(8)
BUS(handshake(PID['ACK'])); IDLE(80)
BUS(token(PID['OUT'], 0, 0)); IDLE(12)
BUS(data(PID['DATA1'], [0xA1, 0xB2, 0xC3]))
WAITTX(400); IDLE(80)
R(REG['INTR_STATE']); R(REG['USBSTAT']); R(REG['IN_SENT']); R(REG['CONFIGIN_0'])
R(REG['RXFIFO']); R(REG['RXFIFO'])
R(BUF(1, 0)); R(BUF(1, 1)); R(BUF(2, 0)); R(REG['COUNT_ERRORS'])
W(REG['INTR_STATE'], 0x1FFFF)                # clear (W1C): interrupt outputs fall
R(REG['INTR_STATE'])
prog.append((OP_DONE, 0, 0))

NP, NS = len(prog), len(syms)
ops  = ''.join(f'{op:01x}' for op, _, _ in reversed(prog))
a1   = ''.join(f'{a:08x}' for _, a, _ in reversed(prog))
a2   = ''.join(f'{d:08x}' for _, _, d in reversed(prog))
sbin = ''.join(f'{s:02b}' for s in reversed(syms))
PW   = max(1, (NP - 1).bit_length())
SW   = max(1, (NS - 1).bit_length())

sv = f"""// GENERATED by scripts/gen_usbdev_selftest.py -- do not edit.
// Self-driving usbdev test top (see the generator's docstring): a TL-UL
// master and a USB full-speed host model run {NP} program steps over
// {NS} host line symbols (4 clk_i cycles each).
module usbdev_selftest_flat (
  input  logic        clk_i,
  input  logic        rst_ni,
  output logic [31:0] rdata_o,      // last TL read
  output logic [31:0] rd_sig_o,     // rolling signature of every TL read
  output logic [7:0]  step_o,
  output logic        done_o,
  output logic        tl_err_o,     // sticky d_error
  output logic        usb_dp_o,     // bus as seen by the device (host or device driving)
  output logic        usb_dn_o,
  output logic        dev_oe_o,
  output logic        pullup_o,
  output logic [18:0] intr_o,
  output logic [15:0] tx_edges_o    // device transmit transitions seen
);
  import tlul_pkg::*;

  localparam int NP = {NP};
  localparam int NS = {NS};
  localparam logic [4*NP-1:0]  OPS  = {4*NP}'h{ops};
  localparam logic [32*NP-1:0] ARG1 = {32*NP}'h{a1};
  localparam logic [32*NP-1:0] ARG2 = {32*NP}'h{a2};
  localparam logic [2*NS-1:0]  SYMS = {2*NS}'b{sbin};

  tl_h2d_t h2d, h2d_intg;
  tl_d2h_t d2h;
  prim_alert_pkg::alert_rx_t [0:0] alert_rx;
  prim_alert_pkg::alert_tx_t [0:0] alert_tx;
  assign alert_rx[0].ping_p = 1'b0;
  assign alert_rx[0].ping_n = 1'b1;
  assign alert_rx[0].ack_p  = 1'b0;
  assign alert_rx[0].ack_n  = 1'b1;

  tlul_cmd_intg_gen #(.EnableDataIntgGen(1'b1)) u_intg (
    .tl_i (h2d),
    .tl_o (h2d_intg)
  );

  logic host_dp, host_dn;
  logic dev_dp, dev_dn, dev_dp_en, dev_dn_en;
  logic bus_dp, bus_dn;
  assign bus_dp = dev_dp_en ? dev_dp : host_dp;
  assign bus_dn = dev_dn_en ? dev_dn : host_dn;

  usbdev u_dut (
    .clk_i                        (clk_i),
    .rst_ni                       (rst_ni),
    .clk_aon_i                    (clk_i),
    .rst_aon_ni                   (rst_ni),
    .tl_i                         (h2d_intg),
    .tl_o                         (d2h),
    .alert_rx_i                   (alert_rx),
    .alert_tx_o                   (alert_tx),
    .cio_usb_dp_i                 (bus_dp),
    .cio_usb_dn_i                 (bus_dn),
    .usb_rx_d_i                   (bus_dp),
    .cio_usb_dp_o                 (dev_dp),
    .cio_usb_dp_en_o              (dev_dp_en),
    .cio_usb_dn_o                 (dev_dn),
    .cio_usb_dn_en_o              (dev_dn_en),
    .usb_tx_se0_o                 (),
    .usb_tx_d_o                   (),
    .cio_sense_i                  (1'b1),
    .usb_dp_pullup_o              (pullup_o),
    .usb_dn_pullup_o              (),
    .usb_rx_enable_o              (),
    .usb_tx_use_d_se0_o           (),
    .usb_aon_suspend_req_o        (),
    .usb_aon_wake_ack_o           (),
    .usb_aon_bus_reset_i          (1'b0),
    .usb_aon_sense_lost_i         (1'b0),
    .usb_aon_bus_not_idle_i       (1'b0),
    .usb_aon_wake_detect_active_i (1'b0),
    .usb_ref_val_o                (),
    .usb_ref_pulse_o              (),
    .ram_cfg_i                    ('0),
    .ram_cfg_rsp_o                (),
    .intr_pkt_received_o          (intr_o[0]),
    .intr_pkt_sent_o              (intr_o[1]),
    .intr_powered_o               (intr_o[2]),
    .intr_disconnected_o          (intr_o[3]),
    .intr_host_lost_o             (intr_o[4]),
    .intr_link_reset_o            (intr_o[5]),
    .intr_link_suspend_o          (intr_o[6]),
    .intr_link_resume_o           (intr_o[7]),
    .intr_av_out_empty_o          (intr_o[8]),
    .intr_rx_full_o               (intr_o[9]),
    .intr_av_overflow_o           (intr_o[10]),
    .intr_link_in_err_o           (intr_o[11]),
    .intr_link_out_err_o          (intr_o[12]),
    .intr_rx_crc_err_o            (intr_o[13]),
    .intr_rx_pid_err_o            (intr_o[14]),
    .intr_rx_bitstuff_err_o       (intr_o[15]),
    .intr_frame_o                 (intr_o[16]),
    .intr_av_setup_empty_o        (intr_o[17])
  );
  assign intr_o[18] = alert_tx[0].alert_p;

  // ------------------------------------------------------------ program
  logic [{PW}:0]  pc_q;
  logic [31:0]    cnt_q;
  logic [{SW}:0]  sym_q;
  logic           req_q;      // TL request outstanding (a_valid until accepted)
  logic           seen_tx_q;
  logic [1:0]     cur_sym;
  logic [3:0]     op;
  logic [31:0]    arg1, arg2;
  logic           dev_oe_q;

  assign op   = OPS[4*pc_q +: 4];
  assign arg1 = ARG1[32*pc_q +: 32];
  assign arg2 = ARG2[32*pc_q +: 32];
  assign cur_sym = SYMS[2*(arg1[{SW}:0] + sym_q) +: 2];

  always_comb begin
    h2d           = TL_H2D_DEFAULT;
    h2d.d_ready   = 1'b1;
    h2d.a_size    = 2'h2;
    h2d.a_mask    = 4'hF;
    h2d.a_address = {{20'h0, arg1[11:0]}};
    h2d.a_data    = arg2;
    h2d.a_opcode  = (op == 4'd{OP_R}) ? Get : PutFullData;
    h2d.a_valid   = req_q;
    host_dp = 1'b1;  // J
    host_dn = 1'b0;
    if (op == 4'd{OP_SE0}) begin
      host_dp = 1'b0;
      host_dn = 1'b0;
    end else if (op == 4'd{OP_BUS}) begin
      host_dp = (cur_sym == 2'd{J});
      host_dn = (cur_sym == 2'd{K});
    end
  end

  assign dev_oe_o = dev_dp_en;
  assign usb_dp_o = bus_dp;
  assign usb_dn_o = bus_dn;
  assign step_o   = 8'(pc_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q       <= '0;
      cnt_q      <= '0;
      sym_q      <= '0;
      req_q      <= 1'b0;
      seen_tx_q  <= 1'b0;
      rdata_o    <= '0;
      rd_sig_o   <= 32'h1;
      done_o     <= 1'b0;
      tl_err_o   <= 1'b0;
      dev_oe_q   <= 1'b0;
      tx_edges_o <= '0;
    end else begin
      dev_oe_q <= dev_dp_en;
      if (dev_dp_en && (dev_dp != dev_oe_q)) tx_edges_o <= tx_edges_o + 16'd1;
      if (d2h.d_valid && d2h.d_error) tl_err_o <= 1'b1;
      unique case (op)
        4'd{OP_DONE}: done_o <= 1'b1;
        4'd{OP_W}, 4'd{OP_R}: begin
          if (!req_q && cnt_q == 0) begin
            req_q <= 1'b1;
            cnt_q <= 32'd1;
          end else begin
            if (req_q && d2h.a_ready) req_q <= 1'b0;
            if (d2h.d_valid) begin
              if (op == 4'd{OP_R}) begin
                rdata_o  <= d2h.d_data;
                rd_sig_o <= {{rd_sig_o[30:0], rd_sig_o[31]}} ^ d2h.d_data;
              end
              req_q <= 1'b0;
              cnt_q <= '0;
              pc_q  <= pc_q + 1'b1;
            end
          end
        end
        4'd{OP_BUS}: begin
          if (cnt_q == 32'd3) begin
            cnt_q <= '0;
            if (sym_q + 1'b1 == arg2[{SW}:0]) begin
              sym_q <= '0;
              pc_q  <= pc_q + 1'b1;
            end else begin
              sym_q <= sym_q + 1'b1;
            end
          end else begin
            cnt_q <= cnt_q + 32'd1;
          end
        end
        4'd{OP_IDLE}, 4'd{OP_SE0}: begin
          if (cnt_q + 32'd1 >= arg1) begin
            cnt_q <= '0;
            pc_q  <= pc_q + 1'b1;
          end else begin
            cnt_q <= cnt_q + 32'd1;
          end
        end
        4'd{OP_WAITTX}: begin
          if (dev_dp_en) seen_tx_q <= 1'b1;
          if ((seen_tx_q && !dev_dp_en) || cnt_q + 32'd1 >= arg1) begin
            cnt_q     <= '0;
            seen_tx_q <= 1'b0;
            pc_q      <= pc_q + 1'b1;
          end else begin
            cnt_q <= cnt_q + 32'd1;
          end
        end
        default: ;
      endcase
    end
  end
endmodule
"""
open(OUT, 'w').write(sv)
print(f'wrote {OUT}: {NP} steps, {NS} symbols')
