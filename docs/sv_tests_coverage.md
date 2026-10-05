# chipsalliance/sv-tests: what our frontend misses

[sv-tests](https://github.com/chipsalliance/sv-tests) at `c4229f3bd` is the LRM-chapter corpus every SystemVerilog tool is
scored on. `test/sv_tests_sweep.py` runs its synthesis set -- every test not marked
`:unsynthesizable: 1` outside `uvm/` and `testbenches/`, 707 of 1015 -- through three
frontends with sv-tests' own rules: the test's mode (simulation > elaboration > parsing >
preprocessing from its `:type:`), the Yosys runner's script per mode (`hierarchy; proc;
check; clean; memory_dff; memory_collect; stat; check`, then `sim -assert` for simulation
tests), and `:should_fail_because:` tests PASS when the tool rejects them.

| frontend | PASS | FAIL | what the column means |
|---|---|---|---|
| read_uhdm (Surelog + our frontend) | 598 | 109 | Surelog parse + read_uhdm + the mode script |
| read_verilog (yosys, sv-tests' own Yosys runner) | 364 | 343 | the same mode script |
| read_slang (sv-tests' yosys_slang runner flags) | 682 | 25 | read only -- that runner never elaborates further, so this is "slang reads it" |

**106** tests pass under read_verilog or read_slang and not under read_uhdm (the misses
below); **285** pass under read_uhdm and not under read_verilog; **3** fail under all three.

## How to reproduce

```
git clone --depth 1 https://github.com/chipsalliance/sv-tests ~/ext/sv-tests
cd test && python3 sv_tests_sweep.py --repo ~/ext/sv-tests --jobs 8 --out ../build/sv_tests   # all 1015 tests, ~10 min
python3 sv_tests_sweep.py --filter 'chapter-9/9.4.2.3'                                       # one test
ls ../build/sv_tests/work/tests__chapter-9__9.4.2.3--event_conditional.sv/   # surelog.log, uhdm.ys/.log, verilog.ys/.log, slang.ys/.log
python3 sv_tests_report.py --results ../build/sv_tests/results.tsv --commit <sha> > ../docs/sv_tests_coverage.md
```

## Misses, by cause

| cause | tests | kind |
|---|---|---|
| a file with no module (class / package / `$unit` declarations only): read_uhdm errors "No modules found", the other frontends accept an empty design | 82 | reader behaviour |
| should-fail test accepted: Surelog elaborates code the LRM forbids (every row lists the rule) | 15 | Surelog leniency |
| several blocking assignments to one variable inside `initial` taken as conflicting init values | 6 | reader bug |
| sized decimal `?`/`z` literal (`16'sd?`) not parsed | 1 | reader bug |
| Surelog syntax error | 1 | Surelog |
| `@(posedge clk iff cond)` event control: no clock extracted | 1 | reader bug |

### a file with no module (class / package / `$unit` declarations only): read_uhdm errors "No modules found", the other frontends accept an empty design -- 82

| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |
|---|---|---|---|---|---|
| [`chapter-18/18.12--randomization-of-scope-variables_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.12--randomization-of-scope-variables_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.12.1--adding-constraints-to-scope-variables_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.12.1--adding-constraints-to-scope-variables_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.13.1--urandom_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.13.1--urandom_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.13.1--urandom_2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.13.1--urandom_2.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.13.2--urandom_range_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.13.2--urandom_range_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.4.1--rand-modifier.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.4.1--rand-modifier.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.4.2--randc-modifier.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.4.2--randc-modifier.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5--constraint-blocks_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5--constraint-blocks_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.1--explicit-external-constraint_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.1--explicit-external-constraint_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.1--implicit-external-constraint_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.1--implicit-external-constraint_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.1--implicit-external-constraint_1.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.1--implicit-external-constraint_1.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.10--variable-ordering_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.10--variable-ordering_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.12--functions-in-constraint_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.12--functions-in-constraint_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.13--constraint-guards_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.13--constraint-guards_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.14--soft-constraints_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.14--soft-constraints_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.14.1--soft-constraint-priorities_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.14.1--soft-constraint-priorities_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.14.1--soft-constraint-priorities_2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.14.1--soft-constraint-priorities_2.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.14.2--discarding-soft-constraints_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.14.2--discarding-soft-constraints_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.14.2--discarding-soft-constraints_2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.14.2--discarding-soft-constraints_2.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.2--constraint-inheritance_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.2--constraint-inheritance_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.2--pure-constraint_3.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.2--pure-constraint_3.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.3--set-membership_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.3--set-membership_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.4--distribution_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.4--distribution_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.5--uniqueness-constraints_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.5--uniqueness-constraints_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.6--implication_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.6--implication_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.7--if-else-constraints_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.7--if-else-constraints_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.7--if-else-constraints_1.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.7--if-else-constraints_1.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.7--if-else-constraints_2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.7--if-else-constraints_2.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.7--if-else-constraints_3.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.7--if-else-constraints_3.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.8.2--array-reduction-iterative-constraints_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.8.2--array-reduction-iterative-constraints_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.5.9--global-constraints_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.5.9--global-constraints_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.6.2--post-randomize_method_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.6.2--post-randomize_method_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.6.2--pre-randomize-method_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.6.2--pre-randomize-method_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.7--in-line-constraints--randomize_3.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.7--in-line-constraints--randomize_3.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.7--in-line-constraints--randomize_5.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.7--in-line-constraints--randomize_5.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-18/18.7.1--local-scope-resolution_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.7.1--local-scope-resolution_0.sv) | elaboration | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.10--celldefine-basic-1.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.10--celldefine-basic-1.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.10--celldefine-basic-2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.10--celldefine-basic-2.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.11--pragma-basic.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.11--pragma-basic.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.11--pragma-complex.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.11--pragma-complex.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.11--pragma-nested.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.11--pragma-nested.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.11--pragma-number-multi.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.11--pragma-number-multi.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.11--pragma-number.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.11--pragma-number.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.12--line-basic.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.12--line-basic.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.12--line-complex.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.12--line-complex.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.1--define-expansion_22.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.1--define-expansion_22.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.1--define.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.1--define.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.1--include-define-expansion.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.1--include-define-expansion.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.2--undef-basic.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.2--undef-basic.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.2--undef-nonexisting.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.2--undef-nonexisting.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.3--undefineall-and-redefine.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.3--undefineall-and-redefine.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.5.3--undefineall-basic.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.5.3--undefineall-basic.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.7--timescale-basic-1.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.7--timescale-basic-1.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.7--timescale-basic-2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.7--timescale-basic-2.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.7--timescale-reset.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.7--timescale-reset.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.8--default_nettype-redefinition.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.8--default_nettype-redefinition.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.8--default_nettype.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.8--default_nettype.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.9--unconnected_drive-basic-2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.9--unconnected_drive-basic-2.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/22.9--unconnected_drive-basic.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/22.9--unconnected_drive-basic.sv) | preprocessing | FAIL | FAIL | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/dummy_include.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/dummy_include.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-22/include_directory/defs.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-22/include_directory/defs.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`chapter-5/5.6.4--compiler-directives-preprocessor-macro_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-5/5.6.4--compiler-directives-preprocessor-macro_0.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_0.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_1.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_1.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_10.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_10.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_16.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_16.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_17.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_17.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_18.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_18.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_2.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_3.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_3.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_4.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_4.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_5.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_5.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_6.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_6.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_7.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_7.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_8.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_8.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/desc/desc_test_9.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/desc/desc_test_9.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/empty/empty_test_0.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/empty/empty_test_0.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/empty/empty_test_1.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/empty/empty_test_1.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/empty/empty_test_2.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/empty/empty_test_2.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/empty/empty_test_3.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/empty/empty_test_3.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/empty/empty_test_4.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/empty/empty_test_4.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |
| [`generic/empty/empty_test_5.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/empty/empty_test_5.sv) | preprocessing | FAIL | PASS | PASS | ERROR: No modules found in UHDM design. |

### should-fail test accepted: Surelog elaborates code the LRM forbids (every row lists the rule) -- 15

| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |
|---|---|---|---|---|---|
| [`chapter-10/10.3--proc-assignment--bad.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-10/10.3--proc-assignment--bad.sv) | simulation | FAIL | FAIL | PASS | should fail: Illegal to procedurally assign to wire, IEEE Table 10-1 |
| [`chapter-11/11.4.14.3--unpack_stream_inv.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-11/11.4.14.3--unpack_stream_inv.sv) | simulation | FAIL | PASS | PASS | should fail: stream is wider than assignment target |
| [`chapter-11/11.9--tagged_union_member_access_inv.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-11/11.9--tagged_union_member_access_inv.sv) | simulation | FAIL | PASS | FAIL | should fail: accessing wrong member should result in run-time error |
| [`chapter-5/5.10-structure-arrays-illegal.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-5/5.10-structure-arrays-illegal.sv) | simulation | FAIL | PASS | PASS | should fail: C-like assignment is illegal |
| [`chapter-6/6.19--enum_value_inv.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.19--enum_value_inv.sv) | simulation | FAIL | FAIL | PASS | should fail: If the integer value expression is a sized literal constant, it shall be an error if the size is different from the enum base type, even if the val |
| [`chapter-6/6.19--enum_xx_inv.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.19--enum_xx_inv.sv) | simulation | FAIL | FAIL | PASS | should fail: An enumerated name with x or z assignments assigned to an enum with no explicit data type or an explicit2-state declaration shall be a syntax error |
| [`chapter-6/6.19--enum_xx_inv_order.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.19--enum_xx_inv_order.sv) | simulation | FAIL | FAIL | PASS | should fail: An unassigned enumerated name that follows an enum name with x or z assignments shall be a syntax error. |
| [`chapter-6/6.19.3--enum_type_checking_inv.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.19.3--enum_type_checking_inv.sv) | simulation | FAIL | FAIL | PASS | should fail: enum enforces strict type checking rules |
| [`chapter-6/6.19.4--enum_numerical_expr_no_cast.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.19.4--enum_numerical_expr_no_cast.sv) | simulation | FAIL | FAIL | PASS | should fail: enum numerical expression without casting |
| [`chapter-6/6.20.5--specparam_inv.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.20.5--specparam_inv.sv) | simulation | FAIL | PASS | PASS | should fail: specparam assignment to param should be invalid |
| [`chapter-6/6.5--variable_redeclare.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.5--variable_redeclare.sv) | simulation | FAIL | FAIL | PASS | should fail: Variable redeclaration |
| [`chapter-7/arrays/packed/variable-slice-zero.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-7/arrays/packed/variable-slice-zero.sv) | simulation | FAIL | FAIL | PASS | should fail: slicing array with zero part width |
| [`chapter-8/8.26.6.2--parameter_type_conflict_unresolved.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-8/8.26.6.2--parameter_type_conflict_unresolved.sv) | simulation | FAIL | PASS | PASS | should fail: superclass type declaration conflicts must be resolved in subclass |
| [`chapter-8/8.26.6.3--diamond_relationship_parametrized.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-8/8.26.6.3--diamond_relationship_parametrized.sv) | simulation | FAIL | PASS | PASS | should fail: different specializations of an interface class are treated as unique interface class types |
| [`generic/typedef/typedef_test_25__bad.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/generic/typedef/typedef_test_25__bad.sv) | simulation | FAIL | PASS | PASS | should fail: Using undefined parameters |

### several blocking assignments to one variable inside `initial` taken as conflicting init values -- 6

| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |
|---|---|---|---|---|---|
| [`chapter-10/10.4.1--blocking-assignment.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-10/10.4.1--blocking-assignment.sv) | simulation | FAIL | PASS | PASS | ERROR: Conflicting init values for signal \a (\a = 1'1 != 1'0). |
| [`chapter-9/9.3.1--sequential_block.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-9/9.3.1--sequential_block.sv) | elaboration | FAIL | PASS | PASS | ERROR: Conflicting init values for signal \a (\a = 1'1 != 1'0). |
| [`chapter-9/9.3.4--block_names_seq.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-9/9.3.4--block_names_seq.sv) | elaboration | FAIL | PASS | PASS | ERROR: Conflicting init values for signal \a (\a = 1'1 != 1'0). |
| [`chapter-9/9.3.5--statement_labels_seq.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-9/9.3.5--statement_labels_seq.sv) | elaboration | FAIL | FAIL | PASS | ERROR: Conflicting init values for signal \a (\a = 1'1 != 1'0). |
| [`chapter-9/9.4.5--event_blocking_assignment_delay.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-9/9.4.5--event_blocking_assignment_delay.sv) | elaboration | FAIL | PASS | PASS | ERROR: Conflicting init values for signal \b (\a = 1'0 != 1'1). |
| [`chapter-9/9.4.5--event_nonblocking_assignment_delay.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-9/9.4.5--event_nonblocking_assignment_delay.sv) | elaboration | FAIL | PASS | PASS | ERROR: Conflicting init values for signal \b (\a = 1'0 != 1'1). |

### sized decimal `?`/`z` literal (`16'sd?`) not parsed -- 1

| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |
|---|---|---|---|---|---|
| [`chapter-5/5.7.1--integers-signed.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-5/5.7.1--integers-signed.sv) | elaboration | FAIL | PASS | PASS | ERROR: Failed to parse decimal constant: value='DEC:?', substr='?', error=stoll |

### Surelog syntax error -- 1

| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |
|---|---|---|---|---|---|
| [`chapter-6/6.23--type_op_compare.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.23--type_op_compare.sv) | elaboration | FAIL | FAIL | PASS | surelog: [SNT:PA0207] tests/chapter-6/6.23--type_op_compare.sv:18:19: Syntax error: no viable alternative at input 'module top #( parameter type T = type(logic[ |

### `@(posedge clk iff cond)` event control: no clock extracted -- 1

| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |
|---|---|---|---|---|---|
| [`chapter-9/9.4.2.3--event_conditional.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-9/9.4.2.3--event_conditional.sv) | elaboration | FAIL | FAIL | PASS | ERROR: Clock signal is empty when creating sync rule at line 3262 |

## Fails under all three frontends

| test | mode | read_uhdm | read_slang |
|---|---|---|---|
| [`chapter-10/10.6.1--assign-deassign.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-10/10.6.1--assign-deassign.sv) | elaboration | FAIL | ERROR: Design elaboration failed; see full log for details |
| [`chapter-6/6.5--variable_mixed_assignments.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.5--variable_mixed_assignments.sv) | simulation | FAIL | FAIL |
| [`chapter-6/6.5--variable_multiple_assignments.sv`](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-6/6.5--variable_multiple_assignments.sv) | simulation | FAIL | FAIL |

## The cores sv-tests covers, and which we sweep

sv-tests generates one test per core configuration from `generators/*` (full-core
elaboration, top module named); our nightly sweeps prove per module against read_slang
and co-simulate.  What they have that we do not:

| sv-tests core test | what it is | our sweep |
|---|---|---|
| ariane / CVA6 (`cva6_cv64a6_imafdc_sv39`) | full core, top `cva6` | yes -- per-module miters + per-instance chip sweep (`sweep-cva6.yml`, same configuration) |
| ariane / CVA6 (`cv64a6_imafdc_sv39_hpdcache`, `cv64a6_imafdch_sv39`, `cv32a6_imac_sv32`, `ariane_testharness`) | full core at four more configurations | **no** -- one configuration only |
| ibex (`ibex_simple_system`, fusesoc) | full core | yes -- per-module (`sweep-ibex.yml`) and `ibex_top` / `ibex_lockstep` as internal tests |
| veer-el2 (`veer-el2_wrapper` synth, `tb_top` sim) | full core, default config | partly -- the VeeR EL2 instances inside the Caliptra chip (`sweep-caliptra.yml`), not standalone |
| veer-eh1 (`veer-eh1_wrapper`, fusesoc) | full core | **no** |
| black-parrot (`bp_default`, `bp_unicore`, `bp_multicore_1`, `_cce_ucode`, `bp_multicore_4`, `_cce_ucode_cfg`) with basejump_stl + HardFloat | six configurations, top `wrapper` | **no** |
| scr1 (`scr1_top_tb_axi`) | full core + AXI top | **no** |
| rsd (`Core`) | full core | **no** |
| tnoc (`tnoc`) | network-on-chip | **no** |
| rggen (`rggen`, rggen-sv-rtl + rggen-sample) | generated register files | **no** |
| fx68k | 68000 core (needs `--allow-dup-initial-drivers` under slang) | **no** |
| yosys tests (`yosys_hana`) | the upstream yosys test files | yes -- the 576 generated `test/run/**` tests in the regression |
| ivtest (Icarus tests) | the Icarus Verilog test suite | **no** |

