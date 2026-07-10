// Minimal repro of tcb_lite_lib_decoder's `encode` one-hot->binary function:
// a for loop inside a function whose bound is a parameter, with a bit-select
// of the loop variable (i[IFL-1:0]) and of the argument (val[i]).
module func_forloop_onehot #(
    parameter int unsigned IFN = 4,          // number of interfaces (one-hot width)
    parameter int unsigned IFL = 2           // log2(IFN) (binary width)
) (
    input  logic [IFN-1:0] val,
    output logic [IFL-1:0] sel
);
    function logic [IFL-1:0] encode (logic [IFN-1:0] v);
        encode = '0;
        for (int i=0; i<IFN; i++) begin
            encode |= v[i] ? i[IFL-1:0] : '0;
        end
    endfunction

    assign sel = encode(val);
endmodule
