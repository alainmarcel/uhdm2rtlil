//EE382M-Verification of Digital Systems
//Lab 4 - Formal Property Verification
//
//
//Modules - apb_props and Wrapper
//SystemVerilog Properties for the module - arbiter_top
`include "rv32_opcodes.v"

module s2qed(
  input clk,
  input rstn,
  input [31:0] cpu0_inst,
  input [31:0] cpu1_inst,
  input [31:0] cpu0_reg[31:0],
  input [31:0] cpu1_reg[31:0],
  input [3:0] cpu0_state,
  input [3:0] cpu1_state,
  input is_illisn0,
  input is_illisn1,
  input [4:0] cpu0_rs1i,
  input [4:0] cpu1_rs1i,
  input [4:0] cpu0_rs2i,
  input [4:0] cpu1_rs2i,
  input [4:0] cpu0_rdi,
  input [4:0] cpu1_rdi,
  input [4:0] cpu0_imm,
  input [4:0] cpu1_imm,
  input [4:0] cpu0_codif,
  input [4:0] cpu1_codif
);
parameter S0_fetch = 0, S1_decode = 1, S2_exec = 2, S4_trap = 4;

// ASSUMPTIONS
//property p_S2QED_NO_ILLISN(is_illisn, state);
//	@(posedge clk)
//	state == S1_decode |-> !is_illisn;
//endproperty
//asm_S2QED_NO_ILLISN0: assume property(p_S2QED_NO_ILLISN(is_illisn0, cpu0_state));
//asm_S2QED_NO_ILLISN1: assume property(p_S2QED_NO_ILLISN(is_illisn1, cpu1_state));



property p_S2QED_MAPPED_VAL(inp0, inp1);
	@(posedge clk) 
	inp0 == reg_map(inp1);
endproperty

property p_S2QED_SAME_VAL(inp0, inp1);
	@(posedge clk) 
	inp0 == inp1;
endproperty
asm_S2QED_MAPPED_VAL_rs1i: assume property(p_S2QED_MAPPED_VAL(cpu0_rs1i,cpu1_rs1i));
asm_S2QED_MAPPED_VAL_rs2i: assume property(p_S2QED_MAPPED_VAL(cpu0_rs2i,cpu1_rs2i));
asm_S2QED_MAPPED_VAL_rdi: assume property(p_S2QED_MAPPED_VAL(cpu0_rdi,cpu1_rdi));
asm_S2QED_SAME_VAL_imm: assume property(p_S2QED_SAME_VAL(cpu0_imm,cpu1_imm));
asm_S2QED_SAME_VAL_codif: assume property(p_S2QED_SAME_VAL(cpu0_codif,cpu1_codif));



property p_S2QED_SAME_STATE();
	@(posedge clk)
	cpu0_state == cpu1_state;	
endproperty
// not sure if this should be assumed or asserted? should only be true after reset?
asm_S2QED_SAME_STATE: assume property(p_S2QED_SAME_STATE());

// ASSERTIONS
property p_S2QED_SAME_REG_N_STATE(state,num);
	@(posedge clk)
	((cpu0_state == cpu1_state) && (cpu0_state == state)) |=> cpu0_reg[num] == cpu1_reg[reg_map(num)];
endproperty //s2qed

generate
for (genvar i = 0; i < 32; i++) begin
  asm_S2QED_SAME_REG_N_STATE: assume property(p_S2QED_SAME_REG_N_STATE(S0_fetch, i));
end
endgenerate

generate
for (genvar i = 0; i < 32; i++) begin
  ast_S2QED_SAME_REG_N_STATE: assert property(p_S2QED_SAME_REG_N_STATE(S2_exec, i));
end
endgenerate



//   /*
// * useful signals that decode th instruction
// * */ 
    wire [6:0] cpu0_opcode;
    wire [6:0] cpu1_opcode;
//
//    wire [6:0] cpu0_funct7;
//    wire [6:0] cpu1_funct7;
//
//    wire [2:0] cpu0_funct3;
//    wire [2:0] cpu1_funct3;
//
//    wire [11:0] cpu0_imm12;
//    wire [11:0] cpu1_imm12;
//
//    wire [4:0] cpu0_rs1;
//    wire [4:0] cpu1_rs1;
//    
//    wire [4:0] cpu0_rs2;
//    wire [4:0] cpu1_rs2;
//
//    wire [4:0] cpu0_rd;
//    wire [4:0] cpu1_rd;
//
    assign cpu0_opcode = cpu0_inst[6:0];
    assign cpu1_opcode = cpu1_inst[6:0];
//
//    assign cpu0_funct7 = cpu0_inst[31:25];
//    assign cpu1_funct7 = cpu1_inst[31:25];
//
//    assign cpu0_funct3 = cpu0_inst[14:12];
//    assign cpu1_funct3 = cpu1_inst[14:12];
//
//    assign cpu0_imm12 = cpu0_inst[31:20];
//    assign cpu1_imm12 = cpu1_inst[31:20];
//
//    assign cpu0_rs1 = cpu0_inst[19:15];
//    assign cpu1_rs1 = cpu1_inst[19:15];
//
//    assign cpu0_rs2 = cpu0_inst[24:20];
//    assign cpu1_rs2 = cpu1_inst[24:20];
//
//    assign cpu0_rd = cpu0_inst[11:7];
//    assign cpu1_rd = cpu1_inst[11:7];
//
//
/*
 * function describing the register map
 * */
    function bit [4:0] reg_map(
        input bit [4:0] orig_reg
    );
        case (orig_reg)
            0:  reg_map = 0;
            1:  reg_map = 12;
            2:  reg_map = 11;
            3:  reg_map = 10;
            4:  reg_map = 9;
            5:  reg_map = 8;
            6:  reg_map = 7;
            7:  reg_map = 6;
            8:  reg_map = 5;
            9:  reg_map = 4;
            10: reg_map = 3;
            11: reg_map = 2;
            12: reg_map = 13;
            13: reg_map = 1;
            14: reg_map = 30;
            15: reg_map = 29;
            16: reg_map = 28;
            17: reg_map = 27;
            18: reg_map = 26;
            19: reg_map = 25;
            20: reg_map = 24;
            21: reg_map = 23;
            22: reg_map = 22;
            23: reg_map = 21;
            24: reg_map = 20;
            25: reg_map = 19;
            26: reg_map = 18;
            27: reg_map = 17;
            28: reg_map = 16;
            29: reg_map = 15;
            30: reg_map = 14;
            31: reg_map = 31;
        endcase    
    endfunction
//
//
///*
// * PROPERTY DEFINITIONS
// * */
//
//
//    property equal_to(ina, inb);
//        ina == inb;
//    endproperty
//    
//    property conditioned_equal_to(cond, ina, inb);
//        cond |-> ina == inb;
//    endproperty
//
     property allow_opcodes(opcode);
	 @(posedge clk)
         opcode == `RV32_OP      ||
         opcode == `RV32_OP_IMM;
     endproperty
     asm_SQ2ED_ALLOW_OPCODES0: assume property(allow_opcodes(cpu0_opcode));
 //    asm_SQ2ED_ALLOW_OPCODES1: assume property(allow_opcodes(cpu1_opcode));
// //    /*
// * used to ensure that rd and rs1 are mapped according to the above defined
// * function
// * */
//    property reg_map_forced(cpu0_regs, cpu1_regs);
//        cpu1_regs == reg_map(cpu0_regs);
//    endproperty
//
//    /*
// * used to ensure register map for rs2 in appropriate cases
// * */
//    property reg_map_conditioned(cond, cpu0_regs, cpu1_regs);
//        cond
//        |->
//        cpu1_regs == reg_map(cpu0_regs);
//    endproperty
//
//    /*
// * limits funct3 to appropriate values for a particular opcode
// * */
//    /*
// * NOT IMPLEMENTED:
// *  because funct3 is allowed to be any value for the two opcodes we are using
// *  */
//
//    /*
// * limits funct7 to 0 for appropriate cases
// * */
//    property funct7_limit_0(op,f3,f7);
//        (op == `RV32_OP_IMM && f3 == `RV32_FUNCT3_SLL) ||
//        (op == `RV32_OP &&
//        (f3 == `RV32_FUNCT3_SLL || f3 == `RV32_FUNCT3_SLT || f3 == `RV32_FUNCT3_SLTU || f3 == `RV32_FUNCT3_XOR || f3 == `RV32_FUNCT3_OR || f3 == `RV32_FUNCT3_AND))
//        |->
//        (f7 == 0);
//    endproperty
//
//    /*
// * limits funct7 to 0 OR 0100000, as appropriate
// * */
//    property funct7_limit_2(op,f3,f7);
//        (op == `RV32_OP_IMM && f3 == `RV32_FUNCT3_SRA_SRL) || 
//        (op == `RV32_OP &&
//        (f3 == `RV32_FUNCT3_ADD_SUB || f3 == `RV32_FUNCT3_SRA_SRL))
//        |->
//        (f7 == 0 || f7 == 7'b0100000);
//    endproperty
//
//    /*
// * limits imm value to shift sizes as appropriate
// *
// * REMOVED: because the limits on funct7 should already enforce this
// * */
///*
//    property imm12_limit_shft(op,f3,imm);
//        (op == `RV32_OP_IMM && (f3 == `RV32_FUNCT3_SRA_SRL || f3 == `RV32_FUNCT3_SLL))
//        |->
//        (imm[11:5] == 0);
//    endproperty
//*/
//
//
//
//
//
///*
// * PROPERTY DECLARATIONS
// * */
//
//
///*
// * enforce reister map
// * */
//    rs1_reg_map : assume property(reg_map_forced(cpu0_rs1, cpu1_rs1));
//    rs2_reg_map : assume property(reg_map_conditioned((cpu0_opcode == `RV32_OP || cpu1_opcode == `RV32_OP_IMM), cpu0_rs2, cpu1_rs2));
//    rdd_reg_map : assume property(reg_map_forced(cpu0_rd, cpu1_rd));
//
///*
// * funct7 limits
// * */
//    cpu0_funct7_limit0 : assume property(funct7_limit_0(cpu0_opcode, cpu0_funct3, cpu0_funct7));
//    cpu1_funct7_limit0 : assume property(funct7_limit_0(cpu1_opcode, cpu1_funct3, cpu1_funct7));
//    cpu0_funct7_limit2 : assume property(funct7_limit_2(cpu0_opcode, cpu0_funct3, cpu0_funct7));
//    cpu1_funct7_limit2 : assume property(funct7_limit_2(cpu1_opcode, cpu1_funct3, cpu1_funct7));
//
///*
// *  the funct3 values should ALWAYS be the same
// *  */
//    cpus_have_same_funct3  : assume property(equal_to(cpu0_funct3, cpu1_funct3));
//
///*
// *  funct7 should match if we are doing a non immediate op. will specify
// *  a different property for immediate opcodes
// *  */
//    cpus_have_same_funct7  : assume property(conditioned_equal_to(cpu0_opcode == `RV32_OP, cpu0_funct7, cpu1_funct7));
//
///*
// * the immediate values should match in the case of an immediate opcode
// * */
//    cpus_have_matching_imm : assume property(conditioned_equal_to(cpu0_opcode == `RV32_OP_IMM, cpu0_imm12, cpu1_imm12));
//
///*
// *  the opcodes should ALWAYS match
// *  */
//    cpus_have_same_opcodes : assume property(equal_to(cpu0_opcode,cpu1_opcode));
//
//
//
//



endmodule

module Wrapper;

bind mriscvcore_top_s2qed s2qed S2QED_BIND(
  .clk(clk),
  .rstn(rstn),
  .cpu0_inst(mriscvcore_inst0.MEMORY_INTERFACE_inst.inst),
  .cpu1_inst(mriscvcore_inst1.MEMORY_INTERFACE_inst.inst),
  .cpu0_reg(mriscvcore_inst0.REG_FILE_inst.MEM_FILE.ram),
  .cpu1_reg(mriscvcore_inst1.REG_FILE_inst.MEM_FILE.ram),
  .cpu0_state(mriscvcore_inst0.FSM_inst.state),
  .cpu1_state(mriscvcore_inst1.FSM_inst.state),
  .is_illisn0(mriscvcore_inst0.FSM_inst.is_illisn),
  .is_illisn1(mriscvcore_inst1.FSM_inst.is_illisn),
  .cpu0_rs1i(mriscvcore_inst0.DECODE_INSTR_inst.rs1i),
  .cpu1_rs1i(mriscvcore_inst1.DECODE_INSTR_inst.rs1i),
  .cpu0_rs2i(mriscvcore_inst0.DECODE_INSTR_inst.rs2i),
  .cpu1_rs2i(mriscvcore_inst1.DECODE_INSTR_inst.rs2i),
  .cpu0_rdi(mriscvcore_inst0.DECODE_INSTR_inst.rdi),
  .cpu1_rdi(mriscvcore_inst1.DECODE_INSTR_inst.rdi),
  .cpu0_imm(mriscvcore_inst0.DECODE_INSTR_inst.imm),
  .cpu1_imm(mriscvcore_inst1.DECODE_INSTR_inst.imm),
  .cpu0_codif(mriscvcore_inst0.DECODE_INSTR_inst.codif),
  .cpu1_codif(mriscvcore_inst1.DECODE_INSTR_inst.codif)
);

endmodule //Wrapper


