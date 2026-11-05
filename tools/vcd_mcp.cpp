// vcd-mcp: fast, indexed inspector for full-hierarchy VCDs.
//
//  This tool does:
//
//   * mmaps the file and parses it once into per-id, time-sorted
//     (time, value) arrays -- windowed queries are O(log n) binary searches.
//   * packs short VCD id-codes into a uint64 key so the hot value-change loop
//     never allocates while looking up the owning signal.
//   * has a persistent --serve mode (Unix-domain socket): the file is parsed
//     once and held in RAM; subsequent queries connect and return instantly.
//
// CLI is a drop-in match for the Python tool:
//
//   vcd-inspect <vcd> --list   PATTERN
//   vcd-inspect <vcd> --count  PATTERN
//   vcd-inspect <vcd> --signal PATTERN [--signal PATTERN ...] [--from T] [--to T]
//   common: --from T --to T --limit N --full-names
//   pattern: substring by default; prefix with "re:" for ECMAScript regex.
//
// Server:
//   vcd-inspect <vcd> --serve [--sock PATH]      # load once, listen forever
//   vcd-inspect <vcd> --list PATTERN             # auto-connects if a server is
//                                                #   up for this vcd, else loads
//                                                #   in-process (one-shot).
//   --no-server  forces in-process one-shot (skip the socket).
//
// Build: make -C tools   (or: g++ -O3 -march=native -std=c++17 ...)

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <csignal>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <regex>
#include <string>
#include <unordered_map>
#include <vector>

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

// ----------------------------------------------------------------------------
// In-memory model
// ----------------------------------------------------------------------------

struct IdData {
    std::string idcode;            // VCD short code (for display, e.g. "1'")
    int width = 1;
    std::string kind;              // "wire", "reg", ...
    std::vector<uint64_t> t;       // transition times (ps), monotonic ascending
    std::vector<std::string> v;    // formatted value at each transition
};

struct Model {
    std::vector<IdData> ids;                       // one entry per unique id-code
    std::unordered_map<uint64_t, uint32_t> packed; // packed id-code -> ids index
    std::unordered_map<std::string, uint32_t> longids; // id-codes > 9 chars
    std::vector<std::pair<std::string, uint32_t>> names; // full hier name -> ids idx
};

// Pack an id-code (printable ASCII, chars in [33,126]) into a uint64.
// Returns false if too long (>9 chars) to fit; caller uses the string map.
static inline bool pack_id(const char* s, int n, uint64_t& out) {
    if (n > 9) return false;
    uint64_t v = 0;
    for (int i = 0; i < n; i++) {
        unsigned char c = (unsigned char)s[i];
        v = v * 95 + (uint64_t)(c - 32); // c in [33,126] -> [1,94]; 0 = absent
    }
    out = v;
    return true;
}

// ----------------------------------------------------------------------------
// Value formatting (mirror the Python tool's choices)
// ----------------------------------------------------------------------------

// Binary bit-string -> "0x..." if pure 0/1, else the raw bit-string (x/z cases).
static std::string bits_to_value(const char* s, int n) {
    bool pure = true;
    for (int i = 0; i < n; i++) {
        char c = s[i];
        if (c != '0' && c != '1') { pure = false; break; }
    }
    if (!pure) return std::string(s, n); // keep raw (e.g. "10xz1")

    // Convert arbitrary-width binary to hex, no leading zeros.
    std::string hex;
    hex.reserve(n / 4 + 3);
    int start = n % 4;
    int idx = 0;
    auto nibble = [&](int bits, int cnt) {
        int val = 0;
        for (int k = 0; k < cnt; k++) val = (val << 1) | (s[bits + k] - '0');
        return val;
    };
    if (start) {
        int val = nibble(0, start);
        idx = start;
        char d = "0123456789abcdef"[val];
        if (d != '0') hex.push_back(d);
    }
    for (; idx + 4 <= n; idx += 4) {
        int val = nibble(idx, 4);
        char d = "0123456789abcdef"[val];
        if (!hex.empty() || d != '0') hex.push_back(d);
    }
    if (hex.empty()) hex = "0";
    return "0x" + hex;
}

// ----------------------------------------------------------------------------
// Header / name helpers
// ----------------------------------------------------------------------------

static bool valid_bitrange(const std::string& s) {
    // \d+(:\d+)? -- e.g. "31", "31:0"
    if (s.empty()) return false;
    size_t colon = s.find(':');
    auto all_digits = [](const std::string& x) {
        if (x.empty()) return false;
        for (char c : x) if (!isdigit((unsigned char)c)) return false;
        return true;
    };
    if (colon == std::string::npos) return all_digits(s);
    if (s.find(':', colon + 1) != std::string::npos) return false;
    return all_digits(s.substr(0, colon)) && all_digits(s.substr(colon + 1));
}

// Reconstruct a signal name from the $var name tokens, stripping a trailing
// bit-range like "[31:0]" / "[7]" (matches the Python regex behaviour).
static std::string make_name_suffix(const std::vector<std::string>& toks,
                                    size_t first, size_t last /*exclusive*/) {
    std::string suffix;
    for (size_t i = first; i < last; i++) {
        if (!suffix.empty()) suffix.push_back(' ');
        suffix += toks[i];
    }
    if (!suffix.empty() && suffix.back() == ']') {
        size_t lb = suffix.rfind('[');
        if (lb != std::string::npos) {
            std::string inside = suffix.substr(lb + 1, suffix.size() - 1 - (lb + 1));
            if (valid_bitrange(inside)) {
                size_t cut = lb;
                while (cut > 0 && suffix[cut - 1] == ' ') cut--;
                suffix.resize(cut);
            }
        }
    }
    return suffix;
}

// ----------------------------------------------------------------------------
// Parse a VCD into the Model (mmap, single pass)
// ----------------------------------------------------------------------------

static double now_sec() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static bool load_vcd(const char* path, Model& m, bool verbose) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) { perror("open"); return false; }
    struct stat st;
    if (fstat(fd, &st) != 0) { perror("fstat"); close(fd); return false; }
    size_t size = (size_t)st.st_size;
    const char* base = (const char*)mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (base == MAP_FAILED) { perror("mmap"); close(fd); return false; }
    madvise((void*)base, size, MADV_SEQUENTIAL);

    double t0 = now_sec();
    const char* p = base;
    const char* end = base + size;

    m.ids.reserve(1u << 21);
    m.names.reserve(1u << 21);
    m.packed.reserve(1u << 22);

    // ---- header ----
    std::string pref;                 // current scope path "a.b.c"
    std::vector<size_t> pref_len;      // for pop
    std::vector<std::string> toks;

    auto get_idx = [&](const char* s, int n, int width, const std::string& kind) -> uint32_t {
        uint64_t key;
        if (pack_id(s, n, key)) {
            auto it = m.packed.find(key);
            if (it != m.packed.end()) return it->second;
            uint32_t idx = (uint32_t)m.ids.size();
            m.ids.push_back(IdData{std::string(s, n), width, kind, {}, {}});
            m.packed.emplace(key, idx);
            return idx;
        } else {
            std::string k(s, n);
            auto it = m.longids.find(k);
            if (it != m.longids.end()) return it->second;
            uint32_t idx = (uint32_t)m.ids.size();
            m.ids.push_back(IdData{k, width, kind, {}, {}});
            m.longids.emplace(std::move(k), idx);
            return idx;
        }
    };

    bool in_data = false;
    while (p < end) {
        const char* nl = (const char*)memchr(p, '\n', end - p);
        const char* le = nl ? nl : end;
        const char* next = nl ? nl + 1 : end;
        // tokenize
        toks.clear();
        const char* q = p;
        while (q < le) {
            while (q < le && isspace((unsigned char)*q)) q++;
            if (q >= le) break;
            const char* s = q;
            while (q < le && !isspace((unsigned char)*q)) q++;
            toks.emplace_back(s, q - s);
        }
        if (!toks.empty()) {
            const std::string& t0tok = toks[0];
            if (t0tok == "$enddefinitions") { in_data = true; p = next; break; }
            else if (t0tok == "$scope") {
                if (toks.size() >= 3) {
                    pref_len.push_back(pref.size());
                    if (!pref.empty()) pref.push_back('.');
                    pref += toks[2];
                }
            } else if (t0tok == "$upscope") {
                if (!pref_len.empty()) { pref.resize(pref_len.back()); pref_len.pop_back(); }
            } else if (t0tok == "$var") {
                // $var <kind> <width> <idcode> <name...> $end
                if (toks.size() >= 6 && toks.back() == "$end") {
                    const std::string& kind = toks[1];
                    int width = atoi(toks[2].c_str());
                    const std::string& idc = toks[3];
                    std::string suffix = make_name_suffix(toks, 4, toks.size() - 1);
                    std::string full = pref.empty() ? suffix : (pref + "." + suffix);
                    uint32_t idx = get_idx(idc.data(), (int)idc.size(), width, kind);
                    m.names.emplace_back(std::move(full), idx);
                }
            }
        }
        p = next;
    }
    if (!in_data) { munmap((void*)base, size); close(fd); return false; }

    if (verbose)
        fprintf(stderr, "[vcd-inspect] header: %zu names, %zu unique ids (%.1fs)\n",
                m.names.size(), m.ids.size(), now_sec() - t0);

    // ---- value-change data ----
    uint64_t curT = 0;
    auto lookup = [&](const char* s, int n) -> int32_t {
        uint64_t key;
        if (pack_id(s, n, key)) {
            auto it = m.packed.find(key);
            return it == m.packed.end() ? -1 : (int32_t)it->second;
        }
        auto it = m.longids.find(std::string(s, n));
        return it == m.longids.end() ? -1 : (int32_t)it->second;
    };

    while (p < end) {
        const char* nl = (const char*)memchr(p, '\n', end - p);
        const char* le = nl ? nl : end;
        const char* next = nl ? nl + 1 : end;
        if (le > p && le[-1] == '\r') le--;
        if (le == p) { p = next; continue; }
        char c = *p;
        if (c == '#') {
            uint64_t v = 0;
            for (const char* q = p + 1; q < le; q++) {
                if (q[0] < '0' || q[0] > '9') break;
                v = v * 10 + (q[0] - '0');
            }
            curT = v;
        } else if (c == 'b' || c == 'B') {
            const char* sp = p + 1;
            while (sp < le && *sp != ' ') sp++;
            int bn = (int)(sp - (p + 1));
            const char* idp = sp;
            while (idp < le && *idp == ' ') idp++;
            int idn = (int)(le - idp);
            if (idn > 0) {
                int32_t idx = lookup(idp, idn);
                if (idx >= 0) {
                    m.ids[idx].t.push_back(curT);
                    m.ids[idx].v.push_back(bits_to_value(p + 1, bn));
                }
            }
        } else if (c == '0' || c == '1' || c == 'x' || c == 'z' || c == 'X' || c == 'Z') {
            int idn = (int)(le - (p + 1));
            if (idn > 0) {
                int32_t idx = lookup(p + 1, idn);
                if (idx >= 0) {
                    m.ids[idx].t.push_back(curT);
                    m.ids[idx].v.emplace_back(1, c);
                }
            }
        }
        // 'r'/'R' reals and '$...' directives are ignored (as in the Python tool).
        p = next;
    }

    if (verbose) {
        size_t total = 0;
        for (auto& id : m.ids) total += id.t.size();
        fprintf(stderr, "[vcd-inspect] data: %zu transitions, end @ %lu ps (%.1fs total)\n",
                total, (unsigned long)curT, now_sec() - t0);
    }
    munmap((void*)base, size);
    close(fd);
    return true;
}

// ----------------------------------------------------------------------------
// Query options + matching
// ----------------------------------------------------------------------------

enum class Mode { NONE, LIST, COUNT, SIGNAL, CHANGED };

struct Options {
    Mode mode = Mode::NONE;
    std::string list_pat;
    std::string count_pat;
    std::string changed_pat;
    std::vector<std::string> signals;
    bool has_from = false, has_to = false;
    uint64_t from = 0, to = 0;
    int limit = 40;
    bool full_names = false;
};

static bool pattern_match(const std::string& pat, const std::string& hay) {
    if (pat.rfind("re:", 0) == 0) {
        try {
            std::regex re(pat.substr(3));
            return std::regex_search(hay, re);
        } catch (...) { return false; }
    }
    return hay.find(pat) != std::string::npos;
}

static bool is_regex(const std::string& pat) { return pat.rfind("re:", 0) == 0; }

// ----------------------------------------------------------------------------
// Query execution (writes to `out`)
// ----------------------------------------------------------------------------

static void appendf(std::string& out, const char* fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (n < 0) return;
    if (n < (int)sizeof(buf)) { out.append(buf, n); return; }
    std::vector<char> big(n + 1);
    va_start(ap, fmt);
    vsnprintf(big.data(), big.size(), fmt, ap);
    va_end(ap);
    out.append(big.data(), n);
}

// Resolve a pattern to (name, ids-index) pairs; mirrors the Python guard rails.
static bool resolve(const Model& m, const std::string& pat,
                    std::vector<std::pair<std::string, uint32_t>>& hits,
                    std::string& err) {
    for (auto& nv : m.names)
        if (pattern_match(pat, nv.first)) hits.emplace_back(nv.first, nv.second);
    if (hits.empty()) { err = "error: no signal matches '" + pat + "'"; return false; }
    if (hits.size() > 8 && !is_regex(pat)) {
        err = "error: pattern '" + pat + "' matches " + std::to_string(hits.size()) +
              " signals; refine or use --list to inspect";
        return false;
    }
    return true;
}

static void cmd_list(const Model& m, const Options& o, std::string& out) {
    std::vector<std::pair<std::string, uint32_t>> hits;
    for (auto& nv : m.names)
        if (pattern_match(o.list_pat, nv.first)) hits.push_back(nv);
    std::sort(hits.begin(), hits.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });
    hits.erase(std::unique(hits.begin(), hits.end(),
                           [](const auto& a, const auto& b) { return a.first == b.first; }),
               hits.end());
    int shown = 0;
    for (auto& h : hits) {
        if (shown >= o.limit) break;
        const IdData& id = m.ids[h.second];
        appendf(out, "  [%s %3d]  %s    (id=%s)\n", id.kind.c_str(), id.width,
                h.first.c_str(), id.idcode.c_str());
        shown++;
    }
    if ((int)hits.size() > o.limit)
        appendf(out, "  ... %d more (use --limit to see)\n", (int)hits.size() - o.limit);
    appendf(out, "\n%zu signal(s) matched.\n", hits.size());
}

// Lower-bound index of first transition with time >= t.
static size_t lb_time(const std::vector<uint64_t>& times, uint64_t t) {
    return (size_t)(std::lower_bound(times.begin(), times.end(), t) - times.begin());
}

static void cmd_count(const Model& m, const Options& o, std::string& out) {
    std::vector<std::pair<std::string, uint32_t>> hits;
    std::string err;
    if (!resolve(m, o.count_pat, hits, err)) { out = err + "\n"; return; }
    for (auto& h : hits) {
        const IdData& id = m.ids[h.second];
        size_t i = o.has_from ? lb_time(id.t, o.from) : 0;
        long cnt = 0;
        long long first_t = -1, last_t = -1;
        const std::string* last_v = nullptr;
        std::vector<std::string> uniq;
        for (; i < id.t.size(); i++) {
            if (o.has_to && id.t[i] > o.to) break;
            const std::string& v = id.v[i];
            if (last_v && *last_v == v) continue;
            cnt++;
            last_v = &v;
            if (std::find(uniq.begin(), uniq.end(), v) == uniq.end()) uniq.push_back(v);
            if (first_t < 0) first_t = (long long)id.t[i];
            last_t = (long long)id.t[i];
        }
        appendf(out, "  [%s %d]  %s\n", id.kind.c_str(), id.width, h.first.c_str());
        appendf(out, "    transitions: %ld\n", cnt);
        if (first_t < 0)
            appendf(out, "    first @ (none), last @ (none)\n");
        else
            appendf(out, "    first @ %lld ps, last @ %lld ps\n", first_t, last_t);
        appendf(out, "    unique values: %zu", uniq.size());
        if (uniq.size() <= 8) {
            std::sort(uniq.begin(), uniq.end());
            out += "  -> [";
            for (size_t k = 0; k < uniq.size(); k++) {
                if (k) out += ", ";
                out += "'" + uniq[k] + "'";
            }
            out += "]";
        }
        out += "\n";
    }
}

static void cmd_signal(const Model& m, const Options& o, std::string& out) {
    // Resolve every --signal pattern; build the id set + id->name map.
    std::vector<uint32_t> idxs;
    std::unordered_map<uint32_t, std::string> id_name;
    for (auto& pat : o.signals) {
        std::vector<std::pair<std::string, uint32_t>> hits;
        std::string err;
        if (!resolve(m, pat, hits, err)) { out = err + "\n"; return; }
        for (auto& h : hits) {
            if (id_name.find(h.second) == id_name.end()) idxs.push_back(h.second);
            id_name[h.second] = h.first; // last wins, like the Python dict
        }
    }

    // Per-id windowed + deduped change list, then merge by time.
    struct Row { uint64_t t; uint32_t idx; const std::string* v; };
    std::vector<Row> rows;
    for (uint32_t idx : idxs) {
        const IdData& id = m.ids[idx];
        size_t i = o.has_from ? lb_time(id.t, o.from) : 0;
        const std::string* last_v = nullptr;
        for (; i < id.t.size(); i++) {
            if (o.has_to && id.t[i] > o.to) break;
            const std::string& v = id.v[i];
            if (last_v && *last_v == v) continue;
            last_v = &v;
            rows.push_back(Row{id.t[i], idx, &v});
        }
    }
    std::stable_sort(rows.begin(), rows.end(),
                     [](const Row& a, const Row& b) { return a.t < b.t; });

    int shown = 0;
    for (auto& r : rows) {
        if (shown >= o.limit) { appendf(out, "  ... stop at --limit=%d\n", o.limit); break; }
        const std::string& name = id_name[r.idx];
        std::string disp;
        if (o.full_names) disp = name;
        else { size_t dot = name.rfind('.'); disp = (dot == std::string::npos) ? name : name.substr(dot + 1); }
        appendf(out, "  %12llu ps  %-28s = %s\n",
                (unsigned long long)r.t, disp.c_str(), r.v->c_str());
        shown++;
    }
}

// List signals (optionally filtered by pattern) that have >=1 transition in
// [from,to]. The diff primitive for "which flops fire in this gap". Sorted by
// the time of their first in-window change.
static void cmd_changed(const Model& m, const Options& o, std::string& out) {
    if (!o.has_from || !o.has_to) {
        out = "error: --changed requires both --from and --to\n";
        return;
    }
    bool filter = !o.changed_pat.empty() && o.changed_pat != "*";
    struct Hit { uint64_t first_t; long cnt; uint32_t idx; const std::string* name; };
    std::vector<Hit> hits;
    std::vector<uint32_t> seen_dedup; // dedup ids reported once even if aliased
    std::unordered_map<uint32_t, const std::string*> reported;
    for (auto& nv : m.names) {
        if (filter && !pattern_match(o.changed_pat, nv.first)) continue;
        if (reported.count(nv.second)) continue;
        const IdData& id = m.ids[nv.second];
        size_t i = lb_time(id.t, o.from);
        if (i >= id.t.size() || id.t[i] > o.to) continue;
        long cnt = 0;
        const std::string* lv = nullptr;
        uint64_t first_t = id.t[i];
        for (size_t j = i; j < id.t.size() && id.t[j] <= o.to; j++) {
            if (lv && *lv == id.v[j]) continue;
            lv = &id.v[j];
            cnt++;
        }
        if (cnt == 0) continue;
        reported[nv.second] = &nv.first;
        hits.push_back(Hit{first_t, cnt, nv.second, &nv.first});
    }
    std::sort(hits.begin(), hits.end(), [](const Hit& a, const Hit& b) {
        if (a.first_t != b.first_t) return a.first_t < b.first_t;
        return *a.name < *b.name;
    });
    int shown = 0;
    for (auto& h : hits) {
        if (shown >= o.limit) break;
        const IdData& id = m.ids[h.idx];
        appendf(out, "  %12llu ps  [%s %3d] x%-4ld  %s\n",
                (unsigned long long)h.first_t, id.kind.c_str(), id.width, h.cnt,
                h.name->c_str());
        shown++;
    }
    if ((int)hits.size() > o.limit)
        appendf(out, "  ... %d more (use --limit)\n", (int)hits.size() - o.limit);
    appendf(out, "\n%zu signal(s) changed in [%llu, %llu] ps.\n", hits.size(),
            (unsigned long long)o.from, (unsigned long long)o.to);
}

static std::string run_query(const Model& m, const Options& o) {
    std::string out;
    switch (o.mode) {
        case Mode::LIST:    cmd_list(m, o, out); break;
        case Mode::COUNT:   cmd_count(m, o, out); break;
        case Mode::SIGNAL:  cmd_signal(m, o, out); break;
        case Mode::CHANGED: cmd_changed(m, o, out); break;
        default: out = "error: no query mode (use --list/--count/--signal/--changed)\n";
    }
    return out;
}

// ----------------------------------------------------------------------------
// CLI parsing
// ----------------------------------------------------------------------------

static uint64_t parse_time(const char* s) {
    std::string clean;
    for (const char* q = s; *q; q++) if (*q != '_') clean.push_back(*q);
    return strtoull(clean.c_str(), nullptr, 10);
}

// Parse only the query-relevant flags (used both for the local CLI and to
// reconstruct a request on the server side).
static bool parse_query(const std::vector<std::string>& a, Options& o, std::string& err) {
    for (size_t i = 0; i < a.size(); i++) {
        const std::string& f = a[i];
        auto need = [&](const char* name) -> const std::string* {
            if (i + 1 >= a.size()) { err = std::string("error: ") + name + " needs a value"; return nullptr; }
            return &a[++i];
        };
        if (f == "--list") { auto* v = need("--list"); if (!v) return false; o.mode = Mode::LIST; o.list_pat = *v; }
        else if (f == "--changed") { auto* v = need("--changed"); if (!v) return false; o.mode = Mode::CHANGED; o.changed_pat = *v; }
        else if (f == "--count") { auto* v = need("--count"); if (!v) return false; o.mode = Mode::COUNT; o.count_pat = *v; }
        else if (f == "--signal") { auto* v = need("--signal"); if (!v) return false; o.mode = Mode::SIGNAL; o.signals.push_back(*v); }
        else if (f == "--from") { auto* v = need("--from"); if (!v) return false; o.has_from = true; o.from = parse_time(v->c_str()); }
        else if (f == "--to") { auto* v = need("--to"); if (!v) return false; o.has_to = true; o.to = parse_time(v->c_str()); }
        else if (f == "--limit") { auto* v = need("--limit"); if (!v) return false; o.limit = atoi(v->c_str()); }
        else if (f == "--full-names") { o.full_names = true; }
        else { err = "error: unknown query flag '" + f + "'"; return false; }
    }
    return true;
}

// Canonical token form of a query, for sending to the server.
static std::vector<std::string> query_to_tokens(const Options& o) {
    std::vector<std::string> t;
    if (o.mode == Mode::LIST) { t.push_back("--list"); t.push_back(o.list_pat); }
    else if (o.mode == Mode::CHANGED) { t.push_back("--changed"); t.push_back(o.changed_pat); }
    else if (o.mode == Mode::COUNT) { t.push_back("--count"); t.push_back(o.count_pat); }
    else if (o.mode == Mode::SIGNAL) for (auto& s : o.signals) { t.push_back("--signal"); t.push_back(s); }
    if (o.has_from) { t.push_back("--from"); t.push_back(std::to_string(o.from)); }
    if (o.has_to) { t.push_back("--to"); t.push_back(std::to_string(o.to)); }
    t.push_back("--limit"); t.push_back(std::to_string(o.limit));
    if (o.full_names) t.push_back("--full-names");
    return t;
}

// ----------------------------------------------------------------------------
// Socket plumbing (length-prefixed framing)
// ----------------------------------------------------------------------------

static uint64_t fnv1a(const std::string& s) {
    uint64_t h = 1469598103934665603ULL;
    for (unsigned char c : s) { h ^= c; h *= 1099511628211ULL; }
    return h;
}

static std::string default_sock(const char* vcd) {
    char real[4096];
    std::string abs = realpath(vcd, real) ? std::string(real) : std::string(vcd);
    char buf[64];
    snprintf(buf, sizeof(buf), "/tmp/vcdq_%016lx.sock", (unsigned long)fnv1a(abs));
    return buf;
}

static bool read_n(int fd, void* buf, size_t n) {
    char* p = (char*)buf;
    while (n) {
        ssize_t r = read(fd, p, n);
        if (r <= 0) return false;
        p += r; n -= (size_t)r;
    }
    return true;
}
static bool write_n(int fd, const void* buf, size_t n) {
    const char* p = (const char*)buf;
    while (n) {
        ssize_t r = write(fd, p, n);
        if (r <= 0) return false;
        p += r; n -= (size_t)r;
    }
    return true;
}

static bool send_tokens(int fd, const std::vector<std::string>& toks) {
    uint32_t n = (uint32_t)toks.size();
    if (!write_n(fd, &n, 4)) return false;
    for (auto& s : toks) {
        uint32_t len = (uint32_t)s.size();
        if (!write_n(fd, &len, 4)) return false;
        if (len && !write_n(fd, s.data(), len)) return false;
    }
    return true;
}
static bool recv_tokens(int fd, std::vector<std::string>& toks) {
    uint32_t n;
    if (!read_n(fd, &n, 4)) return false;
    toks.resize(n);
    for (uint32_t i = 0; i < n; i++) {
        uint32_t len;
        if (!read_n(fd, &len, 4)) return false;
        toks[i].resize(len);
        if (len && !read_n(fd, &toks[i][0], len)) return false;
    }
    return true;
}

// ----------------------------------------------------------------------------
// Server
// ----------------------------------------------------------------------------

static int run_server(const char* vcd, const std::string& sockpath) {
    Model m;
    fprintf(stderr, "[vcd-inspect] loading %s ...\n", vcd);
    if (!load_vcd(vcd, m, true)) { fprintf(stderr, "load failed\n"); return 1; }

    int sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) { perror("socket"); return 1; }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (sockpath.size() >= sizeof(addr.sun_path)) { fprintf(stderr, "sock path too long\n"); return 1; }
    strncpy(addr.sun_path, sockpath.c_str(), sizeof(addr.sun_path) - 1);
    unlink(sockpath.c_str());
    if (bind(sfd, (struct sockaddr*)&addr, sizeof(addr)) != 0) { perror("bind"); return 1; }
    if (listen(sfd, 16) != 0) { perror("listen"); return 1; }
    signal(SIGPIPE, SIG_IGN);
    fprintf(stderr, "[vcd-inspect] ready, serving on %s (Ctrl-C to stop)\n", sockpath.c_str());

    for (;;) {
        int cfd = accept(sfd, nullptr, nullptr);
        if (cfd < 0) { if (errno == EINTR) continue; perror("accept"); break; }
        std::vector<std::string> toks;
        if (recv_tokens(cfd, toks)) {
            Options o;
            std::string err, resp;
            if (parse_query(toks, o, err)) resp = run_query(m, o);
            else resp = err + "\n";
            uint64_t len = resp.size();
            write_n(cfd, &len, 8);
            write_n(cfd, resp.data(), resp.size());
        }
        close(cfd);
    }
    close(sfd);
    unlink(sockpath.c_str());
    return 0;
}

// Try to satisfy a query via a running server. Returns true on success.
static bool try_client(const std::string& sockpath, const Options& o) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return false;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sockpath.c_str(), sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) { close(fd); return false; }
    if (!send_tokens(fd, query_to_tokens(o))) { close(fd); return false; }
    uint64_t len;
    if (!read_n(fd, &len, 8)) { close(fd); return false; }
    std::string resp(len, '\0');
    if (len && !read_n(fd, &resp[0], len)) { close(fd); return false; }
    close(fd);
    fwrite(resp.data(), 1, resp.size(), stdout);
    return true;
}

// ----------------------------------------------------------------------------
// main
// ----------------------------------------------------------------------------

static void usage() {
    fprintf(stderr,
        "usage: vcd-inspect <vcd> [--serve] [--sock PATH] [--no-server]\n"
        "                   (--list PAT | --count PAT | --signal PAT [--signal PAT ...]\n"
        "                    | --changed PAT --from T --to T)\n"
        "                   [--from T] [--to T] [--limit N] [--full-names]\n"
        "  --changed PAT: signals matching PAT with >=1 transition in [from,to]\n"
        "                 (PAT '*' or empty = all signals).\n"
        "  pattern: substring by default; prefix 're:' for regex.\n");
}

int main(int argc, char** argv) {
    std::string vcd, sockpath;
    bool serve = false, no_server = false, have_sock = false;
    std::vector<std::string> query_args;

    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "--serve") serve = true;
        else if (a == "--no-server") no_server = true;
        else if (a == "--sock") { if (i + 1 >= argc) { usage(); return 2; } sockpath = argv[++i]; have_sock = true; }
        else if (a == "-h" || a == "--help") { usage(); return 0; }
        else if (!a.empty() && a[0] == '-') {
            // query flag (with its value, if any) -- forward to the query parser
            query_args.push_back(a);
            if ((a == "--list" || a == "--count" || a == "--signal" || a == "--changed" ||
                 a == "--from" || a == "--to" || a == "--limit") && i + 1 < argc)
                query_args.push_back(argv[++i]);
        } else {
            if (vcd.empty()) vcd = a;
            else { fprintf(stderr, "error: unexpected argument '%s'\n", a.c_str()); return 2; }
        }
    }

    if (vcd.empty()) { usage(); return 2; }
    if (!have_sock) sockpath = default_sock(vcd.c_str());

    if (serve) return run_server(vcd.c_str(), sockpath);

    Options o;
    std::string err;
    if (!parse_query(query_args, o, err)) { fprintf(stderr, "%s\n", err.c_str()); return 2; }
    if (o.mode == Mode::NONE) { usage(); return 2; }

    if (!no_server && try_client(sockpath, o)) return 0;

    // One-shot fallback: load in-process.
    if (!no_server)
        fprintf(stderr, "[vcd-inspect] no server on %s; loading in-process "
                        "(start one with: vcd-inspect %s --serve)\n",
                sockpath.c_str(), vcd.c_str());
    Model m;
    if (!load_vcd(vcd.c_str(), m, false)) { fprintf(stderr, "load failed\n"); return 1; }
    std::string out = run_query(m, o);
    fwrite(out.data(), 1, out.size(), stdout);
    return 0;
}
