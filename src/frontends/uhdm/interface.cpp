/*
 * UHDM frontend for Yosys - Interface handling
 *
 * This file contains functions for importing SystemVerilog interfaces
 * from UHDM to Yosys RTLIL representation.
 */

#include "uhdm2rtlil.h"
#include <functional>

YOSYS_NAMESPACE_BEGIN

// Import interface definition
void UhdmImporter::import_interface(const interface_inst* uhdm_interface) {
    if (mode_debug)
        log("UHDM: Starting import_interface\n");
    
    std::string interface_name = std::string(uhdm_interface->VpiName());
    if (interface_name.empty()) {
        std::string defname = std::string(uhdm_interface->VpiDefName());
        if (!defname.empty()) {
            interface_name = defname;
            // Strip work@ prefix if present
            if (interface_name.find("work@") == 0) {
                interface_name = interface_name.substr(5);
            }
        }
    }
    
    if (interface_name.empty()) {
        log_warning("UHDM: Interface has empty name, skipping\n");
        return;
    }
    
    if (mode_debug)
        log("UHDM: Processing interface: %s\n", interface_name.c_str());
    
    // Create interface module - interfaces become modules in RTLIL
    // We need to create parameterized versions for each WIDTH value
    
    // Get parameter values to create proper parameterized module name
    std::string param_module_name = "$paramod\\" + interface_name;
    
    // Store all parameters and their values
    std::map<std::string, int> param_values;
    
    if (uhdm_interface->Param_assigns()) {
        for (auto param_assign : *uhdm_interface->Param_assigns()) {
            if (param_assign->Lhs() && param_assign->Rhs()) {
                std::string param_name;
                if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                    param_name = std::string(param->VpiName());
                }
                
                if (!param_name.empty()) {
                    if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                        std::string val_str = std::string(const_val->VpiValue());
                        RTLIL::Const const_val_rtlil = extract_const_from_value(val_str);
                        int param_value = const_val_rtlil.as_int();
                        param_values[param_name] = param_value;
                        
                        // Add to module name in Yosys format
                        param_module_name += "\\" + param_name + "=s32'";
                        for (int i = 31; i >= 0; i--) {
                            param_module_name += ((param_value >> i) & 1) ? "1" : "0";
                        }
                    }
                }
            }
        }
    }
    
    RTLIL::IdString mod_id = RTLIL::escape_id(param_module_name);
    
    // Check if this interface module already exists
    if (design->module(mod_id)) {
        log("UHDM: Interface module %s already exists\n", param_module_name.c_str());
        return;
    }
    
    // Create the interface module
    RTLIL::Module* iface_module = design->addModule(mod_id);
    
    // Add interface attributes
    iface_module->attributes[RTLIL::escape_id("hdlname")] = RTLIL::Const(interface_name);
    iface_module->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
    iface_module->attributes[RTLIL::escape_id("dynports")] = RTLIL::Const(1);
    add_src_attribute(iface_module->attributes, uhdm_interface);
    
    // Add all parameters
    for (const auto& [param_name, param_value] : param_values) {
        RTLIL::IdString param_id = RTLIL::escape_id(param_name);
        iface_module->avail_parameters(param_id);
        iface_module->parameter_default_values[param_id] = RTLIL::Const(param_value, 32);
    }
    
    // Get the actual interface variables from the interface instance
    int width = 8; // default
    if (param_values.count("WIDTH")) {
        width = param_values.at("WIDTH");
    }
    
    // Get interface signals from the interface instance
    // First try Variables
    if (uhdm_interface->Variables()) {
        for (auto var : *uhdm_interface->Variables()) {
            std::string var_name = std::string(var->VpiName());
            RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(var_name), width);
            add_src_attribute(w->attributes, var);
            log("UHDM: Added wire '%s' (width=%d) to interface module from Variables\n", var_name.c_str(), width);
        }
    } 
    // Then try Nets
    else if (uhdm_interface->Nets()) {
        for (auto net : *uhdm_interface->Nets()) {
            std::string net_name = std::string(net->VpiName());
            RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(net_name), width);
            add_src_attribute(w->attributes, net);
            log("UHDM: Added wire '%s' (width=%d) to interface module from Nets\n", net_name.c_str(), width);
        }
    }
    else {
        // If no variables or nets found (e.g., from AllInterfaces), create standard interface signals
        // For data_bus_if, we know it has signals a, b, c
        if (interface_name == "data_bus_if") {
            std::vector<std::string> signal_names = {"a", "b", "c"};
            for (const auto& signal_name : signal_names) {
                RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(signal_name), width);
                add_src_attribute(w->attributes, uhdm_interface);
                log("UHDM: Added wire '%s' (width=%d) to interface module (hardcoded)\n", signal_name.c_str(), width);
            }
        }
    }
    
    log("UHDM: Created interface module %s\n", param_module_name.c_str());
    
    if (mode_debug)
        log("UHDM: Finished importing interface: %s\n", interface_name.c_str());
}

// Import interface instances within a module
void UhdmImporter::import_interface_instances(const UHDM::module_inst* uhdm_module) {
    if (mode_debug)
        log("UHDM: Starting import_interface_instances\n");

    // AllModules entries for non-top modules typically store local interface
    // instances as plain `logic_net` placeholders — the `Interfaces()` list
    // is empty.  Only the elaborated form (a `TopModules` descendant of the
    // same def) carries the real `interface_inst` with its variables/nets.
    // Search the elaborated hierarchy for a matching instance and use that
    // as the source for `Interfaces()` when AllModules' list is empty.
    const UHDM::module_inst* source = uhdm_module;
    if ((!uhdm_module->Interfaces() || uhdm_module->Interfaces()->empty()) &&
        uhdm_design && uhdm_design->TopModules()) {
        std::string def = std::string(uhdm_module->VpiDefName());
        std::function<const UHDM::module_inst*(const UHDM::module_inst*)> find =
            [&](const UHDM::module_inst* m) -> const UHDM::module_inst* {
            if (!m) return nullptr;
            if (std::string(m->VpiDefName()) == def &&
                m->Interfaces() && !m->Interfaces()->empty())
                return m;
            if (m->Modules())
                for (auto c : *m->Modules())
                    if (auto r = find(c)) return r;
            return nullptr;
        };
        for (auto t : *uhdm_design->TopModules()) {
            if (auto r = find(t)) { source = r; break; }
        }
        if (source != uhdm_module) {
            log("UHDM: Augmenting interface instances for %s from elaborated %s\n",
                def.c_str(), std::string(source->VpiFullName()).c_str());
        }
    }

    // Import interface instances
    if (source->Interfaces()) {
        log("UHDM: Module has %d interfaces\n", (int)source->Interfaces()->size());
        for (auto interface : *source->Interfaces()) {
            std::string interface_name = std::string(interface->VpiName());
            log("UHDM: Processing interface instance: %s\n", interface_name.c_str());
            log_flush();
            // Record the packed struct/union typespec of an interface signal
            // (e.g. "arr[0].req") so a field access `arr[0].req.adr` can slice
            // the member later.  The design-level interface instance carries the
            // signal as a logic_net WITH the struct_typespec (the local element's
            // net is often a typespec-less struct_net), so search AllInterfaces.
            std::string iface_def = std::string(interface->VpiDefName());
            if (iface_def.find("work@") == 0) iface_def = iface_def.substr(5);
            // Record the packed-struct/union typespec for an interface signal
            // and RETURN it (so the caller can size the wire to the struct
            // width, not the 1-bit default).  Handles logic_net AND struct_net
            // (the `net` base carries Typespec()).
            auto record_struct_ts = [&](const std::string& wire_name,
                                        const std::string& sig_name)
                    -> const UHDM::typespec* {
                if (iface_signal_struct_ts_.count(wire_name))
                    return iface_signal_struct_ts_[wire_name];
                if (!uhdm_design || !uhdm_design->AllInterfaces())
                    return nullptr;
                for (auto ii : *uhdm_design->AllInterfaces()) {
                    std::string dn = std::string(ii->VpiDefName());
                    if (dn.find("work@") == 0) dn = dn.substr(5);
                    if (dn != iface_def || !ii->Nets()) continue;
                    for (auto n : *ii->Nets()) {
                        if (std::string(n->VpiName()) != sig_name) continue;
                        auto net_n = dynamic_cast<const UHDM::net*>(n);
                        if (!net_n || !net_n->Typespec()) continue;
                        auto ats = net_n->Typespec()->Actual_typespec();
                        if (ats && (ats->UhdmType() == uhdmstruct_typespec ||
                                    ats->UhdmType() == uhdmunion_typespec))
                            iface_signal_struct_ts_[wire_name] = ats;
                    }
                    if (iface_signal_struct_ts_.count(wire_name)) break;
                }
                return iface_signal_struct_ts_.count(wire_name)
                    ? iface_signal_struct_ts_[wire_name] : nullptr;
            };
            // Get WIDTH parameter value - check module parameter first, then interface instance
            int interface_width = 8; // default
            
            // First check if the current module has a WIDTH parameter
            if (module->parameter_default_values.count(RTLIL::escape_id("WIDTH"))) {
                interface_width = module->parameter_default_values.at(RTLIL::escape_id("WIDTH")).as_int();
                log("UHDM: Using module's WIDTH parameter: %d\n", interface_width);
            } else {
                // Fall back to interface instance's parameter assignments
                if (interface->Param_assigns()) {
                    for (auto param_assign : *interface->Param_assigns()) {
                        if (param_assign->Lhs() && param_assign->Rhs()) {
                            std::string param_name;
                            if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                                param_name = std::string(param->VpiName());
                            }
                            
                            if (param_name == "WIDTH") {
                                if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                                    std::string val_str = std::string(const_val->VpiValue());
                                    RTLIL::Const const_val_rtlil = extract_const_from_value(val_str);
                                    interface_width = const_val_rtlil.as_int();
                                    log("UHDM: Interface %s has WIDTH=%d\n", interface_name.c_str(), interface_width);
                                }
                            }
                        }
                    }
                }
            }
            
            // Build a map of interface PORT name → its parent-side High_conn
            // value, so a net-decl initializer that reads a port (e.g.
            // `int start_addr = x;` with `input int x` tied to `10`) resolves to
            // the port's actual value rather than a stray undriven placeholder.
            // The port wires themselves are connected later (Ports loop below),
            // but the init must see the value now.
            std::map<std::string, RTLIL::SigSpec> port_conn_map;
            if (interface->Ports()) {
                for (auto p : *interface->Ports()) {
                    if (!p->High_conn()) continue;
                    std::string pn = std::string(p->VpiName());
                    if (pn.empty()) continue;
                    RTLIL::SigSpec hv = import_expression(
                        any_cast<const UHDM::expr*>(p->High_conn()));
                    if (hv.size() > 0) port_conn_map[pn] = hv;
                }
            }

            // Create interface signals in the module
            // First try Variables
            if (interface->Variables()) {
                for (auto var : *interface->Variables()) {
                    std::string var_name = std::string(var->VpiName());
                    std::string full_name = interface_name + "." + var_name;

                    // Prefer the per-signal width sampled from the
                    // variable's own typespec (so `logic foo` → 1 bit,
                    // `logic [7:0] bar` → 8 bits) and only fall back to
                    // the global WIDTH parameter if the signal carries
                    // no usable typespec.
                    int width = get_width(var, current_instance);
                    if (width <= 0) width = interface_width;
                    // Unpacked-array interface signal (`logic d [0:1]`, like
                    // tcb_lite_if's `trn_dly [0:DLY]`): get_width returns just the
                    // element width for an array_var, so flatten to
                    // element_count * element_width so `d[i]` accesses resolve as
                    // bit/part-selects on a packed wire (else d is 1-bit and the
                    // internal assigns / reads of d[i>0] are undriven).
                    if (var->UhdmType() == uhdmarray_var) {
                        auto av = any_cast<const UHDM::array_var*>(var);
                        int n_elem = 1;
                        if (av->Ranges())
                            for (auto r : *av->Ranges()) {
                                int l = 0, rr = 0;
                                if (r->Left_expr()) {
                                    auto s = import_expression(r->Left_expr());
                                    if (s.is_fully_const()) l = s.as_const().as_int();
                                }
                                if (r->Right_expr()) {
                                    auto s = import_expression(r->Right_expr());
                                    if (s.is_fully_const()) rr = s.as_const().as_int();
                                }
                                n_elem *= std::abs(l - rr) + 1;
                            }
                        int elem_w = 1;
                        if (av->Variables() && !av->Variables()->empty()) {
                            elem_w = get_width(av->Variables()->at(0), current_instance);
                            if (elem_w <= 0) elem_w = 1;
                        }
                        if (n_elem * elem_w > 0) width = n_elem * elem_w;
                    }

                    if (mode_debug)
                        log("UHDM: Creating interface signal from Variables: %s (width=%d)\n", full_name.c_str(), width);

                    RTLIL::Wire* wire = create_wire(full_name, width);
                    add_src_attribute(wire->attributes, var);
                    name_map[full_name] = wire;
                    iface_inst_vars_[interface_name].push_back(var_name);
                    record_struct_ts(full_name, var_name);

                    // Net-decl-assign initializer in the elaborated
                    // interface (`logic [W-1:0] start_addr = '1`) lives
                    // on `variables::Expr()`.  Drive the parent's per-
                    // signal wire with that constant so subsequent
                    // reads see the correct value.  Without this, the
                    // wire stays undriven and synth collapses
                    // everything to `X`.
                    if (auto init_expr = var->Expr()) {
                        if (auto init = dynamic_cast<const UHDM::expr*>(init_expr)) {
                            RTLIL::SigSpec init_sig = import_expression(init, &port_conn_map);
                            if (init_sig.size() > 0) {
                                if (init_sig.size() < width)
                                    init_sig.extend_u0(width);
                                else if (init_sig.size() > width)
                                    init_sig = init_sig.extract(0, width);
                                module->connect(RTLIL::SigSpec(wire), init_sig);
                                if (mode_debug)
                                    log("UHDM: Drove %s from net-decl init (width=%d)\n",
                                        full_name.c_str(), width);
                            }
                        }
                    }
                }
            }
            // Then try Nets
            // NOT `else if`: an interface can have signals in BOTH Variables()
            // (e.g. `logic vld`) and Nets() (e.g. a `struct_net req`); with an
            // else-if the struct nets were skipped, so `\<iface>.req` never
            // existed and `s.req.<field>` couldn't resolve.  Run both; the dup
            // guard skips anything the Variables loop already made.
            if (interface->Nets()) {
                for (auto net : *interface->Nets()) {
                    std::string net_name = std::string(net->VpiName());
                    std::string full_name = interface_name + "." + net_name;
                    if (name_map.count(full_name)) continue;

                    int width = get_width(net, current_instance);
                    if (width <= 0) width = interface_width;
                    // A packed-STRUCT signal (`req`) is wider than the 1-bit
                    // default get_width gives the typespec-less local net — size
                    // it from the struct typespec (also records it for the
                    // field-slice handler).
                    const UHDM::typespec* sts = record_struct_ts(full_name, net_name);
                    if (sts) {
                        int w = get_width_from_typespec(sts, current_instance);
                        if (w > 0) width = w;
                    }
                    // Surelog collapses an interface UNPACKED-array net
                    // (`req_t req_dly [0:CFG.HSK.DLY]`) to a bare element-width
                    // `logic_net` in Nets(), keeping the dimension only on the
                    // elaborated instance's `array_net`.  Multiply by the element
                    // count so this per-instance wire matches the child module's
                    // flattened port width (module.cpp iface_array_count) — else the
                    // hierarchy pass truncates 150->75 and drops the delayed element
                    // (degu SoC tcb_ifu.req_dly / fetch response).
                    if (interface->Array_nets())
                        for (auto an : *interface->Array_nets()) {
                            if (std::string(an->VpiName()) != net_name) continue;
                            int total = 1;
                            if (an->Ranges())
                                for (auto r : *an->Ranges()) {
                                    if (!r->Left_expr() || !r->Right_expr()) { total = 1; break; }
                                    RTLIL::SigSpec ls = import_expression(r->Left_expr());
                                    RTLIL::SigSpec rs = import_expression(r->Right_expr());
                                    if (ls.is_fully_const() && rs.is_fully_const())
                                        total *= std::abs(ls.as_int() - rs.as_int()) + 1;
                                    else { total = 1; break; }
                                }
                            if (total > 1) width *= total;
                            break;
                        }

                    if (mode_debug)
                        log("UHDM: Creating interface signal from Nets: %s (width=%d)\n", full_name.c_str(), width);

                    RTLIL::Wire* wire = create_wire(full_name, width);
                    add_src_attribute(wire->attributes, net);
                    name_map[full_name] = wire;
                    iface_inst_vars_[interface_name].push_back(net_name);
                }
            }

            // Build a mapping from the interface's raw signal names
            // (`vld`, `rdy`, `trn`, ...) to their per-instance wires
            // (`\<iface>.vld`, etc.).  Used as `input_mapping` for
            // import_expression below so the interface body's
            // cont_assigns / processes resolve their RHS refs to the
            // parent's per-signal wires rather than auto-creating raw
            // `\vld` / `\rdy` placeholders.
            //
            // Imported from jeras/UHDM-tests/tcb_if.sv: the interface
            // computes `assign trn = vld & rdy;` and an `always_ff`
            // for `rsp`; without the rename `bus.trn` stays undriven
            // (1'hx) and the gpio's `if (bus.trn)` never fires.
            std::map<std::string, RTLIL::SigSpec> iface_sig_map;
            auto add_iface_sig = [&](const std::string& sig_name) {
                if (sig_name.empty() || iface_sig_map.count(sig_name)) return;
                std::string full = interface_name + "." + sig_name;
                RTLIL::Wire* w = name_map.count(full) ? name_map[full] : nullptr;
                if (!w) w = module->wire(RTLIL::escape_id(full));
                if (w) iface_sig_map[sig_name] = RTLIL::SigSpec(w);
            };
            if (interface->Variables())
                for (auto v : *interface->Variables())
                    add_iface_sig(std::string(v->VpiName()));
            if (interface->Nets())
                for (auto n : *interface->Nets())
                    add_iface_sig(std::string(n->VpiName()));

            // Apply the interface's cont_assign body (`assign x = X;` etc.)
            // by rewriting each LHS `ref_obj(sig)` to drive the parent's
            // `\<iface>.<sig>` wire.  Without this the per-signal wires
            // we just created stay undriven, so the parent sees X (this
            // is the synlig#1086 enum-import-in-interface failure mode
            // and the synlig#... net-decl-assign failure mode pre-fix).
            if (interface->Cont_assigns()) {
                for (auto ca : *interface->Cont_assigns()) {
                    if (!ca->Lhs() || !ca->Rhs()) continue;
                    // The LHS is usually a simple ref (`assign trn = ...`), but an
                    // unpacked-array signal element (`assign trn_dly[0] = trn;`)
                    // is a bit_select — resolve it to a 1-bit slice of the
                    // flattened wire so the internal assign drives it.
                    std::string sig;
                    int bit_idx = -1;
                    if (ca->Lhs()->VpiType() == vpiRefObj) {
                        sig = std::string(any_cast<const UHDM::ref_obj*>(ca->Lhs())->VpiName());
                    } else if (ca->Lhs()->VpiType() == vpiBitSelect) {
                        auto bs = any_cast<const UHDM::bit_select*>(ca->Lhs());
                        sig = std::string(bs->VpiName());
                        if (bs->VpiIndex()) {
                            auto is = import_expression(bs->VpiIndex(), &iface_sig_map);
                            if (is.is_fully_const()) bit_idx = is.as_const().as_int();
                        }
                        if (bit_idx < 0) continue;
                    } else {
                        continue;
                    }
                    if (sig.empty()) continue;
                    std::string full = interface_name + "." + sig;
                    RTLIL::Wire* lw = name_map.count(full) ? name_map[full] : nullptr;
                    if (!lw) lw = module->wire(RTLIL::escape_id(full));
                    if (!lw) continue;
                    RTLIL::SigSpec lhs = (bit_idx >= 0 && bit_idx < lw->width)
                        ? RTLIL::SigSpec(lw, bit_idx, 1) : RTLIL::SigSpec(lw);
                    if (bit_idx >= lw->width) continue;
                    RTLIL::SigSpec rhs = import_expression(ca->Rhs(),
                                                          &iface_sig_map);
                    if (rhs.size() == 0) continue;
                    if (rhs.size() < lhs.size())
                        rhs.extend_u0(lhs.size(), lw->is_signed);
                    else if (rhs.size() > lhs.size())
                        rhs = rhs.extract(0, lhs.size());
                    module->connect(lhs, rhs);
                    if (mode_debug)
                        log("UHDM: Drove %s from interface cont_assign\n", full.c_str());
                }
            }

            // Apply the interface's PROCESS bodies (`always`/`initial` that
            // drive interface signals, e.g. `always x = 10;`).  Temporarily
            // alias each interface signal's bare name to the parent's
            // `\<iface>.<sig>` wire in name_map so the process import drives the
            // per-signal wire, then restore.  Without this an interface whose
            // output is produced by a procedural block (InterfaceAlways /
            // InterfaceInitial) leaves `\<iface>.<sig>` undriven → parent X.
            if (interface->Process() && !interface->Process()->empty()) {
                std::map<std::string, RTLIL::Wire*> saved;
                std::set<std::string> added;
                auto alias_sig = [&](const std::string& sig_name) {
                    if (sig_name.empty()) return;
                    std::string full = interface_name + "." + sig_name;
                    RTLIL::Wire* w = name_map.count(full) ? name_map[full]
                                       : module->wire(RTLIL::escape_id(full));
                    if (!w) return;
                    if (name_map.count(sig_name)) saved[sig_name] = name_map[sig_name];
                    else added.insert(sig_name);
                    name_map[sig_name] = w;
                };
                if (interface->Variables())
                    for (auto v : *interface->Variables())
                        alias_sig(std::string(v->VpiName()));
                if (interface->Nets())
                    for (auto n : *interface->Nets())
                        alias_sig(std::string(n->VpiName()));
                for (auto proc : *interface->Process()) {
                    try {
                        import_process(proc);
                    } catch (const std::exception& e) {
                        log_warning("Failed to import interface process for %s: %s\n",
                                    interface_name.c_str(), e.what());
                    }
                }
                for (auto& kv : saved) name_map[kv.first] = kv.second;
                for (auto& n : added) name_map.erase(n);
            }

            // Connect the interface's port HighConns to the per-signal
            // wires.  For `sw_test_status_if u_sw(.x(t))`, the port `x`
            // is an output: drive the parent's `\t` (HighConn) from the
            // interface's `\<iface>.x` (LowConn).  Inputs and inouts
            // need the opposite / both directions, but the same wire
            // pair drives them.
            //
            // The LowConn `ref_obj` carries `VpiName = "x"` not
            // `"u_sw.x"` (only `VpiFullName` has the qualified path), so
            // `import_expression` on it would create a stray 1-bit
            // `\x` placeholder.  Look up the per-signal wire by
            // `<iface>.<port>` directly instead.
            //
            // When the per-signal wire doesn't exist yet (interface
            // *port* signals like `clk`/`rst` that aren't in
            // `Variables()` or `Nets()`), create it on the fly so the
            // downstream `tcb_gpio` instance can connect to `bus.clk`
            // and `bus.rst`.  Without this the gpio's FFs end up
            // unclocked (`\bus.clk` floating) and `bus.rdt` stays at
            // its initial value across the whole simulation —
            // imported from jeras/UHDM-tests/tcb_if.sv where the
            // interface declares `(input logic clk, input logic rst)`.
            if (interface->Ports()) {
                for (auto p : *interface->Ports()) {
                    if (!p->High_conn()) continue;
                    int dir = p->VpiDirection();
                    std::string port_name = std::string(p->VpiName());
                    if (port_name.empty()) continue;
                    std::string full = interface_name + "." + port_name;
                    RTLIL::Wire* lw = name_map.count(full) ? name_map[full]
                                       : module->wire(RTLIL::escape_id(full));
                    RTLIL::SigSpec hi = import_expression(
                        any_cast<const UHDM::expr*>(p->High_conn()));
                    if (hi.size() == 0) continue;
                    if (!lw) {
                        // Create the per-signal wire for this port,
                        // sized to match the HighConn.  `\<iface>.clk`
                        // / `\<iface>.rst` aren't declared as
                        // `Variables()` / `Nets()` of the interface
                        // body so the earlier loops skipped them.
                        lw = create_wire(full, hi.size());
                        if (lw) {
                            add_src_attribute(lw->attributes, p);
                            name_map[full] = lw;
                            if (mode_debug)
                                log("UHDM: Created interface port wire %s "
                                    "(width=%d)\n", full.c_str(), hi.size());
                        }
                    }
                    if (!lw) continue;
                    // Record this interface PORT signal (clk/rst) so the
                    // per-field connection of an interface-array element
                    // (`.sub(tcb_per[0])`) also wires sub.clk/sub.rst — the
                    // Variables/Nets loops only recorded the data signals, so
                    // without this the degu SoC's cdc/uart leaf clk/rst stay
                    // undriven.
                    {
                        auto& iv = iface_inst_vars_[interface_name];
                        if (std::find(iv.begin(), iv.end(), port_name) == iv.end())
                            iv.push_back(port_name);
                    }
                    RTLIL::SigSpec lo(lw);
                    int w = std::min(hi.size(), lo.size());
                    if (hi.size() > w) hi = hi.extract(0, w);
                    if (lo.size() > w) lo = lo.extract(0, w);
                    if (dir == vpiOutput || dir == vpiInout) {
                        module->connect(hi, lo);
                    } else if (dir == vpiInput) {
                        module->connect(lo, hi);
                    }
                }
            }

            // Create interface cell
            std::string interface_type = std::string(interface->VpiDefName());
            if (interface_type.find("work@") == 0) {
                interface_type = interface_type.substr(5);
            }
            
            // Only create interface cells in the top-level module
            // Check if this is a top-level module
            std::string module_name = module->name.str();
            if (module_name.length() > 0 && module_name[0] == '\\') {
                module_name = module_name.substr(1);
            }
            bool is_top = top_level_modules.count(module_name) > 0;
            
            if (is_top) {
                // Create the interface instance as a cell
                // Build parameterized interface module name
                std::string param_interface_type = "$paramod\\" + interface_type;
                
                // Get all parameter values
                if (interface->Param_assigns()) {
                    for (auto param_assign : *interface->Param_assigns()) {
                        if (param_assign->Lhs() && param_assign->Rhs()) {
                            std::string param_name;
                            if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                                param_name = std::string(param->VpiName());
                            }
                            
                            if (!param_name.empty()) {
                                if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                                    std::string val_str = std::string(const_val->VpiValue());
                                    RTLIL::Const const_val_rtlil = extract_const_from_value(val_str);
                                    int param_value = const_val_rtlil.as_int();
                                    
                                    // Add to module name in Yosys format
                                    param_interface_type += "\\" + param_name + "=s32'";
                                    for (int i = 31; i >= 0; i--) {
                                        param_interface_type += ((param_value >> i) & 1) ? "1" : "0";
                                    }
                                }
                            }
                        }
                    }
                }
                
                RTLIL::IdString cell_name = "\\" + interface_name;
                // For an interface PORT (e.g. `tcb_lite_if.man tcb_ifu` on
                // rp32 r5p_degu), the interface's signals are already created
                // as wires and the port itself may exist as a wire/cell, so an
                // interface-instance cell of the same name would collide
                // (rtlil count_id assert).  Only add the representative cell
                // when nothing with that name exists yet.
                if (!module->wire(cell_name) && !module->cell(cell_name)) {
                    module->addCell(cell_name, RTLIL::escape_id(param_interface_type));
                    log("UHDM: Created interface cell %s of type %s\n", interface_name.c_str(), param_interface_type.c_str());
                } else {
                    log("UHDM: Interface '%s' already represented (wire/cell exists) — skipping instance cell\n", interface_name.c_str());
                }
            }
            
        }
    } else {
        log("UHDM: Module has no interfaces\n");
    }
    
    if (mode_debug)
        log("UHDM: Finished import_interface_instances\n");
}

// Check if a module uses interface ports
bool UhdmImporter::module_has_interface_ports(const module_inst* uhdm_module) {
    if (!uhdm_module || !uhdm_module->Ports()) {
        return false;
    }
    
    for (auto port : *uhdm_module->Ports()) {
        any* high_conn = port->High_conn();
        if (high_conn && high_conn->UhdmType() == uhdmref_obj) {
            ref_obj* ref = any_cast<ref_obj*>(high_conn);
            any* actual = ref->Actual_group();
            if (actual && actual->UhdmType() == uhdminterface_inst) {
                return true;
            }
        }
    }
    
    return false;
}

// Build interface-aware module name
std::string UhdmImporter::build_interface_module_name(const std::string& base_name, 
                                                     const std::string& param_signature,
                                                     const module_inst* uhdm_module) {
    // Don't modify the module name for interfaces
    // The parameterized name is sufficient
    return param_signature;
}

// Create interface module with specific width
void UhdmImporter::create_interface_module_with_width(const std::string& interface_name, int width) {
    // Build parameterized module name
    std::string param_module_name = "$paramod\\" + interface_name;
    param_module_name += "\\WIDTH=s32'";
    for (int i = 31; i >= 0; i--) {
        param_module_name += ((width >> i) & 1) ? "1" : "0";
    }
    
    RTLIL::IdString mod_id = RTLIL::escape_id(param_module_name);
    
    // Check if this interface module already exists
    if (design->module(mod_id)) {
        log("UHDM: Interface module %s already exists\n", param_module_name.c_str());
        return;
    }
    
    // Create the interface module
    RTLIL::Module* iface_module = design->addModule(mod_id);
    
    // Add interface attributes
    iface_module->attributes[RTLIL::escape_id("hdlname")] = RTLIL::Const(interface_name);
    iface_module->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
    iface_module->attributes[RTLIL::escape_id("dynports")] = RTLIL::Const(1);
    // Note: no src attribute available - interface module is created from parameters only
    
    // Add WIDTH parameter
    RTLIL::IdString param_id = RTLIL::escape_id("WIDTH");
    iface_module->avail_parameters(param_id);
    iface_module->parameter_default_values[param_id] = RTLIL::Const(width, 32);
    
    // Create the interface signals (a, b, c for data_bus_if)
    std::vector<std::string> signal_names = {"a", "b", "c"};
    for (const auto& signal_name : signal_names) {
        iface_module->addWire(RTLIL::escape_id(signal_name), width);
        log("UHDM: Added wire '%s' (width=%d) to interface module\n", signal_name.c_str(), width);
    }
    
    log("UHDM: Created interface module %s\n", param_module_name.c_str());
}

YOSYS_NAMESPACE_END