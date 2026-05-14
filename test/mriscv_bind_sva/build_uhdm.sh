#!/usr/bin/env bash
# Surelog command — same -formal flag and file order as the synlig
# .ys in chipsalliance/synlig#2246.
set -e
cd "$(dirname "$0")"

SURELOG=/home/alain/uhdm2rtlil/build/third_party/Surelog/bin/surelog

rm -rf slpp_all
$SURELOG -parse -nobuiltin \
    ./ALU/ALU.v \
    ./DECO_INSTR/DECO_INSTR.v \
    ./FSM/FSM.v \
    ./IRQ/IRQ.v \
    ./MEMORY_INTERFACE/MEMORY_INTERFACE.v \
    ./MULT/MULT.v \
    ./REG_FILE/REG_FILE.v \
    ./UTILITIES/UTILITY.v \
    ./mriscvcore.v \
    ./rv32_opcodes.v \
    ./jg_bind_wrapper.sv \
    ./mriscvcore_top_s2qed.v
