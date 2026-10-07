# A $unit enum constant referenced from a file other than the declaring one.
# top.sv must come FIRST: it is the file whose file-scope typedef declares the
# enum, exactly as in scr1 (scr1_pipe_exu.sv's include wins and
# scr1_pipe_lsu.sv's guarded include is a no-op).
# top: unit_enum_const_child_ref

top.sv
child.sv
