// -*- c++ -*-

/*

 Copyright 2019 Alain Dargelas

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

/*
 * File:   Serializer.h
 * Author:
 *
 * Created on December 14, 2019, 10:03 PM
 */

#ifndef UHDM_SERIALIZER_H
#define UHDM_SERIALIZER_H

#include <uhdm/SymbolFactory.h>
#include <uhdm/containers.h>
#include <uhdm/vpi_uhdm.h>

#include <filesystem>
#include <functional>
#include <iostream>
#include <map>
#include <string>
#include <string_view>
#include <vector>

#define UHDM_MAX_BIT_WIDTH (1024 * 1024)

namespace UHDM {
enum ErrorType {
  UHDM_UNSUPPORTED_EXPR = 700,
  UHDM_UNSUPPORTED_STMT = 701,
  UHDM_WRONG_OBJECT_TYPE = 703,
  UHDM_UNDEFINED_PATTERN_KEY = 712,
  UHDM_UNMATCHED_FIELD_IN_PATTERN_ASSIGN = 713,
  UHDM_REAL_TYPE_AS_SELECT = 714,
  UHDM_RETURN_VALUE_VOID_FUNCTION = 715,
  UHDM_ILLEGAL_DEFAULT_VALUE = 716,
  UHDM_MULTIPLE_CONT_ASSIGN = 717,
  UHDM_ILLEGAL_WIRE_LHS = 718,
  UHDM_ILLEGAL_PACKED_DIMENSION = 719,
  UHDM_NON_SYNTHESIZABLE = 720,
  UHDM_ENUM_CONST_SIZE_MISMATCH = 721,
  UHDM_DIVIDE_BY_ZERO = 722,
  UHDM_INTERNAL_ERROR_OUT_OF_BOUND = 723,
  UHDM_UNDEFINED_USER_FUNCTION = 724,
  UHDM_UNRESOLVED_HIER_PATH = 725,
  UHDM_UNDEFINED_VARIABLE = 726,
  UHDM_INVALID_CASE_STMT_VALUE = 727,
  UHDM_UNSUPPORTED_TYPESPEC = 728,
  UHDM_UNRESOLVED_PROPERTY = 729,
  UHDM_NON_TEMPORAL_SEQUENCE_USE = 730,
  UHDM_NON_POSITIVE_VALUE = 731,
  UHDM_SIGNED_UNSIGNED_PORT_CONN = 732,
  UHDM_FORCING_UNSIGNED_TYPE = 733
};

#ifndef SWIG
typedef std::function<void(ErrorType errType, const std::string&,
                           const any* object1, const any* object2)>
    ErrorHandler;

void DefaultErrorHandler(ErrorType errType, const std::string& errorMsg,
                         const any* object1, const any* object2);

template <typename T>
class FactoryT;
#endif

class Serializer final {
 public:
  using IdMap = std::map<const BaseClass*, uint32_t>;
  static constexpr uint32_t kBadIndex = static_cast<uint32_t>(-1);
  static const uint32_t kVersion;

  Serializer() = default;
  ~Serializer();

#ifndef SWIG
  void Save(const std::filesystem::path& filepath);
  void Save(const std::string& filepath);
  void Purge();

  void SetGCEnabled(bool enabled) { m_enableGC = enabled; }
  void GarbageCollect();

  void SetErrorHandler(ErrorHandler handler) { m_errorHandler = handler; }
  ErrorHandler GetErrorHandler() { return m_errorHandler; }

  IdMap AllObjects() const;
#endif

  const std::vector<vpiHandle> Restore(const std::filesystem::path& filepath);
  const std::vector<vpiHandle> Restore(const std::string& filepath);
  std::map<std::string, uint32_t, std::less<>> ObjectStats() const;
  void PrintStats(std::ostream& strm, std::string_view infoText) const;

#ifndef SWIG
 private:
  template <typename T>
  T* Make(FactoryT<T>* const factory);

  template <typename T>
  void Make(FactoryT<T>* const factory, uint32_t count);

  template <typename T>
  std::vector<T*>* Make(FactoryT<std::vector<T*>>* const factory);

 public:
    attribute* MakeAttribute();
  std::vector<attribute*>* MakeAttributeVec();
  virtual_interface_var* MakeVirtual_interface_var();
  std::vector<virtual_interface_var*>* MakeVirtual_interface_varVec();
  let_decl* MakeLet_decl();
  std::vector<let_decl*>* MakeLet_declVec();
  std::vector<concurrent_assertions*>* MakeConcurrent_assertionsVec();
  std::vector<process_stmt*>* MakeProcess_stmtVec();
  always* MakeAlways();
  std::vector<always*>* MakeAlwaysVec();
  final_stmt* MakeFinal_stmt();
  std::vector<final_stmt*>* MakeFinal_stmtVec();
  initial* MakeInitial();
  std::vector<initial*>* MakeInitialVec();
  std::vector<atomic_stmt*>* MakeAtomic_stmtVec();
  delay_control* MakeDelay_control();
  std::vector<delay_control*>* MakeDelay_controlVec();
  delay_term* MakeDelay_term();
  std::vector<delay_term*>* MakeDelay_termVec();
  event_control* MakeEvent_control();
  std::vector<event_control*>* MakeEvent_controlVec();
  repeat_control* MakeRepeat_control();
  std::vector<repeat_control*>* MakeRepeat_controlVec();
  std::vector<scope*>* MakeScopeVec();
  begin* MakeBegin();
  std::vector<begin*>* MakeBeginVec();
  named_begin* MakeNamed_begin();
  std::vector<named_begin*>* MakeNamed_beginVec();
  named_fork* MakeNamed_fork();
  std::vector<named_fork*>* MakeNamed_forkVec();
  fork_stmt* MakeFork_stmt();
  std::vector<fork_stmt*>* MakeFork_stmtVec();
  for_stmt* MakeFor_stmt();
  std::vector<for_stmt*>* MakeFor_stmtVec();
  if_stmt* MakeIf_stmt();
  std::vector<if_stmt*>* MakeIf_stmtVec();
  event_stmt* MakeEvent_stmt();
  std::vector<event_stmt*>* MakeEvent_stmtVec();
  thread_obj* MakeThread_obj();
  std::vector<thread_obj*>* MakeThread_objVec();
  forever_stmt* MakeForever_stmt();
  std::vector<forever_stmt*>* MakeForever_stmtVec();
  std::vector<waits*>* MakeWaitsVec();
  wait_stmt* MakeWait_stmt();
  std::vector<wait_stmt*>* MakeWait_stmtVec();
  wait_fork* MakeWait_fork();
  std::vector<wait_fork*>* MakeWait_forkVec();
  ordered_wait* MakeOrdered_wait();
  std::vector<ordered_wait*>* MakeOrdered_waitVec();
  std::vector<disables*>* MakeDisablesVec();
  disable* MakeDisable();
  std::vector<disable*>* MakeDisableVec();
  disable_fork* MakeDisable_fork();
  std::vector<disable_fork*>* MakeDisable_forkVec();
  continue_stmt* MakeContinue_stmt();
  std::vector<continue_stmt*>* MakeContinue_stmtVec();
  break_stmt* MakeBreak_stmt();
  std::vector<break_stmt*>* MakeBreak_stmtVec();
  return_stmt* MakeReturn_stmt();
  std::vector<return_stmt*>* MakeReturn_stmtVec();
  while_stmt* MakeWhile_stmt();
  std::vector<while_stmt*>* MakeWhile_stmtVec();
  repeat* MakeRepeat();
  std::vector<repeat*>* MakeRepeatVec();
  do_while* MakeDo_while();
  std::vector<do_while*>* MakeDo_whileVec();
  if_else* MakeIf_else();
  std::vector<if_else*>* MakeIf_elseVec();
  case_stmt* MakeCase_stmt();
  std::vector<case_stmt*>* MakeCase_stmtVec();
  force* MakeForce();
  std::vector<force*>* MakeForceVec();
  assign_stmt* MakeAssign_stmt();
  std::vector<assign_stmt*>* MakeAssign_stmtVec();
  deassign* MakeDeassign();
  std::vector<deassign*>* MakeDeassignVec();
  release* MakeRelease();
  std::vector<release*>* MakeReleaseVec();
  null_stmt* MakeNull_stmt();
  std::vector<null_stmt*>* MakeNull_stmtVec();
  expect_stmt* MakeExpect_stmt();
  std::vector<expect_stmt*>* MakeExpect_stmtVec();
  foreach_stmt* MakeForeach_stmt();
  std::vector<foreach_stmt*>* MakeForeach_stmtVec();
  gen_scope* MakeGen_scope();
  std::vector<gen_scope*>* MakeGen_scopeVec();
  gen_var* MakeGen_var();
  std::vector<gen_var*>* MakeGen_varVec();
  gen_scope_array* MakeGen_scope_array();
  std::vector<gen_scope_array*>* MakeGen_scope_arrayVec();
  assert_stmt* MakeAssert_stmt();
  std::vector<assert_stmt*>* MakeAssert_stmtVec();
  cover* MakeCover();
  std::vector<cover*>* MakeCoverVec();
  assume* MakeAssume();
  std::vector<assume*>* MakeAssumeVec();
  restrict* MakeRestrict();
  std::vector<restrict*>* MakeRestrictVec();
  immediate_assert* MakeImmediate_assert();
  std::vector<immediate_assert*>* MakeImmediate_assertVec();
  immediate_assume* MakeImmediate_assume();
  std::vector<immediate_assume*>* MakeImmediate_assumeVec();
  immediate_cover* MakeImmediate_cover();
  std::vector<immediate_cover*>* MakeImmediate_coverVec();
  std::vector<expr*>* MakeExprVec();
  case_item* MakeCase_item();
  std::vector<case_item*>* MakeCase_itemVec();
  assignment* MakeAssignment();
  std::vector<assignment*>* MakeAssignmentVec();
  any_pattern* MakeAny_pattern();
  std::vector<any_pattern*>* MakeAny_patternVec();
  tagged_pattern* MakeTagged_pattern();
  std::vector<tagged_pattern*>* MakeTagged_patternVec();
  struct_pattern* MakeStruct_pattern();
  std::vector<struct_pattern*>* MakeStruct_patternVec();
  unsupported_expr* MakeUnsupported_expr();
  std::vector<unsupported_expr*>* MakeUnsupported_exprVec();
  unsupported_stmt* MakeUnsupported_stmt();
  std::vector<unsupported_stmt*>* MakeUnsupported_stmtVec();
  include_file_info* MakeInclude_file_info();
  std::vector<include_file_info*>* MakeInclude_file_infoVec();
  sequence_inst* MakeSequence_inst();
  std::vector<sequence_inst*>* MakeSequence_instVec();
  seq_formal_decl* MakeSeq_formal_decl();
  std::vector<seq_formal_decl*>* MakeSeq_formal_declVec();
  sequence_decl* MakeSequence_decl();
  std::vector<sequence_decl*>* MakeSequence_declVec();
  prop_formal_decl* MakeProp_formal_decl();
  std::vector<prop_formal_decl*>* MakeProp_formal_declVec();
  property_inst* MakeProperty_inst();
  std::vector<property_inst*>* MakeProperty_instVec();
  property_spec* MakeProperty_spec();
  std::vector<property_spec*>* MakeProperty_specVec();
  property_decl* MakeProperty_decl();
  std::vector<property_decl*>* MakeProperty_declVec();
  clocked_property* MakeClocked_property();
  std::vector<clocked_property*>* MakeClocked_propertyVec();
  case_property_item* MakeCase_property_item();
  std::vector<case_property_item*>* MakeCase_property_itemVec();
  case_property* MakeCase_property();
  std::vector<case_property*>* MakeCase_propertyVec();
  multiclock_sequence_expr* MakeMulticlock_sequence_expr();
  std::vector<multiclock_sequence_expr*>* MakeMulticlock_sequence_exprVec();
  clocked_seq* MakeClocked_seq();
  std::vector<clocked_seq*>* MakeClocked_seqVec();
  std::vector<simple_expr*>* MakeSimple_exprVec();
  constant* MakeConstant();
  std::vector<constant*>* MakeConstantVec();
  let_expr* MakeLet_expr();
  std::vector<let_expr*>* MakeLet_exprVec();
  operation* MakeOperation();
  std::vector<operation*>* MakeOperationVec();
  ref_obj* MakeRef_obj();
  std::vector<ref_obj*>* MakeRef_objVec();
  ref_module* MakeRef_module();
  std::vector<ref_module*>* MakeRef_moduleVec();
  ref_typespec* MakeRef_typespec();
  std::vector<ref_typespec*>* MakeRef_typespecVec();
  part_select* MakePart_select();
  std::vector<part_select*>* MakePart_selectVec();
  indexed_part_select* MakeIndexed_part_select();
  std::vector<indexed_part_select*>* MakeIndexed_part_selectVec();
  var_select* MakeVar_select();
  std::vector<var_select*>* MakeVar_selectVec();
  bit_select* MakeBit_select();
  std::vector<bit_select*>* MakeBit_selectVec();
  std::vector<variables*>* MakeVariablesVec();
  hier_path* MakeHier_path();
  std::vector<hier_path*>* MakeHier_pathVec();
  ref_var* MakeRef_var();
  std::vector<ref_var*>* MakeRef_varVec();
  short_real_var* MakeShort_real_var();
  std::vector<short_real_var*>* MakeShort_real_varVec();
  real_var* MakeReal_var();
  std::vector<real_var*>* MakeReal_varVec();
  byte_var* MakeByte_var();
  std::vector<byte_var*>* MakeByte_varVec();
  short_int_var* MakeShort_int_var();
  std::vector<short_int_var*>* MakeShort_int_varVec();
  int_var* MakeInt_var();
  std::vector<int_var*>* MakeInt_varVec();
  long_int_var* MakeLong_int_var();
  std::vector<long_int_var*>* MakeLong_int_varVec();
  integer_var* MakeInteger_var();
  std::vector<integer_var*>* MakeInteger_varVec();
  time_var* MakeTime_var();
  std::vector<time_var*>* MakeTime_varVec();
  array_var* MakeArray_var();
  std::vector<array_var*>* MakeArray_varVec();
  array_expr* MakeArray_expr();
  std::vector<array_expr*>* MakeArray_exprVec();
  reg_array* MakeReg_array();
  std::vector<reg_array*>* MakeReg_arrayVec();
  reg* MakeReg();
  std::vector<reg*>* MakeRegVec();
  packed_array_var* MakePacked_array_var();
  std::vector<packed_array_var*>* MakePacked_array_varVec();
  bit_var* MakeBit_var();
  std::vector<bit_var*>* MakeBit_varVec();
  logic_var* MakeLogic_var();
  std::vector<logic_var*>* MakeLogic_varVec();
  struct_var* MakeStruct_var();
  std::vector<struct_var*>* MakeStruct_varVec();
  union_var* MakeUnion_var();
  std::vector<union_var*>* MakeUnion_varVec();
  enum_var* MakeEnum_var();
  std::vector<enum_var*>* MakeEnum_varVec();
  string_var* MakeString_var();
  std::vector<string_var*>* MakeString_varVec();
  chandle_var* MakeChandle_var();
  std::vector<chandle_var*>* MakeChandle_varVec();
  var_bit* MakeVar_bit();
  std::vector<var_bit*>* MakeVar_bitVec();
  std::vector<task_func*>* MakeTask_funcVec();
  task* MakeTask();
  std::vector<task*>* MakeTaskVec();
  function* MakeFunction();
  std::vector<function*>* MakeFunctionVec();
  modport* MakeModport();
  std::vector<modport*>* MakeModportVec();
  interface_tf_decl* MakeInterface_tf_decl();
  std::vector<interface_tf_decl*>* MakeInterface_tf_declVec();
  cont_assign* MakeCont_assign();
  std::vector<cont_assign*>* MakeCont_assignVec();
  cont_assign_bit* MakeCont_assign_bit();
  std::vector<cont_assign_bit*>* MakeCont_assign_bitVec();
  std::vector<ports*>* MakePortsVec();
  port* MakePort();
  std::vector<port*>* MakePortVec();
  port_bit* MakePort_bit();
  std::vector<port_bit*>* MakePort_bitVec();
  checker_port* MakeChecker_port();
  std::vector<checker_port*>* MakeChecker_portVec();
  checker_inst_port* MakeChecker_inst_port();
  std::vector<checker_inst_port*>* MakeChecker_inst_portVec();
  std::vector<primitive*>* MakePrimitiveVec();
  gate* MakeGate();
  std::vector<gate*>* MakeGateVec();
  switch_tran* MakeSwitch_tran();
  std::vector<switch_tran*>* MakeSwitch_tranVec();
  udp* MakeUdp();
  std::vector<udp*>* MakeUdpVec();
  mod_path* MakeMod_path();
  std::vector<mod_path*>* MakeMod_pathVec();
  tchk* MakeTchk();
  std::vector<tchk*>* MakeTchkVec();
  range* MakeRange();
  std::vector<range*>* MakeRangeVec();
  udp_defn* MakeUdp_defn();
  std::vector<udp_defn*>* MakeUdp_defnVec();
  table_entry* MakeTable_entry();
  std::vector<table_entry*>* MakeTable_entryVec();
  io_decl* MakeIo_decl();
  std::vector<io_decl*>* MakeIo_declVec();
  alias_stmt* MakeAlias_stmt();
  std::vector<alias_stmt*>* MakeAlias_stmtVec();
  clocking_block* MakeClocking_block();
  std::vector<clocking_block*>* MakeClocking_blockVec();
  clocking_io_decl* MakeClocking_io_decl();
  std::vector<clocking_io_decl*>* MakeClocking_io_declVec();
  param_assign* MakeParam_assign();
  std::vector<param_assign*>* MakeParam_assignVec();
  std::vector<instance_array*>* MakeInstance_arrayVec();
  interface_array* MakeInterface_array();
  std::vector<interface_array*>* MakeInterface_arrayVec();
  program_array* MakeProgram_array();
  std::vector<program_array*>* MakeProgram_arrayVec();
  module_array* MakeModule_array();
  std::vector<module_array*>* MakeModule_arrayVec();
  std::vector<primitive_array*>* MakePrimitive_arrayVec();
  gate_array* MakeGate_array();
  std::vector<gate_array*>* MakeGate_arrayVec();
  switch_array* MakeSwitch_array();
  std::vector<switch_array*>* MakeSwitch_arrayVec();
  udp_array* MakeUdp_array();
  std::vector<udp_array*>* MakeUdp_arrayVec();
  std::vector<typespec*>* MakeTypespecVec();
  std::vector<net_drivers*>* MakeNet_driversVec();
  std::vector<net_loads*>* MakeNet_loadsVec();
  prim_term* MakePrim_term();
  std::vector<prim_term*>* MakePrim_termVec();
  path_term* MakePath_term();
  std::vector<path_term*>* MakePath_termVec();
  tchk_term* MakeTchk_term();
  std::vector<tchk_term*>* MakeTchk_termVec();
  std::vector<nets*>* MakeNetsVec();
  net_bit* MakeNet_bit();
  std::vector<net_bit*>* MakeNet_bitVec();
  std::vector<net*>* MakeNetVec();
  struct_net* MakeStruct_net();
  std::vector<struct_net*>* MakeStruct_netVec();
  enum_net* MakeEnum_net();
  std::vector<enum_net*>* MakeEnum_netVec();
  integer_net* MakeInteger_net();
  std::vector<integer_net*>* MakeInteger_netVec();
  time_net* MakeTime_net();
  std::vector<time_net*>* MakeTime_netVec();
  logic_net* MakeLogic_net();
  std::vector<logic_net*>* MakeLogic_netVec();
  array_net* MakeArray_net();
  std::vector<array_net*>* MakeArray_netVec();
  packed_array_net* MakePacked_array_net();
  std::vector<packed_array_net*>* MakePacked_array_netVec();
  event_typespec* MakeEvent_typespec();
  std::vector<event_typespec*>* MakeEvent_typespecVec();
  named_event* MakeNamed_event();
  std::vector<named_event*>* MakeNamed_eventVec();
  named_event_array* MakeNamed_event_array();
  std::vector<named_event_array*>* MakeNamed_event_arrayVec();
  parameter* MakeParameter();
  std::vector<parameter*>* MakeParameterVec();
  def_param* MakeDef_param();
  std::vector<def_param*>* MakeDef_paramVec();
  spec_param* MakeSpec_param();
  std::vector<spec_param*>* MakeSpec_paramVec();
  class_typespec* MakeClass_typespec();
  std::vector<class_typespec*>* MakeClass_typespecVec();
  extends* MakeExtends();
  std::vector<extends*>* MakeExtendsVec();
  class_defn* MakeClass_defn();
  std::vector<class_defn*>* MakeClass_defnVec();
  class_obj* MakeClass_obj();
  std::vector<class_obj*>* MakeClass_objVec();
  class_var* MakeClass_var();
  std::vector<class_var*>* MakeClass_varVec();
  std::vector<instance*>* MakeInstanceVec();
  interface_inst* MakeInterface_inst();
  std::vector<interface_inst*>* MakeInterface_instVec();
  program* MakeProgram();
  std::vector<program*>* MakeProgramVec();
  package* MakePackage();
  std::vector<package*>* MakePackageVec();
  module_inst* MakeModule_inst();
  std::vector<module_inst*>* MakeModule_instVec();
  checker_decl* MakeChecker_decl();
  std::vector<checker_decl*>* MakeChecker_declVec();
  checker_inst* MakeChecker_inst();
  std::vector<checker_inst*>* MakeChecker_instVec();
  short_real_typespec* MakeShort_real_typespec();
  std::vector<short_real_typespec*>* MakeShort_real_typespecVec();
  real_typespec* MakeReal_typespec();
  std::vector<real_typespec*>* MakeReal_typespecVec();
  byte_typespec* MakeByte_typespec();
  std::vector<byte_typespec*>* MakeByte_typespecVec();
  short_int_typespec* MakeShort_int_typespec();
  std::vector<short_int_typespec*>* MakeShort_int_typespecVec();
  int_typespec* MakeInt_typespec();
  std::vector<int_typespec*>* MakeInt_typespecVec();
  long_int_typespec* MakeLong_int_typespec();
  std::vector<long_int_typespec*>* MakeLong_int_typespecVec();
  integer_typespec* MakeInteger_typespec();
  std::vector<integer_typespec*>* MakeInteger_typespecVec();
  time_typespec* MakeTime_typespec();
  std::vector<time_typespec*>* MakeTime_typespecVec();
  enum_typespec* MakeEnum_typespec();
  std::vector<enum_typespec*>* MakeEnum_typespecVec();
  string_typespec* MakeString_typespec();
  std::vector<string_typespec*>* MakeString_typespecVec();
  chandle_typespec* MakeChandle_typespec();
  std::vector<chandle_typespec*>* MakeChandle_typespecVec();
  module_typespec* MakeModule_typespec();
  std::vector<module_typespec*>* MakeModule_typespecVec();
  struct_typespec* MakeStruct_typespec();
  std::vector<struct_typespec*>* MakeStruct_typespecVec();
  union_typespec* MakeUnion_typespec();
  std::vector<union_typespec*>* MakeUnion_typespecVec();
  logic_typespec* MakeLogic_typespec();
  std::vector<logic_typespec*>* MakeLogic_typespecVec();
  packed_array_typespec* MakePacked_array_typespec();
  std::vector<packed_array_typespec*>* MakePacked_array_typespecVec();
  array_typespec* MakeArray_typespec();
  std::vector<array_typespec*>* MakeArray_typespecVec();
  void_typespec* MakeVoid_typespec();
  std::vector<void_typespec*>* MakeVoid_typespecVec();
  unsupported_typespec* MakeUnsupported_typespec();
  std::vector<unsupported_typespec*>* MakeUnsupported_typespecVec();
  sequence_typespec* MakeSequence_typespec();
  std::vector<sequence_typespec*>* MakeSequence_typespecVec();
  property_typespec* MakeProperty_typespec();
  std::vector<property_typespec*>* MakeProperty_typespecVec();
  interface_typespec* MakeInterface_typespec();
  std::vector<interface_typespec*>* MakeInterface_typespecVec();
  type_parameter* MakeType_parameter();
  std::vector<type_parameter*>* MakeType_parameterVec();
  typespec_member* MakeTypespec_member();
  std::vector<typespec_member*>* MakeTypespec_memberVec();
  enum_const* MakeEnum_const();
  std::vector<enum_const*>* MakeEnum_constVec();
  bit_typespec* MakeBit_typespec();
  std::vector<bit_typespec*>* MakeBit_typespecVec();
  std::vector<tf_call*>* MakeTf_callVec();
  user_systf* MakeUser_systf();
  std::vector<user_systf*>* MakeUser_systfVec();
  sys_func_call* MakeSys_func_call();
  std::vector<sys_func_call*>* MakeSys_func_callVec();
  sys_task_call* MakeSys_task_call();
  std::vector<sys_task_call*>* MakeSys_task_callVec();
  method_func_call* MakeMethod_func_call();
  std::vector<method_func_call*>* MakeMethod_func_callVec();
  method_task_call* MakeMethod_task_call();
  std::vector<method_task_call*>* MakeMethod_task_callVec();
  func_call* MakeFunc_call();
  std::vector<func_call*>* MakeFunc_callVec();
  task_call* MakeTask_call();
  std::vector<task_call*>* MakeTask_callVec();
  std::vector<constraint_expr*>* MakeConstraint_exprVec();
  constraint_ordering* MakeConstraint_ordering();
  std::vector<constraint_ordering*>* MakeConstraint_orderingVec();
  constraint* MakeConstraint();
  std::vector<constraint*>* MakeConstraintVec();
  import_typespec* MakeImport_typespec();
  std::vector<import_typespec*>* MakeImport_typespecVec();
  dist_item* MakeDist_item();
  std::vector<dist_item*>* MakeDist_itemVec();
  distribution* MakeDistribution();
  std::vector<distribution*>* MakeDistributionVec();
  implication* MakeImplication();
  std::vector<implication*>* MakeImplicationVec();
  constr_if* MakeConstr_if();
  std::vector<constr_if*>* MakeConstr_ifVec();
  constr_if_else* MakeConstr_if_else();
  std::vector<constr_if_else*>* MakeConstr_if_elseVec();
  constr_foreach* MakeConstr_foreach();
  std::vector<constr_foreach*>* MakeConstr_foreachVec();
  soft_disable* MakeSoft_disable();
  std::vector<soft_disable*>* MakeSoft_disableVec();
  std::vector<gen_stmt*>* MakeGen_stmtVec();
  gen_if* MakeGen_if();
  std::vector<gen_if*>* MakeGen_ifVec();
  gen_if_else* MakeGen_if_else();
  std::vector<gen_if_else*>* MakeGen_if_elseVec();
  gen_for* MakeGen_for();
  std::vector<gen_for*>* MakeGen_forVec();
  gen_case* MakeGen_case();
  std::vector<gen_case*>* MakeGen_caseVec();
  gen_region* MakeGen_region();
  std::vector<gen_region*>* MakeGen_regionVec();
  design* MakeDesign();
  std::vector<design*>* MakeDesignVec(); std::vector<any*>* MakeAnyVec() {
    return anyVectMaker.Make();
  }

  SymbolId MakeSymbol(std::string_view symbol);
  std::string_view GetSymbol(SymbolId id) const;
  SymbolId GetSymbolId(std::string_view symbol) const;

  vpiHandle MakeUhdmHandle(UHDM_OBJECT_TYPE type, const void* object);

  bool Erase(const BaseClass* p);

 private:
  struct SaveAdapter;
  friend struct SaveAdapter;

  struct RestoreAdapter;
  friend struct RestoreAdapter;

 private:
  BaseClass* GetObject(uint32_t objectType, uint32_t index) const;

  uint64_t m_version = 0;
  uint32_t m_objId = 0;
  bool m_enableGC = true;
  ErrorHandler m_errorHandler = DefaultErrorHandler;

  VectorOfanyFactory anyVectMaker;
  SymbolFactory symbolMaker;
  uhdm_handleFactory uhdm_handleMaker;
  attributeFactory attributeMaker;
  VectorOfattributeFactory attributeVectMaker;
  virtual_interface_varFactory virtual_interface_varMaker;
  VectorOfvirtual_interface_varFactory virtual_interface_varVectMaker;
  let_declFactory let_declMaker;
  VectorOflet_declFactory let_declVectMaker;
  VectorOfconcurrent_assertionsFactory concurrent_assertionsVectMaker;
  VectorOfprocess_stmtFactory process_stmtVectMaker;
  alwaysFactory alwaysMaker;
  VectorOfalwaysFactory alwaysVectMaker;
  final_stmtFactory final_stmtMaker;
  VectorOffinal_stmtFactory final_stmtVectMaker;
  initialFactory initialMaker;
  VectorOfinitialFactory initialVectMaker;
  VectorOfatomic_stmtFactory atomic_stmtVectMaker;
  delay_controlFactory delay_controlMaker;
  VectorOfdelay_controlFactory delay_controlVectMaker;
  delay_termFactory delay_termMaker;
  VectorOfdelay_termFactory delay_termVectMaker;
  event_controlFactory event_controlMaker;
  VectorOfevent_controlFactory event_controlVectMaker;
  repeat_controlFactory repeat_controlMaker;
  VectorOfrepeat_controlFactory repeat_controlVectMaker;
  VectorOfscopeFactory scopeVectMaker;
  beginFactory beginMaker;
  VectorOfbeginFactory beginVectMaker;
  named_beginFactory named_beginMaker;
  VectorOfnamed_beginFactory named_beginVectMaker;
  named_forkFactory named_forkMaker;
  VectorOfnamed_forkFactory named_forkVectMaker;
  fork_stmtFactory fork_stmtMaker;
  VectorOffork_stmtFactory fork_stmtVectMaker;
  for_stmtFactory for_stmtMaker;
  VectorOffor_stmtFactory for_stmtVectMaker;
  if_stmtFactory if_stmtMaker;
  VectorOfif_stmtFactory if_stmtVectMaker;
  event_stmtFactory event_stmtMaker;
  VectorOfevent_stmtFactory event_stmtVectMaker;
  thread_objFactory thread_objMaker;
  VectorOfthread_objFactory thread_objVectMaker;
  forever_stmtFactory forever_stmtMaker;
  VectorOfforever_stmtFactory forever_stmtVectMaker;
  VectorOfwaitsFactory waitsVectMaker;
  wait_stmtFactory wait_stmtMaker;
  VectorOfwait_stmtFactory wait_stmtVectMaker;
  wait_forkFactory wait_forkMaker;
  VectorOfwait_forkFactory wait_forkVectMaker;
  ordered_waitFactory ordered_waitMaker;
  VectorOfordered_waitFactory ordered_waitVectMaker;
  VectorOfdisablesFactory disablesVectMaker;
  disableFactory disableMaker;
  VectorOfdisableFactory disableVectMaker;
  disable_forkFactory disable_forkMaker;
  VectorOfdisable_forkFactory disable_forkVectMaker;
  continue_stmtFactory continue_stmtMaker;
  VectorOfcontinue_stmtFactory continue_stmtVectMaker;
  break_stmtFactory break_stmtMaker;
  VectorOfbreak_stmtFactory break_stmtVectMaker;
  return_stmtFactory return_stmtMaker;
  VectorOfreturn_stmtFactory return_stmtVectMaker;
  while_stmtFactory while_stmtMaker;
  VectorOfwhile_stmtFactory while_stmtVectMaker;
  repeatFactory repeatMaker;
  VectorOfrepeatFactory repeatVectMaker;
  do_whileFactory do_whileMaker;
  VectorOfdo_whileFactory do_whileVectMaker;
  if_elseFactory if_elseMaker;
  VectorOfif_elseFactory if_elseVectMaker;
  case_stmtFactory case_stmtMaker;
  VectorOfcase_stmtFactory case_stmtVectMaker;
  forceFactory forceMaker;
  VectorOfforceFactory forceVectMaker;
  assign_stmtFactory assign_stmtMaker;
  VectorOfassign_stmtFactory assign_stmtVectMaker;
  deassignFactory deassignMaker;
  VectorOfdeassignFactory deassignVectMaker;
  releaseFactory releaseMaker;
  VectorOfreleaseFactory releaseVectMaker;
  null_stmtFactory null_stmtMaker;
  VectorOfnull_stmtFactory null_stmtVectMaker;
  expect_stmtFactory expect_stmtMaker;
  VectorOfexpect_stmtFactory expect_stmtVectMaker;
  foreach_stmtFactory foreach_stmtMaker;
  VectorOfforeach_stmtFactory foreach_stmtVectMaker;
  gen_scopeFactory gen_scopeMaker;
  VectorOfgen_scopeFactory gen_scopeVectMaker;
  gen_varFactory gen_varMaker;
  VectorOfgen_varFactory gen_varVectMaker;
  gen_scope_arrayFactory gen_scope_arrayMaker;
  VectorOfgen_scope_arrayFactory gen_scope_arrayVectMaker;
  assert_stmtFactory assert_stmtMaker;
  VectorOfassert_stmtFactory assert_stmtVectMaker;
  coverFactory coverMaker;
  VectorOfcoverFactory coverVectMaker;
  assumeFactory assumeMaker;
  VectorOfassumeFactory assumeVectMaker;
  restrictFactory restrictMaker;
  VectorOfrestrictFactory restrictVectMaker;
  immediate_assertFactory immediate_assertMaker;
  VectorOfimmediate_assertFactory immediate_assertVectMaker;
  immediate_assumeFactory immediate_assumeMaker;
  VectorOfimmediate_assumeFactory immediate_assumeVectMaker;
  immediate_coverFactory immediate_coverMaker;
  VectorOfimmediate_coverFactory immediate_coverVectMaker;
  VectorOfexprFactory exprVectMaker;
  case_itemFactory case_itemMaker;
  VectorOfcase_itemFactory case_itemVectMaker;
  assignmentFactory assignmentMaker;
  VectorOfassignmentFactory assignmentVectMaker;
  any_patternFactory any_patternMaker;
  VectorOfany_patternFactory any_patternVectMaker;
  tagged_patternFactory tagged_patternMaker;
  VectorOftagged_patternFactory tagged_patternVectMaker;
  struct_patternFactory struct_patternMaker;
  VectorOfstruct_patternFactory struct_patternVectMaker;
  unsupported_exprFactory unsupported_exprMaker;
  VectorOfunsupported_exprFactory unsupported_exprVectMaker;
  unsupported_stmtFactory unsupported_stmtMaker;
  VectorOfunsupported_stmtFactory unsupported_stmtVectMaker;
  include_file_infoFactory include_file_infoMaker;
  VectorOfinclude_file_infoFactory include_file_infoVectMaker;
  sequence_instFactory sequence_instMaker;
  VectorOfsequence_instFactory sequence_instVectMaker;
  seq_formal_declFactory seq_formal_declMaker;
  VectorOfseq_formal_declFactory seq_formal_declVectMaker;
  sequence_declFactory sequence_declMaker;
  VectorOfsequence_declFactory sequence_declVectMaker;
  prop_formal_declFactory prop_formal_declMaker;
  VectorOfprop_formal_declFactory prop_formal_declVectMaker;
  property_instFactory property_instMaker;
  VectorOfproperty_instFactory property_instVectMaker;
  property_specFactory property_specMaker;
  VectorOfproperty_specFactory property_specVectMaker;
  property_declFactory property_declMaker;
  VectorOfproperty_declFactory property_declVectMaker;
  clocked_propertyFactory clocked_propertyMaker;
  VectorOfclocked_propertyFactory clocked_propertyVectMaker;
  case_property_itemFactory case_property_itemMaker;
  VectorOfcase_property_itemFactory case_property_itemVectMaker;
  case_propertyFactory case_propertyMaker;
  VectorOfcase_propertyFactory case_propertyVectMaker;
  multiclock_sequence_exprFactory multiclock_sequence_exprMaker;
  VectorOfmulticlock_sequence_exprFactory multiclock_sequence_exprVectMaker;
  clocked_seqFactory clocked_seqMaker;
  VectorOfclocked_seqFactory clocked_seqVectMaker;
  VectorOfsimple_exprFactory simple_exprVectMaker;
  constantFactory constantMaker;
  VectorOfconstantFactory constantVectMaker;
  let_exprFactory let_exprMaker;
  VectorOflet_exprFactory let_exprVectMaker;
  operationFactory operationMaker;
  VectorOfoperationFactory operationVectMaker;
  ref_objFactory ref_objMaker;
  VectorOfref_objFactory ref_objVectMaker;
  ref_moduleFactory ref_moduleMaker;
  VectorOfref_moduleFactory ref_moduleVectMaker;
  ref_typespecFactory ref_typespecMaker;
  VectorOfref_typespecFactory ref_typespecVectMaker;
  part_selectFactory part_selectMaker;
  VectorOfpart_selectFactory part_selectVectMaker;
  indexed_part_selectFactory indexed_part_selectMaker;
  VectorOfindexed_part_selectFactory indexed_part_selectVectMaker;
  var_selectFactory var_selectMaker;
  VectorOfvar_selectFactory var_selectVectMaker;
  bit_selectFactory bit_selectMaker;
  VectorOfbit_selectFactory bit_selectVectMaker;
  VectorOfvariablesFactory variablesVectMaker;
  hier_pathFactory hier_pathMaker;
  VectorOfhier_pathFactory hier_pathVectMaker;
  ref_varFactory ref_varMaker;
  VectorOfref_varFactory ref_varVectMaker;
  short_real_varFactory short_real_varMaker;
  VectorOfshort_real_varFactory short_real_varVectMaker;
  real_varFactory real_varMaker;
  VectorOfreal_varFactory real_varVectMaker;
  byte_varFactory byte_varMaker;
  VectorOfbyte_varFactory byte_varVectMaker;
  short_int_varFactory short_int_varMaker;
  VectorOfshort_int_varFactory short_int_varVectMaker;
  int_varFactory int_varMaker;
  VectorOfint_varFactory int_varVectMaker;
  long_int_varFactory long_int_varMaker;
  VectorOflong_int_varFactory long_int_varVectMaker;
  integer_varFactory integer_varMaker;
  VectorOfinteger_varFactory integer_varVectMaker;
  time_varFactory time_varMaker;
  VectorOftime_varFactory time_varVectMaker;
  array_varFactory array_varMaker;
  VectorOfarray_varFactory array_varVectMaker;
  array_exprFactory array_exprMaker;
  VectorOfarray_exprFactory array_exprVectMaker;
  reg_arrayFactory reg_arrayMaker;
  VectorOfreg_arrayFactory reg_arrayVectMaker;
  regFactory regMaker;
  VectorOfregFactory regVectMaker;
  packed_array_varFactory packed_array_varMaker;
  VectorOfpacked_array_varFactory packed_array_varVectMaker;
  bit_varFactory bit_varMaker;
  VectorOfbit_varFactory bit_varVectMaker;
  logic_varFactory logic_varMaker;
  VectorOflogic_varFactory logic_varVectMaker;
  struct_varFactory struct_varMaker;
  VectorOfstruct_varFactory struct_varVectMaker;
  union_varFactory union_varMaker;
  VectorOfunion_varFactory union_varVectMaker;
  enum_varFactory enum_varMaker;
  VectorOfenum_varFactory enum_varVectMaker;
  string_varFactory string_varMaker;
  VectorOfstring_varFactory string_varVectMaker;
  chandle_varFactory chandle_varMaker;
  VectorOfchandle_varFactory chandle_varVectMaker;
  var_bitFactory var_bitMaker;
  VectorOfvar_bitFactory var_bitVectMaker;
  VectorOftask_funcFactory task_funcVectMaker;
  taskFactory taskMaker;
  VectorOftaskFactory taskVectMaker;
  functionFactory functionMaker;
  VectorOffunctionFactory functionVectMaker;
  modportFactory modportMaker;
  VectorOfmodportFactory modportVectMaker;
  interface_tf_declFactory interface_tf_declMaker;
  VectorOfinterface_tf_declFactory interface_tf_declVectMaker;
  cont_assignFactory cont_assignMaker;
  VectorOfcont_assignFactory cont_assignVectMaker;
  cont_assign_bitFactory cont_assign_bitMaker;
  VectorOfcont_assign_bitFactory cont_assign_bitVectMaker;
  VectorOfportsFactory portsVectMaker;
  portFactory portMaker;
  VectorOfportFactory portVectMaker;
  port_bitFactory port_bitMaker;
  VectorOfport_bitFactory port_bitVectMaker;
  checker_portFactory checker_portMaker;
  VectorOfchecker_portFactory checker_portVectMaker;
  checker_inst_portFactory checker_inst_portMaker;
  VectorOfchecker_inst_portFactory checker_inst_portVectMaker;
  VectorOfprimitiveFactory primitiveVectMaker;
  gateFactory gateMaker;
  VectorOfgateFactory gateVectMaker;
  switch_tranFactory switch_tranMaker;
  VectorOfswitch_tranFactory switch_tranVectMaker;
  udpFactory udpMaker;
  VectorOfudpFactory udpVectMaker;
  mod_pathFactory mod_pathMaker;
  VectorOfmod_pathFactory mod_pathVectMaker;
  tchkFactory tchkMaker;
  VectorOftchkFactory tchkVectMaker;
  rangeFactory rangeMaker;
  VectorOfrangeFactory rangeVectMaker;
  udp_defnFactory udp_defnMaker;
  VectorOfudp_defnFactory udp_defnVectMaker;
  table_entryFactory table_entryMaker;
  VectorOftable_entryFactory table_entryVectMaker;
  io_declFactory io_declMaker;
  VectorOfio_declFactory io_declVectMaker;
  alias_stmtFactory alias_stmtMaker;
  VectorOfalias_stmtFactory alias_stmtVectMaker;
  clocking_blockFactory clocking_blockMaker;
  VectorOfclocking_blockFactory clocking_blockVectMaker;
  clocking_io_declFactory clocking_io_declMaker;
  VectorOfclocking_io_declFactory clocking_io_declVectMaker;
  param_assignFactory param_assignMaker;
  VectorOfparam_assignFactory param_assignVectMaker;
  VectorOfinstance_arrayFactory instance_arrayVectMaker;
  interface_arrayFactory interface_arrayMaker;
  VectorOfinterface_arrayFactory interface_arrayVectMaker;
  program_arrayFactory program_arrayMaker;
  VectorOfprogram_arrayFactory program_arrayVectMaker;
  module_arrayFactory module_arrayMaker;
  VectorOfmodule_arrayFactory module_arrayVectMaker;
  VectorOfprimitive_arrayFactory primitive_arrayVectMaker;
  gate_arrayFactory gate_arrayMaker;
  VectorOfgate_arrayFactory gate_arrayVectMaker;
  switch_arrayFactory switch_arrayMaker;
  VectorOfswitch_arrayFactory switch_arrayVectMaker;
  udp_arrayFactory udp_arrayMaker;
  VectorOfudp_arrayFactory udp_arrayVectMaker;
  VectorOftypespecFactory typespecVectMaker;
  VectorOfnet_driversFactory net_driversVectMaker;
  VectorOfnet_loadsFactory net_loadsVectMaker;
  prim_termFactory prim_termMaker;
  VectorOfprim_termFactory prim_termVectMaker;
  path_termFactory path_termMaker;
  VectorOfpath_termFactory path_termVectMaker;
  tchk_termFactory tchk_termMaker;
  VectorOftchk_termFactory tchk_termVectMaker;
  VectorOfnetsFactory netsVectMaker;
  net_bitFactory net_bitMaker;
  VectorOfnet_bitFactory net_bitVectMaker;
  VectorOfnetFactory netVectMaker;
  struct_netFactory struct_netMaker;
  VectorOfstruct_netFactory struct_netVectMaker;
  enum_netFactory enum_netMaker;
  VectorOfenum_netFactory enum_netVectMaker;
  integer_netFactory integer_netMaker;
  VectorOfinteger_netFactory integer_netVectMaker;
  time_netFactory time_netMaker;
  VectorOftime_netFactory time_netVectMaker;
  logic_netFactory logic_netMaker;
  VectorOflogic_netFactory logic_netVectMaker;
  array_netFactory array_netMaker;
  VectorOfarray_netFactory array_netVectMaker;
  packed_array_netFactory packed_array_netMaker;
  VectorOfpacked_array_netFactory packed_array_netVectMaker;
  event_typespecFactory event_typespecMaker;
  VectorOfevent_typespecFactory event_typespecVectMaker;
  named_eventFactory named_eventMaker;
  VectorOfnamed_eventFactory named_eventVectMaker;
  named_event_arrayFactory named_event_arrayMaker;
  VectorOfnamed_event_arrayFactory named_event_arrayVectMaker;
  parameterFactory parameterMaker;
  VectorOfparameterFactory parameterVectMaker;
  def_paramFactory def_paramMaker;
  VectorOfdef_paramFactory def_paramVectMaker;
  spec_paramFactory spec_paramMaker;
  VectorOfspec_paramFactory spec_paramVectMaker;
  class_typespecFactory class_typespecMaker;
  VectorOfclass_typespecFactory class_typespecVectMaker;
  extendsFactory extendsMaker;
  VectorOfextendsFactory extendsVectMaker;
  class_defnFactory class_defnMaker;
  VectorOfclass_defnFactory class_defnVectMaker;
  class_objFactory class_objMaker;
  VectorOfclass_objFactory class_objVectMaker;
  class_varFactory class_varMaker;
  VectorOfclass_varFactory class_varVectMaker;
  VectorOfinstanceFactory instanceVectMaker;
  interface_instFactory interface_instMaker;
  VectorOfinterface_instFactory interface_instVectMaker;
  programFactory programMaker;
  VectorOfprogramFactory programVectMaker;
  packageFactory packageMaker;
  VectorOfpackageFactory packageVectMaker;
  module_instFactory module_instMaker;
  VectorOfmodule_instFactory module_instVectMaker;
  checker_declFactory checker_declMaker;
  VectorOfchecker_declFactory checker_declVectMaker;
  checker_instFactory checker_instMaker;
  VectorOfchecker_instFactory checker_instVectMaker;
  short_real_typespecFactory short_real_typespecMaker;
  VectorOfshort_real_typespecFactory short_real_typespecVectMaker;
  real_typespecFactory real_typespecMaker;
  VectorOfreal_typespecFactory real_typespecVectMaker;
  byte_typespecFactory byte_typespecMaker;
  VectorOfbyte_typespecFactory byte_typespecVectMaker;
  short_int_typespecFactory short_int_typespecMaker;
  VectorOfshort_int_typespecFactory short_int_typespecVectMaker;
  int_typespecFactory int_typespecMaker;
  VectorOfint_typespecFactory int_typespecVectMaker;
  long_int_typespecFactory long_int_typespecMaker;
  VectorOflong_int_typespecFactory long_int_typespecVectMaker;
  integer_typespecFactory integer_typespecMaker;
  VectorOfinteger_typespecFactory integer_typespecVectMaker;
  time_typespecFactory time_typespecMaker;
  VectorOftime_typespecFactory time_typespecVectMaker;
  enum_typespecFactory enum_typespecMaker;
  VectorOfenum_typespecFactory enum_typespecVectMaker;
  string_typespecFactory string_typespecMaker;
  VectorOfstring_typespecFactory string_typespecVectMaker;
  chandle_typespecFactory chandle_typespecMaker;
  VectorOfchandle_typespecFactory chandle_typespecVectMaker;
  module_typespecFactory module_typespecMaker;
  VectorOfmodule_typespecFactory module_typespecVectMaker;
  struct_typespecFactory struct_typespecMaker;
  VectorOfstruct_typespecFactory struct_typespecVectMaker;
  union_typespecFactory union_typespecMaker;
  VectorOfunion_typespecFactory union_typespecVectMaker;
  logic_typespecFactory logic_typespecMaker;
  VectorOflogic_typespecFactory logic_typespecVectMaker;
  packed_array_typespecFactory packed_array_typespecMaker;
  VectorOfpacked_array_typespecFactory packed_array_typespecVectMaker;
  array_typespecFactory array_typespecMaker;
  VectorOfarray_typespecFactory array_typespecVectMaker;
  void_typespecFactory void_typespecMaker;
  VectorOfvoid_typespecFactory void_typespecVectMaker;
  unsupported_typespecFactory unsupported_typespecMaker;
  VectorOfunsupported_typespecFactory unsupported_typespecVectMaker;
  sequence_typespecFactory sequence_typespecMaker;
  VectorOfsequence_typespecFactory sequence_typespecVectMaker;
  property_typespecFactory property_typespecMaker;
  VectorOfproperty_typespecFactory property_typespecVectMaker;
  interface_typespecFactory interface_typespecMaker;
  VectorOfinterface_typespecFactory interface_typespecVectMaker;
  type_parameterFactory type_parameterMaker;
  VectorOftype_parameterFactory type_parameterVectMaker;
  typespec_memberFactory typespec_memberMaker;
  VectorOftypespec_memberFactory typespec_memberVectMaker;
  enum_constFactory enum_constMaker;
  VectorOfenum_constFactory enum_constVectMaker;
  bit_typespecFactory bit_typespecMaker;
  VectorOfbit_typespecFactory bit_typespecVectMaker;
  VectorOftf_callFactory tf_callVectMaker;
  user_systfFactory user_systfMaker;
  VectorOfuser_systfFactory user_systfVectMaker;
  sys_func_callFactory sys_func_callMaker;
  VectorOfsys_func_callFactory sys_func_callVectMaker;
  sys_task_callFactory sys_task_callMaker;
  VectorOfsys_task_callFactory sys_task_callVectMaker;
  method_func_callFactory method_func_callMaker;
  VectorOfmethod_func_callFactory method_func_callVectMaker;
  method_task_callFactory method_task_callMaker;
  VectorOfmethod_task_callFactory method_task_callVectMaker;
  func_callFactory func_callMaker;
  VectorOffunc_callFactory func_callVectMaker;
  task_callFactory task_callMaker;
  VectorOftask_callFactory task_callVectMaker;
  VectorOfconstraint_exprFactory constraint_exprVectMaker;
  constraint_orderingFactory constraint_orderingMaker;
  VectorOfconstraint_orderingFactory constraint_orderingVectMaker;
  constraintFactory constraintMaker;
  VectorOfconstraintFactory constraintVectMaker;
  import_typespecFactory import_typespecMaker;
  VectorOfimport_typespecFactory import_typespecVectMaker;
  dist_itemFactory dist_itemMaker;
  VectorOfdist_itemFactory dist_itemVectMaker;
  distributionFactory distributionMaker;
  VectorOfdistributionFactory distributionVectMaker;
  implicationFactory implicationMaker;
  VectorOfimplicationFactory implicationVectMaker;
  constr_ifFactory constr_ifMaker;
  VectorOfconstr_ifFactory constr_ifVectMaker;
  constr_if_elseFactory constr_if_elseMaker;
  VectorOfconstr_if_elseFactory constr_if_elseVectMaker;
  constr_foreachFactory constr_foreachMaker;
  VectorOfconstr_foreachFactory constr_foreachVectMaker;
  soft_disableFactory soft_disableMaker;
  VectorOfsoft_disableFactory soft_disableVectMaker;
  VectorOfgen_stmtFactory gen_stmtVectMaker;
  gen_ifFactory gen_ifMaker;
  VectorOfgen_ifFactory gen_ifVectMaker;
  gen_if_elseFactory gen_if_elseMaker;
  VectorOfgen_if_elseFactory gen_if_elseVectMaker;
  gen_forFactory gen_forMaker;
  VectorOfgen_forFactory gen_forVectMaker;
  gen_caseFactory gen_caseMaker;
  VectorOfgen_caseFactory gen_caseVectMaker;
  gen_regionFactory gen_regionMaker;
  VectorOfgen_regionFactory gen_regionVectMaker;
  designFactory designMaker;
  VectorOfdesignFactory designVectMaker;
#endif
};
};  // namespace UHDM

#endif
