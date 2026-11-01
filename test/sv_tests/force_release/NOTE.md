NOT SYNTHESIZABLE -- classified, not converted.

Class: force / release
`force` and `release` override a signal's drivers from outside its own hierarchy
for part of a simulation.  Synthesis has no construct for that: a netlist's
drivers are fixed at elaboration.

Upstream evidence:

        force u_flop.q = 0;
      else if (f1)
        force u_flop.q = 1;
