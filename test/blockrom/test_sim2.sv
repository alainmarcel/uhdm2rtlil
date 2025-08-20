module test_sim2;
    integer j;
    
    initial begin
        j = 64'hF4B1CA8127865242;
        $display("j after assignment = 0x%08x", j);
        $finish;
    end
endmodule