NOT SYNTHESIZABLE -- classified, not converted.

Class: forever + disable
The loop is `forever begin : loop disable loop; end` -- an unbounded loop whose
only statement DISABLES the named block it is in.  Neither half has a netlist
form: an unbounded loop cannot be unrolled, and `disable` is a simulation-time
control transfer.

Upstream evidence:

          forever begin : loop
    	 disable loop;
          end
