NOT SYNTHESIZABLE -- classified, not converted.

Class: file I/O
File and string-formatting system tasks are simulation services.

Upstream evidence:
    	int fd;
    	fd = $fopen("tmp.txt", "w");
    	$display(":assert: (%d == 0)", $ftell(fd));

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
