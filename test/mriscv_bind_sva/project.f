# Multi-file SystemVerilog project — reproduces synlig#2246.
# A RISC-V core (mriscvcore) bound to an SVA wrapper (jg_bind_wrapper)
# via the `bind` construct, then both copies of the core wrapped under
# `mriscvcore_top_s2qed` for S2QED-style formal checking.

# top: mriscvcore_top_s2qed
# mode: uhdm-only
# surelog: -nobuiltin

./ALU/ALU.v
./DECO_INSTR/DECO_INSTR.v
./FSM/FSM.v
./IRQ/IRQ.v
./MEMORY_INTERFACE/MEMORY_INTERFACE.v
./MULT/MULT.v
./REG_FILE/REG_FILE.v
./UTILITIES/UTILITY.v
./mriscvcore.v
./rv32_opcodes.v
./jg_bind_wrapper.sv
./mriscvcore_top_s2qed.v
