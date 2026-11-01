NOT SYNTHESIZABLE -- classified, not converted.

Class: do-while loop
A `do ... while` loop body is not supported by ANY of the three frontends, so a
converted test would fail on all of them rather than on ours.  Measured
2026-10-31 on a version with the strings replaced by ints and the loop driving
real outputs:

    read_verilog : dut.sv:13: ERROR: syntax error, unexpected TOK_BEGIN
    read_slang   : dut.sv:13: ERROR: unsupported language feature
    read_uhdm    : Warning: Unsupported statement type in comb context: 670
                   (the loop is DROPPED; the outputs then prove nothing)

Upstream evidence:

    		do begin
    			$display(i, test[i]);
    			i++;
    		end while(test[i] != "222");

read_uhdm is the only one of the three that accepts the file and then silently
drops the statement, which is worth fixing on its own; recorded here rather than
converted, because until it IS fixed there is no frontend to compare against.
If `do ... while` gains support, re-triage by grepping NOTE.md for this class.
