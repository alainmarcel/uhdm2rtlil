// PeakRDL register-block storage: an UNPACKED struct whose member is an
// unpacked ARRAY of structs, below another struct member, written and read
// per genvar (`field_combo.regs.mtimecmp[i0].low.next`).  Unpatched read_uhdm
// resolved none of these paths ("Could not resolve struct member access").
module dut(input logic clk, input logic arst_n, input logic [1:0] we, input logic [31:0] wd,
           output logic [31:0] q0, output logic [31:0] q1);
    typedef struct {
        logic pad0;
        struct {
            logic [2:0] padc;
            struct {
                struct { logic [31:0] next; logic load_next; } low;
                struct { logic [31:0] next; logic load_next; } high;
            } mtimecmp[2];
            logic padb;
        } regs;
    } field_combo_t;
    field_combo_t field_combo;
    typedef struct {
        struct {
            struct {
                struct { logic [31:0] value; } low;
                struct { logic [31:0] value; } high;
            } mtimecmp[2];
            logic [4:0] pads;
        } regs;
        logic pad1;
    } field_storage_t;
    field_storage_t field_storage;
    for (genvar i0 = 0; i0 < 2; i0++) begin
        always_comb begin
            automatic logic [31:0] next_c;
            automatic logic load_next_c;
            next_c = field_storage.regs.mtimecmp[i0].low.value;
            load_next_c = '0;
            if (we[i0]) begin
                next_c = wd;
                load_next_c = '1;
            end
            field_combo.regs.mtimecmp[i0].low.next = next_c;
            field_combo.regs.mtimecmp[i0].low.load_next = load_next_c;
        end
        always_ff @(posedge clk or negedge arst_n) begin
            if (~arst_n) field_storage.regs.mtimecmp[i0].low.value <= 32'h0;
            else if (field_combo.regs.mtimecmp[i0].low.load_next)
                field_storage.regs.mtimecmp[i0].low.value <= field_combo.regs.mtimecmp[i0].low.next;
        end
    end
    assign q0 = field_storage.regs.mtimecmp[0].low.value;
    assign q1 = field_storage.regs.mtimecmp[1].low.value;
endmodule

