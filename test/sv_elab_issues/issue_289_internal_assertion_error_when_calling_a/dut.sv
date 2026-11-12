// povik/sv-elab#289 (closed): Internal assertion error when calling a parameterized function with different parameters and an argument
// https://github.com/povik/sv-elab/issues/289
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
virtual class Cls #(parameter type type_t);
    static function func (
        input num
    );
        return 0;
    endfunction
endclass

module test
(
    output bit a,
    output logic b
);
    assign a = Cls#(bit)::func(0);
    assign b = Cls#(logic)::func(0);
endmodule

