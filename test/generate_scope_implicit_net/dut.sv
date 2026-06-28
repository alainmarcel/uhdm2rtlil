// Issue #437: an implicit wire from a module-level continuous assign
// (INTERNAL1) read inside an always block in a nested generate scope must
// resolve to the PARENT net, not a disconnected gen-scope-local net.
module dut #(parameter Q_RESET_VAL = 0) (
    output reg Q,
    input D, CP, RN, TI, TE
);
    assign INTERNAL1 = TE ? TI : D;   // implicit/deferred wire in parent scope

    generate if (Q_RESET_VAL == 0) begin : sync_flipflop_low_reset_gen
        always @(posedge CP or negedge RN) begin
            if (RN == 1'b0)  Q <= 1'b0;
            else             Q <= INTERNAL1;   // read parent's implicit wire
        end
    end endgenerate
endmodule
