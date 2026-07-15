// Minimal repro of tcb_lite_lib_logsize2byteena read-data byte-remux.
// With rsp_off==0 the remux must be identity: sub_rdt === man_rdt.
module read_remux #(
    parameter int unsigned BYT = 4,
    parameter int unsigned OFF = 2
)(
    input  logic [BYT-1:0][8-1:0] man_rdt,
    input  logic [OFF-1:0]        rsp_off,
    output logic [BYT-1:0][8-1:0] sub_rdt
);
    // prefix OR (same as the TCB lib helper)
    function automatic [OFF-1:0] prefix_or (input logic [OFF-1:0] val);
        prefix_or[OFF-1] = val[OFF-1];
        for (int unsigned i=OFF-1; i>0; i--) begin
            prefix_or[i-1] = prefix_or[i] | val[i-1];
        end
    endfunction: prefix_or

    for (genvar i=0; i<BYT; i++) begin
        assign sub_rdt[i] = man_rdt[(~prefix_or(i[OFF-1:0]) & rsp_off) | i[OFF-1:0]];
    end
endmodule
