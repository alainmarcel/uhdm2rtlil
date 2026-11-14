// MikePopoloski/slang#744 (closed): Warnings for unused ports when type is inout
// https://github.com/MikePopoloski/slang/issues/744
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module pad(
    input en,
    input val,
    inout sig
);
    assign sig = en ? val : 1'bz;
endmodule

module i2c(
    inout wire scl,
    input scl_en,
    input scl_drive
);
    wire scl_local;

    pullup (scl_local);
    tranif1(scl, scl_local, 1'b1);

    pad pad_scl(
        .en (scl_en),
        .val (scl_drive),
        .sig (scl_local)
    );
endmodule

module top;
    wire scl;
    logic scl_en1, scl_en2;
    logic scl_drive1, scl_drive2;

    initial begin
        scl_en1 = 1'b0;
        scl_drive1 = '1;
        scl_en2 = 1'b0;
        scl_drive2 = '1;
        #100ns;
        scl_en1 = 1'b1;
        scl_drive1 = 1'b0;
        #50ns;
        scl_en2 = 1'b1;
        scl_drive2 = 1'b0;
    end

    i2c master1(
        .scl_en    (scl_en1),
        .scl_drive (scl_drive1),
        .*
    );
    i2c master2(
        .scl_en    (scl_en2),
        .scl_drive (scl_drive2),
        .*
    );
endmodule

