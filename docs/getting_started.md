# Getting started

Prerequisites, build, and the two commands the plugin adds to Yosys.  Back to
the [README](../README.md).


**Version.** The project version tracks the Yosys release it is built against — `project(uhdm2rtlil VERSION 0.70)` for Yosys 0.70.  A plugin is only ever loaded by the Yosys it was compiled for, so a single number names the pairing.

## Prerequisites
- GCC ≥ 11 (C++20; the bundled Yosys v0.70 and its built-in `read_slang` frontend require it)
- CMake **3.28 – 3.31** (≥ 3.28 for the bundled slang library; CMake 4.x is rejected by
  Surelog/UHDM's capnproto — `pip install 'cmake==3.31.6'` on ubuntu-22.04)
- Python 3.8+
- Standard development tools (make, bison, flex)
- Verilator (used by `test/test_sim_equivalence.py` to co-simulate
  the original SV against the UHDM-derived netlist for tests where
  the Yosys Verilog frontend can't parse the source — see
  [Verilator-based simulation equivalence](testing.md#verilator-based-simulation-equivalence-check))

On Debian / Ubuntu:
```bash
sudo apt-get install -y \
    build-essential cmake git python3 python3-pip pkg-config \
    libssl-dev zlib1g-dev libtcmalloc-minimal4 uuid-dev tcl-dev \
    libffi-dev libreadline-dev bison flex libfl-dev libunwind-dev \
    libgoogle-perftools-dev ccache help2man
```

`test/test_sim_equivalence.py` needs **Verilator 5.x** (5.020+) for SVA
parsing.  Ubuntu 24.04's stock `verilator` package is recent enough;
on older distros (22.04 ships 4.038) build from source:

```bash
git clone --depth=1 -b v5.048 https://github.com/verilator/verilator.git
cd verilator
autoconf
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
verilator --version  # confirm: "Verilator 5.048 ..."
```

## Build
```bash
# Clone with submodules
git clone --recursive https://github.com/alainmarcel/uhdm2rtlil.git
cd uhdm2rtlil

# Configure git hooks (prevents committing files >10MB)
git config core.hooksPath .githooks

# Build everything (Surelog, Yosys, UHDM Frontend)
make
```

## Basic usage

The plugin (`build/uhdm2rtlil.so` after `make`; every command below runs from the repository root) registers two Yosys commands for getting
SystemVerilog into RTLIL:

| Command | Input | Surelog run | Intermediate `.uhdm` |
|---------|-------|-------------|----------------------|
| **`read_sv`**   | SystemVerilog source(s) + Surelog flags | in-process | no — fully in-memory |
| **`read_uhdm`** | a pre-generated `.uhdm` file             | separate / earlier | yes |

### `read_sv` — compile SystemVerilog directly (recommended)

Runs the Surelog compiler **in-process** and imports the elaborated in-memory
UHDM design straight to RTLIL, without writing or re-reading a `.uhdm` file.
All arguments are forwarded to Surelog verbatim, exactly as if it were the
`surelog` executable:

```bash
./out/current/bin/yosys -m build/uhdm2rtlil.so \
  -p "read_sv -parse -nobuiltin design.sv; synth -top top_module"

# Multi-file / flags work just like the surelog CLI:
#   read_sv -parse -nobuiltin a.sv b.sv +incdir+inc -DWIDTH=8 -top mytop
```

`read_sv` forces parse + elaborate + in-memory UHDM elaboration on and `.uhdm`
file writing off.  Pass any Surelog flag as usual; `-nobuiltin` is recommended
to skip Surelog's built-in classes.  Plugin-only options (consumed, not passed
to Surelog): `-uhdm_debug`, `-formal`, `-keep_names`, `-allow-undefined-modules`.

### `read_uhdm` — read a pre-generated UHDM file

Useful when the UHDM database was produced by a separate Surelog run (e.g. the
test workflow, or for caching/debugging the `.uhdm`):

```bash
# Step 1: Generate UHDM from SystemVerilog
./build/third_party/Surelog/bin/surelog -parse -d uhdm design.sv

# Step 2: Read the UHDM file with the frontend
./out/current/bin/yosys -m build/uhdm2rtlil.so \
  -p "read_uhdm slpp_all/surelog.uhdm; synth -top top_module"
```

Options: `-debug`, `-formal`, `-keep_names`, `-allow-undefined-modules`.  An
instance of a module that has no definition is REFUSED by default, with the
modules named (Surelog only warns and would hand over an empty cell); the flag
keeps such instances as blackbox cells for a design read file by file, which
is what `read_verilog` does.

### Using the test workflow
```bash
cd test
bash test_uhdm_workflow.sh simple_counter
```
