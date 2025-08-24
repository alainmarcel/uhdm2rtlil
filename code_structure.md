# UHDM to RTLIL Code Structure

This document provides a comprehensive overview of the function call hierarchy in the UHDM to RTLIL translation frontend for Yosys.

## Main Entry Point

```
UhdmFrontend::execute() (in uhdm2rtlil.cpp)
│
├── Parse command line arguments
├── Read UHDM file using Serializer
├── Create UhdmImporter instance
└── UhdmImporter::import_design()
    │
    ├── Import all packages
    │   └── import_package() for each package
    │
    ├── Import module hierarchy (first pass)
    │   └── import_module_hierarchy() for all top modules
    │       ├── Create RTLIL module
    │       ├── Import ports
    │       ├── Import parameters
    │       └── Recursively import child modules
    │
    ├── Import module implementations (second pass)
    │   └── import_module() for each module
    │       ├── Import nets and wires
    │       ├── Import memory objects
    │       ├── Import continuous assigns
    │       ├── Import processes
    │       ├── Import instances
    │       ├── Import primitives
    │       └── Import generate scopes
    │
    ├── Create parameterized module variants
    │   └── create_parameterized_modules()
    │
    └── Expand interfaces
        └── expand_interfaces()
```

## Module Import Hierarchy

```
import_module_hierarchy (First Pass - Structure)
├── Create RTLIL::Module
├── Set module attributes (top, src, etc.)
├── Import ports
│   └── import_port()
│       ├── Create RTLIL::Wire for port
│       ├── Set direction (input/output/inout)
│       └── Handle port ranges and arrays
├── Import parameters
│   └── import_parameter()
│       ├── Extract parameter value
│       └── Add to module->parameters
└── Recursively process child modules
    └── import_module_hierarchy() [recursive]

import_module (Second Pass - Implementation)
├── Set current_module context
├── Import nets and variables
│   └── import_net()
│       ├── Create RTLIL::Wire
│       ├── Handle arrays (array_net → memory)
│       └── Set wire attributes
├── Import memory objects
│   └── import_memory_objects()
│       ├── Analyze array usage patterns
│       ├── create_memory_from_array()
│       └── Generate memory access logic
├── Import continuous assigns
│   └── import_continuous_assign()
│       ├── Process LHS/RHS expressions
│       └── Create RTLIL connections
├── Import processes (always blocks)
│   └── import_process() [see Process Import section]
├── Import module instances
│   └── import_instance()
│       ├── Find target module
│       ├── Create RTLIL::Cell
│       ├── Map parameters
│       └── Connect ports
├── Import primitives (gates)
│   ├── import_primitives()
│   │   └── import_gate()
│   └── import_primitive_arrays()
│       └── import_gate_array()
├── Import generate scopes
│   └── import_generate_scopes()
│       └── import_gen_scope()
└── Import interface instances
    └── import_interface_instances()
```

## Process Import Hierarchy

```
import_process (for each process in module->Process())
│
├── Determine process type (vpiAlways, vpiAlwaysFF, vpiAlwaysComb, vpiInitial)
│   ├── Check VpiAlwaysType() method
│   └── Use heuristics if needed (clock/reset detection)
│
├── Create RTLIL::Process with unique name
│
├── import_always_ff (for always_ff blocks)
│   ├── Extract clocking information (UhdmClocking)
│   │   ├── Detect clock edge (posedge/negedge)
│   │   └── Detect reset signal and polarity
│   ├── Create RTLIL::SyncRule for clock edge
│   ├── import_statement_sync (for process statement)
│   │   └── [Statement dispatcher - see below]
│   └── Process pending memory writes
│       ├── Create $memwr$ temporary wires
│       └── Generate memwr statements with priorities
│
├── import_always_comb (for always_comb blocks)
│   ├── Set always_comb attribute
│   └── import_statement_comb (for process statement)
│       └── [Statement dispatcher - see below]
│
├── import_always (for generic always blocks)
│   ├── Detect sensitivity list (UhdmClocking)
│   ├── If sequential (has clock):
│   │   ├── Create sync rule for clock edge
│   │   ├── import_statement_sync
│   │   └── Process pending memory writes
│   └── If combinational:
│       └── import_statement_comb
│
└── import_initial (for initial blocks)
    ├── Create RTLIL::SyncRule with INIT type
    └── import_statement_sync
```

## Statement Import Hierarchy (Synchronous)

```
import_statement_sync(stmt, sync, is_reset)
├── vpiBegin → import_begin_block_sync
│   └── For each statement: import_statement_sync [recursive]
│
├── vpiNamedBegin → import_named_begin_block_sync
│   └── For each statement: import_statement_sync [recursive]
│
├── vpiAssignment → import_assignment_sync
│   ├── Process LHS/RHS expressions
│   ├── Handle memory writes specially
│   │   └── Add to pending_memory_writes vector
│   └── Regular assignments: sync->actions.push_back
│
├── vpiIf → import_if_stmt_sync
│   ├── Evaluate condition expression
│   ├── import_statement_sync (then branch)
│   └── import_statement_sync (else branch if exists)
│
├── vpiIfElse → Special handling
│   ├── Get then/else statements
│   └── import_statement_sync for each
│
├── vpiCase → import_case_stmt_sync
│   ├── Process case condition
│   └── For each case item:
│       ├── Evaluate case expressions
│       └── import_statement_sync
│
└── vpiFor → import_statement_with_loop_vars
    ├── Extract loop variable and bounds
    ├── Unroll loop
    └── For each iteration:
        ├── Substitute loop variable in expressions
        └── import_statement_sync with substitution
```

## Statement Import Hierarchy (Combinational)

```
import_statement_comb(stmt, proc/case_rule)
├── vpiBegin → import_begin_block_comb
│   └── For each statement: import_statement_comb [recursive]
│
├── vpiNamedBegin → import_named_begin_block_comb
│   └── For each statement: import_statement_comb [recursive]
│
├── vpiAssignment → import_assignment_comb
│   ├── Process LHS/RHS expressions
│   └── Create RTLIL::CaseRule with assignment action
│
├── vpiIf → import_if_stmt_comb
│   ├── Create RTLIL::CaseRule for condition
│   ├── import_statement_comb (then branch)
│   └── import_statement_comb (else branch)
│
├── vpiIfElse → import_if_else_comb
│   ├── Similar to vpiIf handling
│   └── Process then/else branches
│
└── vpiCase → import_case_stmt_comb
    ├── Create RTLIL::CaseRule for each case item
    └── import_statement_comb for case statements
```

## Expression Import Hierarchy

```
import_expression(expr)
├── vpiConstant → import_constant
│   ├── Parse constant value (binary, hex, decimal)
│   └── Create RTLIL::Const
│
├── vpiOperation → import_operation
│   ├── Get operation type
│   ├── Process operands recursively
│   └── Create appropriate RTLIL cell:
│       ├── Arithmetic: $add, $sub, $mul, $div, $mod
│       ├── Logical: $and, $or, $not, $xor
│       ├── Comparison: $eq, $ne, $lt, $le, $gt, $ge
│       ├── Shift: $shl, $shr, $sshl, $sshr
│       ├── Reduction: $reduce_and, $reduce_or, $reduce_xor
│       └── Ternary: $mux
│
├── vpiRefObj → import_ref_obj
│   ├── Look up signal in name_map
│   ├── Handle hierarchical references
│   └── Return RTLIL::SigSpec
│
├── vpiPartSelect → import_part_select
│   ├── Get base signal
│   ├── Calculate bit range
│   ├── Handle indexed part select (with loop variables)
│   └── Return slice of signal
│
├── vpiBitSelect → import_bit_select
│   ├── Get base signal
│   ├── Calculate bit index
│   └── Return single bit
│
├── vpiConcatOp → import_concat
│   ├── Process each operand
│   └── Concatenate signals
│
├── vpiHierPath → import_hier_path
│   ├── Traverse hierarchy
│   └── Resolve to final signal
│
└── vpiSysFuncCall → import_sys_func_call
    ├── $clog2 → Calculate ceiling log2
    ├── $bits → Return bit width
    └── Other system functions
```

## Memory Handling

```
Memory Import Flow:
├── analyze_and_generate_memories()
│   ├── Scan for array declarations
│   ├── Analyze access patterns
│   └── Decide memory vs. wire array
│
├── create_memory_from_array()
│   ├── Create RTLIL::Memory
│   ├── Set size and width
│   └── Generate access logic
│
└── Memory Write Restructuring (in processes)
    ├── Collect writes in pending_memory_writes
    ├── Create $memwr$ temporary wires:
    │   ├── $memwr$<mem>$addr
    │   ├── $memwr$<mem>$data
    │   └── $memwr$<mem>$en
    ├── Generate assignment logic in process
    └── Create memwr statement with priorities
```

## Interface Handling

```
Interface Import Flow:
├── import_interface()
│   ├── Create interface module
│   ├── Import interface ports
│   └── Import interface signals
│
├── import_interface_instances()
│   ├── Find interface instantiations
│   ├── Create interface cells
│   └── Connect interface ports
│
└── expand_interfaces()
    ├── Inline interface signals
    ├── Replace interface references
    └── Remove interface modules
```

## Package Import

```
import_package()
├── Create package namespace
├── Import package parameters
├── Import typedef definitions
├── Import functions
└── Store in package_map for reference
```

## Helper Functions

```
Helper Functions (Refactoring):
├── create_temp_wire()
│   └── Generate unique wire name
├── create_eq_cell()
│   └── Create $eq comparison cell
├── create_and_cell()
│   └── Create $and logic cell
├── create_or_cell()
│   └── Create $or logic cell
├── create_not_cell()
│   └── Create $not logic cell
├── create_mux_cell()
│   └── Create $mux multiplexer cell
├── cast_to_assignment()
│   └── Safe cast to assignment type
└── process_assignment_lhs_rhs()
    └── Extract LHS/RHS from assignment

Utility Functions:
├── get_src_attribute()
│   └── Extract source location
├── add_src_attribute()
│   └── Add source attribute to RTLIL
├── find_wire()
│   └── Look up wire by name
├── get_actual_type()
│   └── Resolve typedef references
└── evaluate_constant_expression()
    └── Evaluate compile-time constants
```

## Data Flow

1. **UHDM File** → Serializer → UHDM Object Tree
2. **UHDM Objects** → UhdmImporter → RTLIL IR
3. **RTLIL IR** → Yosys Passes → Optimized Design

## Key Design Patterns

1. **Two-Pass Import**: First pass creates module structure, second pass imports implementation
2. **Context Tracking**: `current_module`, `current_instance`, `current_scope` maintain context
3. **Name Mapping**: `name_map` tracks UHDM to RTLIL signal mappings
4. **Memory Write Buffering**: Collects memory writes for proper RTLIL generation
5. **Loop Unrolling**: For-loops are unrolled with variable substitution
6. **Process Structure Preservation**: Maintains process block structure instead of creating external combinational cells

