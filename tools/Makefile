# vcd-inspect: indexed VCD inspector used by the co-sim internal-probe flow
# (test/netlist_cosim.py --probe, test/probe_diff.py, test/probe_signal.py).
#
#   make -C tools            # -> tools/vcd-inspect
#   make -C tools clean
#
# -march=native is deliberately NOT used: the binary is committed-source but
# built per machine, and native breaks a shared build directory across hosts.
CXX      ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wno-unused-function
LDFLAGS  ?=

all: vcd-inspect

vcd-inspect: vcd_mcp.cpp
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f vcd-inspect

.PHONY: all clean
