# Recursive Function RTLIL Size Optimization

## Current Status
The recursive function support is now working correctly and produces functionally equivalent results to the Verilog frontend. However, the UHDM frontend generates significantly larger RTLIL code (31K vs 1.7K for fib_simple test).

## Issue Analysis
The UHDM frontend creates separate processes for each recursive function call, even when those calls have constant arguments that could be evaluated at compile time.

For example, when processing `fib(2)`:
- `fib(2)` creates a process that calls `fib(1)` and `fib(0)` 
- `fib(1)` and `fib(0)` each create their own processes
- Even though 1 and 0 are constants, they're passed as wire expressions

The Verilog frontend appears to perform more aggressive constant propagation and inlining.

## Root Cause
1. **Lack of constant propagation in function bodies**: When a function parameter `k` has value 2, expressions like `k-1` are evaluated as wire operations, not as the constant 1.

2. **No constant tracking through wire mappings**: The function processing doesn't track that certain wires have constant values.

3. **Expression evaluation returns wires**: Even when computing constant expressions, `import_expression` returns wire references instead of constant values.

## Proposed Solution
To match the Verilog frontend's efficiency, we need:

### 1. Enhanced Constant Propagation
Track constant values through the function's wire mappings:
```cpp
// In FunctionCallContext
std::map<std::string, RTLIL::Const> const_wire_values;  // Track constant wire values

// When assigning k = 2
if (arg.is_fully_const()) {
    const_wire_values[param_name] = arg.as_const();
}
```

### 2. Constant Expression Evaluation
When evaluating expressions in function bodies:
```cpp
// In import_expression for function parameters
if (input_mapping && input_mapping->count(name)) {
    // Check if this wire has a known constant value
    if (const_wire_values.count(name)) {
        return RTLIL::SigSpec(const_wire_values[name]);
    }
}
```

### 3. Immediate Evaluation of Constant Operations
When processing operations like `k - 1`:
```cpp
// In import_operation
if (operands_are_constant) {
    // Evaluate immediately
    RTLIL::Const result = evaluate_operation(op, const_operands);
    return RTLIL::SigSpec(result);
}
```

### 4. Function Call Optimization
Before creating a process for a function call, check if arguments are constant after evaluation:
```cpp
// After importing arguments
for (auto& arg : args) {
    if (arg.is_wire()) {
        // Try to resolve to constant if possible
        arg = resolve_to_constant_if_possible(arg);
    }
}
```

## Benefits
- Dramatically reduce RTLIL size (10-20x smaller)
- Faster synthesis 
- Better optimization opportunities
- Match Verilog frontend efficiency

## Implementation Complexity
Medium - Requires careful tracking of constant values through the function processing pipeline without breaking existing functionality.

## Testing Requirements
- Ensure all existing tests still pass
- Verify constant propagation works correctly
- Check that recursive functions with variable inputs still work
- Compare RTLIL sizes with Verilog frontend for various test cases