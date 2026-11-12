// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r26); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r26
// issue 259 another bug in order_symbols_within_scope 
typedef struct packed {
    logic                       valid;
  } r26_s_flit_req_t;

typedef struct packed {
    logic                       ready;
  } r26_s_flit_resp_t;

interface r26_router_if;
   r26_s_flit_req_t  req;
   r26_s_flit_resp_t resp;

  modport send_flit (
    output  req,
    input   resp
  );

  modport recv_flit (
    input   req,
    output  resp
  );

endinterface // router_if
module r26();
   r26_router_if ns_con [2] ();
   r26_router_if sn_con [2] ();
   localparam int NorthIdx = 0;
   r26_router u_router (
        .north_send     (ns_con[NorthIdx]),
        .north_recv     (sn_con[NorthIdx])
      );
endmodule // raven

module r26_router
  (
  r26_router_if.send_flit   north_send,
  r26_router_if.recv_flit   north_recv
);
  r26_s_flit_resp_t       [4:0] ext_resp_v_o;
  r26_s_flit_req_t        [4:0] ext_req_v_o;
  always_comb begin : mapping_input_ports
    north_recv.resp = ext_resp_v_o[0];
    north_send.req = ext_req_v_o[0];
  end
endmodule

