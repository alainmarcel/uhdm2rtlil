// Half-adder wrapper that calls the interface's summ2 method.
// The function writes to `ha_intf.sum` / `ha_intf.c_out`; we surface
// those onto the module's `sum` / `cout` outputs so co-sim can compare.
module ha_itf (intf1 ha_intf, output sum, cout, input a, b);

    always @(*) begin
        ha_intf.summ2(a, b);
    end

    assign sum  = ha_intf.sum;
    assign cout = ha_intf.c_out;

endmodule
