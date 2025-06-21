#include "kernel/register.h"
#include "kernel/log.h"
#include "kernel/rtlil.h"

#include <uhdm/uhdm.h>
#include <uhdm/Serializer.h>
#include <uhdm/vpi_user.h>

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

using namespace UHDM;

struct ReadUHDMPass : public Frontend {
    ReadUHDMPass() : Frontend("read_uhdm", "read UHDM design") {}

    void help() override {
        log("\n");
        log("    read_uhdm <filename>\n");
        log("\n");
        log("Read a UHDM design file (created by Surelog) into Yosys.\n");
        log("\n");
    }

    void execute(std::istream*, std::string filename, const std::vector<std::string>& args) override {
        log_header(design, "Executing UHDM frontend.\n");

        if (args.size() != 2)
            log_cmd_error("Usage: read_uhdm <uhdm_file>\n");

        filename = args[1];
        log("Reading UHDM file: %s\n", filename.c_str());

        Serializer serializer;
        std::vector<vpiHandle> handles;
        Design* uhdm_design = UHDM::restore(filename, &serializer, handles);

        if (!uhdm_design)
            log_error("Failed to restore UHDM file.\n");

        if (!uhdm_design->AllModules())
            log_error("No modules found in UHDM design.\n");

        for (const Module* uhdm_mod : *uhdm_design->AllModules()) {
            std::string modname = uhdm_mod->VpiName();
            RTLIL::IdString mod_id = RTLIL::escape_id(modname);
            RTLIL::Module* yosys_mod = design->addModule(mod_id);

            // Ports
            if (uhdm_mod->Ports()) {
                for (auto port : *uhdm_mod->Ports()) {
                    std::string portname = port->VpiName();
                    int direction = port->VpiDirection();

                    RTLIL::Wire* w = yosys_mod->addWire(RTLIL::escape_id(portname), 1);

                    if (direction == vpiInput)
                        w->port_input = true;
                    else if (direction == vpiOutput)
                        w->port_output = true;
                    else if (direction == vpiInout) {
                        w->port_input = true;
                        w->port_output = true;
                    }

                    w->port_id = yosys_mod->wires_.size();
                }
            }

            // Nets
            if (uhdm_mod->Nets()) {
                for (auto net : *uhdm_mod->Nets()) {
                    std::string netname = net->VpiName();
                    if (!yosys_mod->wires_.count(RTLIL::escape_id(netname)))
                        yosys_mod->addWire(RTLIL::escape_id(netname), 1);
                }
            }

            // Simple assigns
            if (uhdm_mod->Cont_assigns()) {
                for (auto assign : *uhdm_mod->Cont_assigns()) {
                    const std::string lhs = assign->Lhs()->VpiName();
                    const std::string rhs = assign->Rhs()->VpiName();

                    RTLIL::SigSpec lhs_sig = yosys_mod->wires_[RTLIL::escape_id(lhs)];
                    RTLIL::SigSpec rhs_sig = yosys_mod->wires_[RTLIL::escape_id(rhs)];

                    yosys_mod->connect(lhs_sig, rhs_sig);
                }
            }

            if (uhdm_mod->Process_stmts()) {
                for (auto process : *uhdm_mod->Process_stmts()) {
                    int proc_type = process->VpiType(); // vpiAlways, vpiAlwaysComb, etc.
                    RTLIL::Process* yosys_proc = new RTLIL::Process;
                    yosys_mod->processes[NEW_ID] = yosys_proc;

                    // Handle sensitivity (only for always_ff for now)
                    if (proc_type == vpiAlwaysFF) {
                        RTLIL::SyncRule sync;
                        sync.type = RTLIL::SyncType::STp;

                        // Try to get clock edge
                        auto sens_list = process->Stmt()->Sensitivity_list();
                        if (sens_list) {
                            for (auto sens : *sens_list) {
                                if (sens->VpiType() == vpiNet) {
                                    sync.signal = yosys_mod->wires_[RTLIL::escape_id(sens->VpiName())];
                                }
                            }
                        }

                        // Body
                        if (auto stmt = process->Stmt()) {
                            if (stmt->VpiType() == vpiBegin) {
                                for (auto s : *stmt->Stmt()) {
                                    if (s->VpiType() == vpiBlockingAssign || s->VpiType() == vpiNonBlockingAssign) {
                                        auto lhs = s->Lhs()->VpiName();
                                        auto rhs = s->Rhs()->VpiName();
                                        sync.actions.push_back(RTLIL::SigSig(
                                            yosys_mod->wires_[RTLIL::escape_id(lhs)],
                                            yosys_mod->wires_[RTLIL::escape_id(rhs)]
                                        ));
                                    }
                                }
                            }
                        }

                        yosys_proc->syncs.push_back(sync);
                    }

                    // Handle always_comb as combinational process
                    else if (proc_type == vpiAlwaysComb || proc_type == vpiAlways) {
                        if (auto stmt = process->Stmt()) {
                            if (stmt->VpiType() == vpiBegin) {
                                for (auto s : *stmt->Stmt()) {
                                    if (s->VpiType() == vpiBlockingAssign) {
                                        auto lhs = s->Lhs()->VpiName();
                                        auto rhs = s->Rhs()->VpiName();

                                        RTLIL::SigSig assign(
                                            yosys_mod->wires_[RTLIL::escape_id(lhs)],
                                            yosys_mod->wires_[RTLIL::escape_id(rhs)]
                                        );

                                        yosys_proc->root_case.actions.push_back(assign);
                                    }
                                }
                            }
                        }
                    }

                    // NOTE: Add support for nested if/case/loops later
                }
            }
        }
    }
};

PRIVATE_NAMESPACE_END
YOSYS_NAMESPACE_BEGIN
YOSYS_FRONTEND(ReadUHDMPass, "read_uhdm")
YOSYS_NAMESPACE_END
