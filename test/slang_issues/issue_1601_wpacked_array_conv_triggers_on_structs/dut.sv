// MikePopoloski/slang#1601 (closed): -Wpacked-array-conv triggers on structs defined with [0:0]
// https://github.com/MikePopoloski/slang/issues/1601
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module testA (__i_data_in, __o_data_out);

    typedef struct packed {
        logic a;
        logic b;
    } data_t;

    data_t data_in, data_out;

    testB #(
         .data_t(data_t),
         .Width(1)
    ) i_testB (
        .data_i(data_in),
        .data_o(data_out)
    );


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [1:0] __i_data_in;
  assign data_in = data_t'(__i_data_in);
  output logic [1:0] __o_data_out;
  assign __o_data_out = data_out;
endmodule

module testB #(
    parameter type data_t = logic,
    parameter int unsigned Width = 1
) (
    input data_t [Width-1:0] data_i,
    output data_t [Width-1:0] data_o
);

    assign data_o = data_i;

endmodule

