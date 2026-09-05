// Flat-port shim (see flat_ibex_alu.sv): every ibex_pmp port is an
// unpacked array (cfg/addr per region, per-channel request/grant); direct
// miters feed the same flat bits into opposite element orders between the
// frontends.  Generate-loop part-select mapping pins element 0 at the LSBs
// for both sides.
module ibex_pmp_flat import ibex_pkg::*; #(
  parameter int unsigned DmBaseAddr     = 32'h1A110000,
  parameter int unsigned DmAddrMask     = 32'h00000FFF,
  parameter int unsigned PMPGranularity = 0,
  parameter int unsigned PMPNumChan     = 2,
  parameter int unsigned PMPNumRegions  = 4
) (
  input  logic [PMPNumRegions*6-1:0]                csr_pmp_cfg_flat_i,
  input  logic [PMPNumRegions*(PMP_ADDR_MSB+1)-1:0] csr_pmp_addr_flat_i,
  input  ibex_pkg::pmp_mseccfg_t                    csr_pmp_mseccfg_i,
  input  logic                                      debug_mode_i,

  input  logic [PMPNumChan*2-1:0]                   priv_mode_flat_i,
  input  logic [PMPNumChan*(PMP_ADDR_MSB+1)-1:0]    pmp_req_addr_flat_i,
  input  logic [PMPNumChan*2-1:0]                   pmp_req_type_flat_i,
  output logic [PMPNumChan-1:0]                     pmp_req_err_flat_o
);
  ibex_pkg::pmp_cfg_t     csr_pmp_cfg    [PMPNumRegions];
  logic [PMP_ADDR_MSB:0]  csr_pmp_addr   [PMPNumRegions];
  ibex_pkg::priv_lvl_e    priv_mode      [PMPNumChan];
  logic [PMP_ADDR_MSB:0]  pmp_req_addr   [PMPNumChan];
  ibex_pkg::pmp_req_e     pmp_req_type   [PMPNumChan];
  logic                   pmp_req_err    [PMPNumChan];

  for (genvar r = 0; r < PMPNumRegions; r++) begin : gen_regions
    assign csr_pmp_cfg[r]  = pmp_cfg_t'(csr_pmp_cfg_flat_i[r*6 +: 6]);
    assign csr_pmp_addr[r] = csr_pmp_addr_flat_i[r*(PMP_ADDR_MSB+1) +: PMP_ADDR_MSB+1];
  end
  for (genvar c = 0; c < PMPNumChan; c++) begin : gen_chan
    assign priv_mode[c]    = priv_lvl_e'(priv_mode_flat_i[c*2 +: 2]);
    assign pmp_req_addr[c] = pmp_req_addr_flat_i[c*(PMP_ADDR_MSB+1) +: PMP_ADDR_MSB+1];
    assign pmp_req_type[c] = pmp_req_e'(pmp_req_type_flat_i[c*2 +: 2]);
    assign pmp_req_err_flat_o[c] = pmp_req_err[c];
  end

  ibex_pmp #(
    .DmBaseAddr     (DmBaseAddr),
    .DmAddrMask     (DmAddrMask),
    .PMPGranularity (PMPGranularity),
    .PMPNumChan     (PMPNumChan),
    .PMPNumRegions  (PMPNumRegions)
  ) u_pmp (
    .csr_pmp_cfg_i     (csr_pmp_cfg),
    .csr_pmp_addr_i    (csr_pmp_addr),
    .csr_pmp_mseccfg_i (csr_pmp_mseccfg_i),
    .debug_mode_i      (debug_mode_i),
    .priv_mode_i       (priv_mode),
    .pmp_req_addr_i    (pmp_req_addr),
    .pmp_req_type_i    (pmp_req_type),
    .pmp_req_err_o     (pmp_req_err)
  );
endmodule
