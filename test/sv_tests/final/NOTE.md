NOT SYNTHESIZABLE -- classified, not converted.

Class: final block
A `final` block runs once when SIMULATION ENDS.  There is no corresponding point
in hardware, so nothing a netlist contains can show that it ran.

Upstream evidence:

    	final
    		a = 1;
