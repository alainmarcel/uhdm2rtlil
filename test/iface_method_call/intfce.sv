interface intf1;
    logic sum, c_out;
    logic a, b;
    function summ2(input a, b);
        sum   = a ^ b;
        c_out = a & b;
    endfunction
endinterface

interface intf2;
    logic sum, c_out;
    logic a, b, cin;
    function summ3(input a, b);
        sum   = a ^ b ^ cin;
        c_out = (a & b) | (a & cin) | (b & cin);
    endfunction
endinterface
