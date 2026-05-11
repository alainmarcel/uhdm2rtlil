// Yosys plugin: extract clock and reset top-level input names from the
// current design.  Used by test/test_sim_equivalence.sh to drive a
// Verilator co-simulation testbench.
//
// Usage:
//   yosys -m extract_clocks_resets.so \
//         -p "read_verilog <file>; hierarchy -check -auto-top;
//             extract_clocks_resets -o ports.txt"
//
// Output format (one entry per line):
//   PORT <name> <width> [input|output|inout]
//   CLOCK <name>
//   RESET <name> <active_high_polarity 0|1>

#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

static bool starts_with(const std::string &s, const std::string &p) {
    return s.size() >= p.size() && s.compare(0, p.size(), p) == 0;
}

struct ExtractClocksResetsPass : public Pass {
    ExtractClocksResetsPass()
        : Pass("extract_clocks_resets",
               "extract clock and reset top-level input names") {}

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        std::string output_file;
        for (size_t i = 1; i < args.size(); i++) {
            if (args[i] == "-o" && i + 1 < args.size()) {
                output_file = args[++i];
            }
        }
        if (output_file.empty())
            log_error("extract_clocks_resets: -o <file> is required\n");

        // Pick the top module
        RTLIL::Module *top = nullptr;
        for (auto mod : design->modules())
            if (mod->get_bool_attribute(ID::top)) { top = mod; break; }
        if (!top) {
            // Fall back to the only / last design module
            for (auto mod : design->modules()) top = mod;
        }
        if (!top)
            log_error("extract_clocks_resets: no module in design\n");

        // Build a map of wire -> name for top-level input ports so we can
        // detect when a clock/reset connection directly reaches one.
        std::set<RTLIL::IdString> top_inputs;
        for (auto wire : top->wires())
            if (wire->port_input) top_inputs.insert(wire->name);

        std::set<RTLIL::IdString> clocks;
        std::map<RTLIL::IdString, bool> resets; // active-high?

        auto cell_is_dff = [](RTLIL::IdString t) {
            // RTLIL-level FF cells
            if (t == ID($dff) || t == ID($dffe) ||
                t == ID($adff) || t == ID($adffe) ||
                t == ID($sdff) || t == ID($sdffe) || t == ID($sdffce) ||
                t == ID($dffsr) || t == ID($dffsre))
                return true;
            // Internal "$_DFF_*_" cell library (post-techmap).  After a
            // synthesised netlist has been written with `write_verilog`
            // and re-read, the cell type comes back as a *public*
            // identifier `\$_DFF_PP0_` etc. — match both.
            std::string s = t.str();
            auto match = [&](const std::string &pfx) {
                return starts_with(s, pfx) || starts_with(s, "\\" + pfx);
            };
            return match("$_DFF_") || match("$_SDFF_") ||
                   match("$_DFFE_") || match("$_DFFSR_") ||
                   match("$_SDFFE_") || match("$_SDFFCE_");
        };

        auto record_top_port = [&](const RTLIL::SigSpec &sig,
                                    std::set<RTLIL::IdString> *clk_out,
                                    std::map<RTLIL::IdString, bool> *rst_out,
                                    bool active_high) {
            for (auto chunk : sig.chunks()) {
                if (!chunk.is_wire()) continue;
                if (top_inputs.count(chunk.wire->name)) {
                    if (clk_out) clk_out->insert(chunk.wire->name);
                    if (rst_out) (*rst_out)[chunk.wire->name] = active_high;
                }
            }
        };

        for (auto cell : top->cells()) {
            if (!cell_is_dff(cell->type)) continue;

            // Clock — try common port names
            RTLIL::SigSpec clk_sig;
            if (cell->hasPort(ID::CLK))      clk_sig = cell->getPort(ID::CLK);
            else if (cell->hasPort(ID::C))   clk_sig = cell->getPort(ID::C);
            record_top_port(clk_sig, &clocks, nullptr, false);

            // Async reset
            if (cell->hasPort(ID::ARST)) {
                bool ah = cell->hasParam(ID::ARST_POLARITY)
                              ? cell->getParam(ID::ARST_POLARITY).as_bool()
                              : true;
                record_top_port(cell->getPort(ID::ARST), nullptr, &resets, ah);
            }
            // For internal $_DFF_PP0_ / $_DFF_PN0_ etc, the active-low/high
            // flag is encoded in the cell type name.  Encoding:
            //   $_DFF_<clk-edge><rst-polarity><reset-value>_
            //   <clk-edge>: P or N
            //   <rst-polarity>: P (active-high) or N (active-low)
            //   <reset-value>: 0 or 1
            // The cell type may also come back as a backslash-prefixed
            // public Verilog identifier (`\$_SDFF_PP0_`) after a
            // round-trip through `write_verilog` / `read_verilog`.
            auto type_str = [&]() {
                std::string s = cell->type.str();
                if (!s.empty() && s[0] == '\\') return s.substr(1);
                return s;
            };
            if (cell->hasPort(ID::R)) {
                std::string s = type_str();
                bool ah = true;
                size_t prefix_len = 0;
                if (starts_with(s, "$_DFF_") || starts_with(s, "$_SDFF_")) {
                    prefix_len = starts_with(s, "$_SDFF_") ? 7 : 6;
                    if (s.size() >= prefix_len + 2)
                        ah = (s[prefix_len + 1] == 'P');
                }
                record_top_port(cell->getPort(ID::R), nullptr, &resets, ah);
            }
            if (cell->hasPort(ID::S)) {
                std::string s = type_str();
                bool ah = true;
                if (starts_with(s, "$_DFFSR_") && s.size() >= 9)
                    ah = (s[6] == 'P');
                record_top_port(cell->getPort(ID::S), nullptr, &resets, ah);
            }
        }

        std::ofstream f(output_file);
        if (!f.is_open())
            log_error("extract_clocks_resets: cannot open %s\n", output_file.c_str());

        // Emit all top-level ports first so the testbench knows the full
        // interface (and their widths) without re-parsing the Verilog.
        for (auto wire : top->wires()) {
            if (!(wire->port_input || wire->port_output)) continue;
            const char *dir = wire->port_input && wire->port_output ? "inout"
                              : wire->port_input ? "input" : "output";
            f << "PORT " << RTLIL::unescape_id(wire->name) << " "
              << wire->width << " " << dir << "\n";
        }
        for (auto clk : clocks)
            f << "CLOCK " << RTLIL::unescape_id(clk) << "\n";
        for (auto &r : resets)
            f << "RESET " << RTLIL::unescape_id(r.first) << " "
              << (r.second ? "1" : "0") << "\n";
        f.close();

        log("extract_clocks_resets: module=%s, ports=%d, clocks=%d, resets=%d -> %s\n",
            log_id(top->name), (int)top->ports.size(),
            (int)clocks.size(), (int)resets.size(), output_file.c_str());
    }
} ExtractClocksResetsPass;

PRIVATE_NAMESPACE_END
