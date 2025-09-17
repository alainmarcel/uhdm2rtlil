# Recursive Function Support Implementation Plan for UHDM Frontend

## Problem Statement
The UHDM frontend currently cannot properly synthesize recursive functions. When encountering recursive functions with non-constant arguments, it either:
1. Hits maximum recursion depth and errors out
2. Creates placeholder wires that result in undefined values

The Verilog frontend correctly handles this by unrolling recursive functions into separate instances.

## Current Implementation Analysis

### Two Main Paths
1. **Compile-time evaluation** (`evaluate_function_call`): Works correctly for constant arguments
2. **Runtime synthesis** (`generate_function_process`): Broken for recursive functions

### Core Issues
- **Static recursion depth counter**: Prevents infinite loops but doesn't actually unroll
- **Flat namespace**: All function instances share same wire namespace
- **No call context tracking**: Cannot differentiate between recursive calls
- **Missing instance generation**: Doesn't create separate instances for each call

### Files to Modify
- `src/frontends/uhdm/functions.cpp` - Main function processing logic
- `src/frontends/uhdm/expression.cpp` - Function call handling
- `src/frontends/uhdm/uhdm2rtlil.h` - Class definitions

## Proposed Architecture

### 1. Core Data Structures

```cpp
// Function call context for tracking individual invocations
struct FunctionCallContext {
    // Identification
    std::string function_name;
    std::string instance_id;      // Unique: func$file:line$idx
    
    // Variable tracking
    std::map<std::string, RTLIL::SigSpec> wire_mappings;   // Variable -> Wire
    std::map<std::string, RTLIL::Const> const_values;      // Variable -> Const
    std::vector<RTLIL::SigSpec> arguments;
    
    // Metadata
    int call_depth;
    int source_line;
    std::string source_file;
    const func_call* call_site;
    const function* func_def;
    
    // For connecting instances
    RTLIL::Wire* result_wire;
    std::vector<RTLIL::Wire*> output_wires;
};

// Call stack manager
class FunctionCallStack {
private:
    std::vector<FunctionCallContext> stack;
    std::map<std::string, RTLIL::Process*> generated_processes;
    std::map<std::string, RTLIL::SigSpec> memoized_results;
    static constexpr int MAX_DEPTH = 100;
    
public:
    // Stack operations
    bool push(FunctionCallContext ctx);
    void pop();
    FunctionCallContext& current();
    const FunctionCallContext* parent() const;
    
    // Query operations
    bool isRecursive(const std::string& func_name) const;
    int getCallDepth(const std::string& func_name) const;
    std::string generateInstanceId(const std::string& func_name, int line);
    
    // Memoization
    bool hasCachedResult(const std::string& key) const;
    RTLIL::SigSpec getCachedResult(const std::string& key) const;
    void cacheResult(const std::string& key, RTLIL::SigSpec result);
};
```

### 2. Main Function Processor Class

```cpp
class FunctionProcessor {
private:
    UhdmImporter* importer;
    RTLIL::Module* module;
    FunctionCallStack call_stack;
    int instance_counter;
    
public:
    FunctionProcessor(UhdmImporter* imp, RTLIL::Module* mod) 
        : importer(imp), module(mod), instance_counter(0) {}
    
    // Main entry point
    RTLIL::SigSpec processFunction(
        const function* func_def,
        const std::vector<RTLIL::SigSpec>& args,
        const func_call* call_site,
        std::map<std::string, RTLIL::SigSpec>* parent_mapping = nullptr
    );
    
private:
    // Evaluation strategies
    bool canEvaluateConstant(const std::vector<RTLIL::SigSpec>& args);
    RTLIL::Const evaluateConstant(const function* func_def, 
                                  const std::vector<RTLIL::Const>& const_args);
    
    // Process generation
    RTLIL::Process* generateFunctionProcess(const FunctionCallContext& ctx);
    RTLIL::Process* generateRecursiveProcess(const FunctionCallContext& ctx);
    
    // Recursive call handling
    RTLIL::SigSpec handleRecursiveCall(const func_call* fc, 
                                       const FunctionCallContext& parent_ctx);
    
    // Instance management
    std::string createInstanceId(const std::string& func_name,
                                 const func_call* call_site);
    void connectInstances(const FunctionCallContext& parent,
                         const FunctionCallContext& child);
    
    // Statement processing
    void processStatement(const any* stmt, 
                         RTLIL::CaseRule* case_rule,
                         const FunctionCallContext& ctx);
};
```

## Implementation Phases

### Phase 1: Infrastructure Setup (Immediate)
**Goal**: Create foundation without breaking existing code

1. **Add FunctionCallContext structure** to `uhdm2rtlil.h`
2. **Create FunctionCallStack class** in `functions.cpp`
3. **Add instance ID generation** to differentiate recursive calls
4. **Update wire naming** to include instance IDs

**Validation**: Ensure all existing tests still pass

### Phase 2: Basic Recursive Support (Week 1)
**Goal**: Handle simple recursive functions like fibonacci

1. **Implement push/pop operations** for call stack
2. **Modify generate_function_process** to use call context
3. **Add recursion detection** based on call stack
4. **Create separate processes** for each recursive instance

**Test Case**: `fib_simple` should produce correct output

### Phase 3: Instance Connection (Week 2)
**Goal**: Properly connect recursive instances

1. **Track parent-child relationships** between instances
2. **Generate connection wires** between instances
3. **Handle return value propagation** through call chain
4. **Implement proper base case detection**

**Test Case**: `fib` test should pass

### Phase 4: Optimization (Week 3)
**Goal**: Optimize generated RTLIL

1. **Add memoization** for identical calls
2. **Implement constant folding** in recursive calls
3. **Dead code elimination** for unreachable branches
4. **Common subexpression elimination**

**Validation**: Compare gate count with Verilog frontend

## Detailed Implementation Steps

### Step 1: Modify uhdm2rtlil.h
```cpp
// Add to class UhdmImporter
private:
    class FunctionProcessor; // Forward declaration
    std::unique_ptr<FunctionProcessor> func_processor;
    
    // Add new method signatures
    RTLIL::SigSpec processFunctionWithContext(
        const function* func_def,
        const std::vector<RTLIL::SigSpec>& args,
        const func_call* call_site,
        FunctionCallContext* parent_ctx
    );
```

### Step 2: Refactor expression.cpp function call handling
```cpp
// In import_expression, case vpiFuncCall:
if (input_mapping) {
    // We're inside a function - use context-aware processing
    FunctionCallContext* parent_ctx = getCurrentFunctionContext();
    return processFunctionWithContext(func_def, args, fc, parent_ctx);
} else {
    // Top-level call - create new context
    return processFunctionWithContext(func_def, args, fc, nullptr);
}
```

### Step 3: Implement processFunctionWithContext
```cpp
RTLIL::SigSpec UhdmImporter::processFunctionWithContext(
    const function* func_def,
    const std::vector<RTLIL::SigSpec>& args,
    const func_call* call_site,
    FunctionCallContext* parent_ctx
) {
    // Check if all arguments are constant
    if (allArgsConstant(args)) {
        return evaluateConstant(func_def, args);
    }
    
    // Create new context for this call
    FunctionCallContext ctx;
    ctx.function_name = func_def->VpiName();
    ctx.instance_id = generateInstanceId(ctx.function_name, call_site);
    ctx.arguments = args;
    ctx.call_site = call_site;
    ctx.func_def = func_def;
    
    // Check for recursion
    if (parent_ctx && parent_ctx->function_name == ctx.function_name) {
        // Recursive call detected
        return handleRecursiveCall(ctx, parent_ctx);
    }
    
    // Generate process for this function instance
    return generateProcessForContext(ctx);
}
```

### Step 4: Handle Recursive Unrolling
```cpp
RTLIL::SigSpec UhdmImporter::handleRecursiveCall(
    FunctionCallContext& ctx,
    FunctionCallContext* parent_ctx
) {
    // Check if we can determine this will terminate
    bool has_base_case = checkForBaseCase(ctx);
    if (!has_base_case) {
        log_warning("Cannot determine termination for recursive function %s\n",
                   ctx.function_name.c_str());
    }
    
    // Create unique instance for this recursive call
    ctx.instance_id = generateUniqueInstanceId(ctx.function_name, 
                                               ctx.call_site,
                                               instance_counter++);
    
    // Create result wire for this instance
    std::string result_wire_name = stringf("$func_%s_result",
                                          ctx.instance_id.c_str());
    RTLIL::Wire* result_wire = module->addWire(
        RTLIL::escape_id(result_wire_name), 
        getReturnWidth(ctx.func_def)
    );
    ctx.result_wire = result_wire;
    
    // Generate process for this recursive instance
    RTLIL::Process* proc = generateRecursiveProcess(ctx);
    
    // Connect to parent instance
    connectInstances(*parent_ctx, ctx);
    
    return RTLIL::SigSpec(result_wire);
}
```

## Example: How fib(2) Would Be Processed

```
1. fib_wrap(2, fib2) called from initial block
   - Create context: fib_wrap$func$dut.sv:28$1
   - Arguments: [2, fib2_wire]
   - Not recursive (no parent context)
   - Generate process

2. Inside fib_wrap, calls fib(2)
   - Create context: fib$func$dut.sv:21$2
   - Arguments: [2]
   - Not recursive (different function)
   - Generate process

3. Inside fib(2), condition 2 <= 1 is false
   - Branch to else: fib(1) + fib(0)

4. Call fib(1)
   - Create context: fib$func$dut.sv:13$3
   - Arguments: [1]
   - RECURSIVE! (parent is fib)
   - Generate separate instance

5. Inside fib(1), condition 1 <= 1 is true
   - Return constant 1

6. Call fib(0)
   - Create context: fib$func$dut.sv:13$4
   - Arguments: [0]
   - RECURSIVE! (parent is fib)
   - Generate separate instance

7. Inside fib(0), condition 0 <= 1 is true
   - Return constant 0

8. Back in fib(2)
   - Add results: 1 + 0 = 1
   - Return 1

9. Back in fib_wrap
   - Compute: off + 1
   - Assign to fib2
```

## Testing Strategy

### Test Cases
1. **fib_simple**: Basic recursion with depth 2
2. **fib**: Recursion with variable input
3. **fib_recursion**: Pure recursive function
4. **mutual_recursion**: Two functions calling each other (future)

### Validation Metrics
- Correct output values
- No infinite recursion
- Generated gate count comparable to Verilog frontend
- No undefined wires (x values)

## Migration from Current Code

### Files to Preserve
- Compile-time evaluation functions (working correctly)
- Helper functions for scanning statements
- Operation evaluation logic

### Files to Refactor
- `generate_function_process` - needs complete rewrite with context
- Function call handling in `expression.cpp`
- Wire naming and instance generation

### Backward Compatibility
- Keep existing API for non-recursive functions
- Add feature flag for new recursive handling if needed
- Maintain existing test compatibility

## Success Criteria

1. **Correctness**: fib_simple produces `fib2 = off + 1`
2. **Completeness**: All recursive function tests pass
3. **Performance**: No worse than 2x slowdown vs current implementation
4. **Maintainability**: Clear separation of concerns, well-documented

## Next Steps

1. Review and approve this plan
2. Create feature branch `recursive-functions`
3. Implement Phase 1 infrastructure
4. Add unit tests for call stack
5. Proceed with Phase 2-4

## References

- Verilog frontend implementation: `frontends/verilog/`
- RTLIL documentation: `kernel/rtlil.h`
- Yosys internals guide: docs/yosys_internals.pdf