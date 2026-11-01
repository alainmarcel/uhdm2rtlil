NOT SYNTHESIZABLE -- classified, not converted.

Class: dynamic array / queue
The typedef is an ASSOCIATIVE ARRAY: its index position holds a TYPE
(`[bit[31:0]]`, or a pair of packed types), not a range, so the array is
unbounded at elaboration time and has no netlist form.  The classifier's pattern
catches the simple index types (`[int]`, `[string]`, ...); a packed-vector index
type is the same construct spelled longer.
