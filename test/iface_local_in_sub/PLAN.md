# SystemVerilog Interface Support — Multi-PR Plan

Tracker for the work needed to make `yosys/tests/svinterfaces/svinterface1.sv`
pass through the UHDM frontend. The upstream test exercises four distinct
interface features that our frontend handles incompletely. Each is being
fixed in its own PR with a minimal local repro.

## Issue 1: Local interface instances inside non-top modules — ✅ DONE

**Symptom**: `MyInterface intf();` declared inside a non-top module
produces a bare 1-bit `\intf` wire instead of the per-field
`\intf.field` wires. Downstream `assign intf.field = ...` then drives
a non-existent signal and is silently dropped.

**Root cause**: Surelog's `AllModules` form stores local interface
instances as plain `logic_net` placeholders — `Interfaces()` is empty.
Only the elaborated `TopModules` descendant carries the real
`interface_inst`.

**Fix**: `interface.cpp` — when AllModules' `Interfaces()` is empty,
walk `TopModules` to find any elaborated instance of the same module
def with a non-empty `Interfaces()`, and use that as the source.

**Repro**: this directory (`test/iface_local_in_sub/`).

## Issue 2: Cell-side connections to interface-typed ports — ✅ DONE

**Symptom**: For `Sub u_sub(.iface_port(local_iface))`, the cell
emits `connect \iface_port \local_iface` (single bare wires) but the
target module has flattened ports `\iface_port.field`. Yosys hierarchy
fails: "does not have a port named 'iface_port'".

**Root cause**: `import_module_hierarchy`'s cell-creation path
(uhdm2rtlil.cpp ~line 852) imports `high_conn` as a plain expression.
For a `ref_obj` that references an interface (port or local), the
referenced wire doesn't exist as a bare `\<name>` — only as
`\<name>.<field>` flattened wires.  `import_expression` returns
empty, `cell->setPort(port_name, empty)` drops the connection, and
the cell ends up with no port connections at all.

**Fix**: detect interface-typed instance ports by checking the
target module for `<port_name>.<field>` wires, then iterate fields
and pair each `<port_name>.<field>` ↔ `<src_name>.<field>` (source
name from the high_conn ref_obj's `VpiName`).

**Repro**: `test/iface_passthrough/` — `top → mid → leaf` where
`mid` forwards its received `bus` interface port into `leaf` (the
"inherited interface" pattern svinterface1 uses).

## Issue 3: Per-instance parameterised interface widths — ✅ DONE

**Symptom**: A submodule receives a parameterised interface port
whose `WIDTH` was overridden at the parent (e.g. `bus_if #(.W(22))`).
The submodule's `\bus.field` wire still has the *default* width from
the interface declaration, so the hierarchy pass sees a width
mismatch and the design breaks.

**Root cause**: `import_port` reads the modport / interface_inst via
the AllModules port's `Low_conn->Actual_group()` — that's the
unelaborated interface with default parameter values.  When
`compute_signal_width` runs ExprEval against this scope, `W` resolves
to the default.

**Fix**: when processing an interface port, find a matching
elaborated instance of the current module via the `TopModules`
walk; look up the same-named port on it; replace `mp` / `iface_inst`
with the elaborated port's `High_conn` modport / interface_inst.
`High_conn` (not `Low_conn`) carries the *parent's* local interface
instance — which is where the parameter override (`param_assign`
with `vpiOverriden:1`) lives.

**Limitation**: this picks the first elaborated instance found.
Modules instantiated multiple times with different parameter
overrides would need real `$paramod` variants (Yosys's approach);
svinterface1.sv has single instances so this suffices for now.

**Repro**: `test/iface_param_width_per_inst/` — `top` instantiates
`sub` passing `my_iface #(.W(22)) bus()`; without the fix
`sub`'s `bus.data` is width 3 (default `W`) instead of 22.

## Issue 4: hier_path LHS on interface fields with part-selects — PENDING

**Symptom**: `intf.field[hi:lo] = expr` inside `always_comb` lowers
to `assign $0\intf 1'0` — drops the field name AND the part-select,
producing a degenerate 1-bit write to the wrong wire.

**Root cause**: the LHS hier_path resolution path in process.cpp /
expression.cpp doesn't handle the
`[ref_obj(intf), <field>, part_select]` pattern when `intf` is an
interface-typed port wire.

**Fix plan**: extend the hier_path LHS handler to follow `intf` →
flattened field wire `\intf.field` → apply the part-select to that
field wire.

**Repro to write**: `test/iface_field_partsel_lhs/dut.sv` — write to
`intf.array_field[idx:0]` inside an `always_comb`, read back via a
top-level output.

## Status

| PR | Issue | Status |
|----|-------|--------|
| 1 | Local interface instances in non-top modules | merged |
| 2 | Cell-side per-field connections | merged |
| 3 | Per-instance parameterised interface widths | this PR (`iface_param_width_per_inst`) |
| 4 | hier_path LHS on interface fields | pending |

Once all four land, copy
`third_party/yosys/tests/svinterfaces/svinterface1.sv` into
`test/svinterface1/` and confirm formal equivalence passes
end-to-end.
