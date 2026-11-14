// MikePopoloski/slang#813 (closed): [feature] Allow union to struct assignments with matching formats for -Wimplicit-conv
// https://github.com/MikePopoloski/slang/issues/813
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
typedef struct packed {
    logic a;
    logic [1:0] b;
    logic c;
} s1_t;

typedef struct packed {
    logic a;
    logic [1:0] b;
    logic c;
} s2_t;

typedef struct packed {
    logic a;
    logic [1:0] b;
    logic c;
} s3_t;

typedef union packed {
    s2_t s2;
    s3_t s3;
} s4_t;

module top;
    s1_t s1a, s1b;
    s2_t s2;
    s4_t s4;

    always_comb begin
        s1a = s2;
        s1b = s4;
    end
endmodule

