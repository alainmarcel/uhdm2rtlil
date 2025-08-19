#!/bin/bash
export YOSYS_ENABLE_UHDM_DEBUG=1
/home/alain/uhdm2rtlil/out/current/bin/yosys -p "plugin -i /home/alain/uhdm2rtlil/build/uhdm2rtlil.so; read_uhdm slpp_all/surelog.uhdm" | grep -A10 -B10 "edge"