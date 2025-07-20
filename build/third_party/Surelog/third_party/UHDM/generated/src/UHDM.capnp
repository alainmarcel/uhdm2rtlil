@0xfff7299129556877;

struct ObjIndexType {
  index @0 : UInt64;
  type  @1 : UInt32;
}

struct UhdmRoot {
  version  @0 : UInt32;
  objectId @1 : UInt32;
  designs  @2 : List(Design);
  symbols  @3 : List(Text);
  factoryAliasstmt @4 : List(Aliasstmt);
  factoryAlways @5 : List(Always);
  factoryAnypattern @6 : List(Anypattern);
  factoryArrayexpr @7 : List(Arrayexpr);
  factoryArraynet @8 : List(Arraynet);
  factoryArraytypespec @9 : List(Arraytypespec);
  factoryArrayvar @10 : List(Arrayvar);
  factoryAssertstmt @11 : List(Assertstmt);
  factoryAssignment @12 : List(Assignment);
  factoryAssignstmt @13 : List(Assignstmt);
  factoryAssume @14 : List(Assume);
  factoryAttribute @15 : List(Attribute);
  factoryBegin @16 : List(Begin);
  factoryBitselect @17 : List(Bitselect);
  factoryBittypespec @18 : List(Bittypespec);
  factoryBitvar @19 : List(Bitvar);
  factoryBreakstmt @20 : List(Breakstmt);
  factoryBytetypespec @21 : List(Bytetypespec);
  factoryBytevar @22 : List(Bytevar);
  factoryCaseitem @23 : List(Caseitem);
  factoryCaseproperty @24 : List(Caseproperty);
  factoryCasepropertyitem @25 : List(Casepropertyitem);
  factoryCasestmt @26 : List(Casestmt);
  factoryChandletypespec @27 : List(Chandletypespec);
  factoryChandlevar @28 : List(Chandlevar);
  factoryCheckerdecl @29 : List(Checkerdecl);
  factoryCheckerinst @30 : List(Checkerinst);
  factoryCheckerinstport @31 : List(Checkerinstport);
  factoryCheckerport @32 : List(Checkerport);
  factoryClassdefn @33 : List(Classdefn);
  factoryClassobj @34 : List(Classobj);
  factoryClasstypespec @35 : List(Classtypespec);
  factoryClassvar @36 : List(Classvar);
  factoryClockedproperty @37 : List(Clockedproperty);
  factoryClockedseq @38 : List(Clockedseq);
  factoryClockingblock @39 : List(Clockingblock);
  factoryClockingiodecl @40 : List(Clockingiodecl);
  factoryConstant @41 : List(Constant);
  factoryConstraint @42 : List(Constraint);
  factoryConstraintordering @43 : List(Constraintordering);
  factoryConstrforeach @44 : List(Constrforeach);
  factoryConstrif @45 : List(Constrif);
  factoryConstrifelse @46 : List(Constrifelse);
  factoryContassign @47 : List(Contassign);
  factoryContassignbit @48 : List(Contassignbit);
  factoryContinuestmt @49 : List(Continuestmt);
  factoryCover @50 : List(Cover);
  factoryDeassign @51 : List(Deassign);
  factoryDefparam @52 : List(Defparam);
  factoryDelaycontrol @53 : List(Delaycontrol);
  factoryDelayterm @54 : List(Delayterm);
  factoryDesign @55 : List(Design);
  factoryDisable @56 : List(Disable);
  factoryDisablefork @57 : List(Disablefork);
  factoryDistitem @58 : List(Distitem);
  factoryDistribution @59 : List(Distribution);
  factoryDowhile @60 : List(Dowhile);
  factoryEnumconst @61 : List(Enumconst);
  factoryEnumnet @62 : List(Enumnet);
  factoryEnumtypespec @63 : List(Enumtypespec);
  factoryEnumvar @64 : List(Enumvar);
  factoryEventcontrol @65 : List(Eventcontrol);
  factoryEventstmt @66 : List(Eventstmt);
  factoryEventtypespec @67 : List(Eventtypespec);
  factoryExpectstmt @68 : List(Expectstmt);
  factoryExtends @69 : List(Extends);
  factoryFinalstmt @70 : List(Finalstmt);
  factoryForce @71 : List(Force);
  factoryForeachstmt @72 : List(Foreachstmt);
  factoryForeverstmt @73 : List(Foreverstmt);
  factoryForkstmt @74 : List(Forkstmt);
  factoryForstmt @75 : List(Forstmt);
  factoryFunccall @76 : List(Funccall);
  factoryFunction @77 : List(Function);
  factoryGate @78 : List(Gate);
  factoryGatearray @79 : List(Gatearray);
  factoryGencase @80 : List(Gencase);
  factoryGenfor @81 : List(Genfor);
  factoryGenif @82 : List(Genif);
  factoryGenifelse @83 : List(Genifelse);
  factoryGenregion @84 : List(Genregion);
  factoryGenscope @85 : List(Genscope);
  factoryGenscopearray @86 : List(Genscopearray);
  factoryGenvar @87 : List(Genvar);
  factoryHierpath @88 : List(Hierpath);
  factoryIfelse @89 : List(Ifelse);
  factoryIfstmt @90 : List(Ifstmt);
  factoryImmediateassert @91 : List(Immediateassert);
  factoryImmediateassume @92 : List(Immediateassume);
  factoryImmediatecover @93 : List(Immediatecover);
  factoryImplication @94 : List(Implication);
  factoryImporttypespec @95 : List(Importtypespec);
  factoryIncludefileinfo @96 : List(Includefileinfo);
  factoryIndexedpartselect @97 : List(Indexedpartselect);
  factoryInitial @98 : List(Initial);
  factoryIntegernet @99 : List(Integernet);
  factoryIntegertypespec @100 : List(Integertypespec);
  factoryIntegervar @101 : List(Integervar);
  factoryInterfacearray @102 : List(Interfacearray);
  factoryInterfaceinst @103 : List(Interfaceinst);
  factoryInterfacetfdecl @104 : List(Interfacetfdecl);
  factoryInterfacetypespec @105 : List(Interfacetypespec);
  factoryInttypespec @106 : List(Inttypespec);
  factoryIntvar @107 : List(Intvar);
  factoryIodecl @108 : List(Iodecl);
  factoryLetdecl @109 : List(Letdecl);
  factoryLetexpr @110 : List(Letexpr);
  factoryLogicnet @111 : List(Logicnet);
  factoryLogictypespec @112 : List(Logictypespec);
  factoryLogicvar @113 : List(Logicvar);
  factoryLonginttypespec @114 : List(Longinttypespec);
  factoryLongintvar @115 : List(Longintvar);
  factoryMethodfunccall @116 : List(Methodfunccall);
  factoryMethodtaskcall @117 : List(Methodtaskcall);
  factoryModpath @118 : List(Modpath);
  factoryModport @119 : List(Modport);
  factoryModulearray @120 : List(Modulearray);
  factoryModuleinst @121 : List(Moduleinst);
  factoryModuletypespec @122 : List(Moduletypespec);
  factoryMulticlocksequenceexpr @123 : List(Multiclocksequenceexpr);
  factoryNamedbegin @124 : List(Namedbegin);
  factoryNamedevent @125 : List(Namedevent);
  factoryNamedeventarray @126 : List(Namedeventarray);
  factoryNamedfork @127 : List(Namedfork);
  factoryNetbit @128 : List(Netbit);
  factoryNullstmt @129 : List(Nullstmt);
  factoryOperation @130 : List(Operation);
  factoryOrderedwait @131 : List(Orderedwait);
  factoryPackage @132 : List(Package);
  factoryPackedarraynet @133 : List(Packedarraynet);
  factoryPackedarraytypespec @134 : List(Packedarraytypespec);
  factoryPackedarrayvar @135 : List(Packedarrayvar);
  factoryParamassign @136 : List(Paramassign);
  factoryParameter @137 : List(Parameter);
  factoryPartselect @138 : List(Partselect);
  factoryPathterm @139 : List(Pathterm);
  factoryPort @140 : List(Port);
  factoryPortbit @141 : List(Portbit);
  factoryPrimterm @142 : List(Primterm);
  factoryProgram @143 : List(Program);
  factoryProgramarray @144 : List(Programarray);
  factoryPropertydecl @145 : List(Propertydecl);
  factoryPropertyinst @146 : List(Propertyinst);
  factoryPropertyspec @147 : List(Propertyspec);
  factoryPropertytypespec @148 : List(Propertytypespec);
  factoryPropformaldecl @149 : List(Propformaldecl);
  factoryRange @150 : List(Range);
  factoryRealtypespec @151 : List(Realtypespec);
  factoryRealvar @152 : List(Realvar);
  factoryRefmodule @153 : List(Refmodule);
  factoryRefobj @154 : List(Refobj);
  factoryReftypespec @155 : List(Reftypespec);
  factoryRefvar @156 : List(Refvar);
  factoryReg @157 : List(Reg);
  factoryRegarray @158 : List(Regarray);
  factoryRelease @159 : List(Release);
  factoryRepeat @160 : List(Repeat);
  factoryRepeatcontrol @161 : List(Repeatcontrol);
  factoryRestrict @162 : List(Restrict);
  factoryReturnstmt @163 : List(Returnstmt);
  factorySeqformaldecl @164 : List(Seqformaldecl);
  factorySequencedecl @165 : List(Sequencedecl);
  factorySequenceinst @166 : List(Sequenceinst);
  factorySequencetypespec @167 : List(Sequencetypespec);
  factoryShortinttypespec @168 : List(Shortinttypespec);
  factoryShortintvar @169 : List(Shortintvar);
  factoryShortrealtypespec @170 : List(Shortrealtypespec);
  factoryShortrealvar @171 : List(Shortrealvar);
  factorySoftdisable @172 : List(Softdisable);
  factorySpecparam @173 : List(Specparam);
  factoryStringtypespec @174 : List(Stringtypespec);
  factoryStringvar @175 : List(Stringvar);
  factoryStructnet @176 : List(Structnet);
  factoryStructpattern @177 : List(Structpattern);
  factoryStructtypespec @178 : List(Structtypespec);
  factoryStructvar @179 : List(Structvar);
  factorySwitcharray @180 : List(Switcharray);
  factorySwitchtran @181 : List(Switchtran);
  factorySysfunccall @182 : List(Sysfunccall);
  factorySystaskcall @183 : List(Systaskcall);
  factoryTableentry @184 : List(Tableentry);
  factoryTaggedpattern @185 : List(Taggedpattern);
  factoryTask @186 : List(Task);
  factoryTaskcall @187 : List(Taskcall);
  factoryTchk @188 : List(Tchk);
  factoryTchkterm @189 : List(Tchkterm);
  factoryThreadobj @190 : List(Threadobj);
  factoryTimenet @191 : List(Timenet);
  factoryTimetypespec @192 : List(Timetypespec);
  factoryTimevar @193 : List(Timevar);
  factoryTypeparameter @194 : List(Typeparameter);
  factoryTypespecmember @195 : List(Typespecmember);
  factoryUdp @196 : List(Udp);
  factoryUdparray @197 : List(Udparray);
  factoryUdpdefn @198 : List(Udpdefn);
  factoryUniontypespec @199 : List(Uniontypespec);
  factoryUnionvar @200 : List(Unionvar);
  factoryUnsupportedexpr @201 : List(Unsupportedexpr);
  factoryUnsupportedstmt @202 : List(Unsupportedstmt);
  factoryUnsupportedtypespec @203 : List(Unsupportedtypespec);
  factoryUsersystf @204 : List(Usersystf);
  factoryVarbit @205 : List(Varbit);
  factoryVarselect @206 : List(Varselect);
  factoryVirtualinterfacevar @207 : List(Virtualinterfacevar);
  factoryVoidtypespec @208 : List(Voidtypespec);
  factoryWaitfork @209 : List(Waitfork);
  factoryWaitstmt @210 : List(Waitstmt);
  factoryWhilestmt @211 : List(Whilestmt);
}


struct Any {
  uhdmId @0 : UInt64;
  vpiParent @1 : ObjIndexType;
  vpiFile @2 : UInt64;
  vpiLineNo @3 : UInt32;
  vpiEndLineNo @4 : UInt32;
  vpiColumnNo @5 : UInt16;
  vpiEndColumnNo @6 : UInt16;
}

struct Attribute {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiDefAttribute @2 : Bool;
  vpiValue @3 : UInt64;
  vpiDefFile @4 : UInt64;
  vpiDefLineNo @5 : Int64;
}

struct Virtualinterfacevar {
  base @0: Any;
}

struct Letdecl {
  base @0: Any;
  expressions @1 : List(ObjIndexType);
  seqformaldecls @2 : List(UInt64);
  vpiName @3 : UInt64;
}

struct Concurrentassertions {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  vpiIsClockInferred @3 : Bool;
  clockingevent @4 : ObjIndexType;
  stmt @5 : ObjIndexType;
  vpiProperty @6 : ObjIndexType;
  attributes @7 : List(UInt64);
}

struct Processstmt {
  base @0: Any;
  stmt @1 : ObjIndexType;
  moduleinst @2 : UInt64;
  attributes @3 : List(UInt64);
}

struct Always {
  base @0: Processstmt;
  vpiAlwaysType @1 : Int64;
}

struct Finalstmt {
  base @0: Processstmt;
}

struct Initial {
  base @0: Processstmt;
}

struct Atomicstmt {
  base @0: Any;
  vpiName @1 : UInt64;
  attributes @2 : List(UInt64);
}

struct Delaycontrol {
  base @0: Atomicstmt;
  vpiDelay @1 : UInt64;
  stmt @2 : ObjIndexType;
  delay @3 : ObjIndexType;
}

struct Delayterm {
  base @0: Any;
}

struct Eventcontrol {
  base @0: Atomicstmt;
  vpiCondition @1 : ObjIndexType;
  stmt @2 : ObjIndexType;
}

struct Repeatcontrol {
  base @0: Atomicstmt;
}

struct Scope {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  propertydecls @3 : List(UInt64);
  sequencedecls @4 : List(UInt64);
  concurrentassertions @5 : List(ObjIndexType);
  namedevents @6 : List(UInt64);
  namedeventarrays @7 : List(UInt64);
  variables @8 : List(ObjIndexType);
  virtualinterfacevars @9 : List(UInt64);
  logicvars @10 : List(UInt64);
  arrayvars @11 : List(UInt64);
  arrayvarmems @12 : List(UInt64);
  parameters @13 : List(ObjIndexType);
  paramassigns @14 : List(UInt64);
  scopes @15 : List(ObjIndexType);
  typespecs @16 : List(ObjIndexType);
  instanceitems @17 : List(ObjIndexType);
  letdecls @18 : List(UInt64);
  attributes @19 : List(UInt64);
}

struct Begin {
  base @0: Scope;
  stmts @1 : List(ObjIndexType);
}

struct Namedbegin {
  base @0: Scope;
  stmts @1 : List(ObjIndexType);
  vpiEndLabel @2 : UInt64;
}

struct Namedfork {
  base @0: Scope;
  vpiJoinType @1 : Int64;
  stmts @2 : List(ObjIndexType);
  vpiEndLabel @3 : UInt64;
}

struct Forkstmt {
  base @0: Scope;
  vpiJoinType @1 : Int64;
  stmts @2 : List(ObjIndexType);
}

struct Forstmt {
  base @0: Scope;
  vpiLocalVarDecls @1 : Int64;
  vpiForInitStmts @2 : List(ObjIndexType);
  vpiForIncStmts @3 : List(ObjIndexType);
  vpiForInitStmt @4 : ObjIndexType;
  vpiCondition @5 : ObjIndexType;
  vpiForIncStmt @6 : ObjIndexType;
  vpiStmt @7 : ObjIndexType;
}

struct Ifstmt {
  base @0: Atomicstmt;
  vpiQualifier @1 : Int64;
  vpiCondition @2 : ObjIndexType;
  vpiStmt @3 : ObjIndexType;
}

struct Eventstmt {
  base @0: Atomicstmt;
  vpiBlocking @1 : Bool;
  namedevent @2 : UInt64;
}

struct Threadobj {
  base @0: Any;
}

struct Foreverstmt {
  base @0: Atomicstmt;
  vpiStmt @1 : ObjIndexType;
}

struct Waits {
  base @0: Atomicstmt;
  vpiStmt @1 : ObjIndexType;
}

struct Waitstmt {
  base @0: Waits;
  vpiCondition @1 : ObjIndexType;
}

struct Waitfork {
  base @0: Waits;
}

struct Orderedwait {
  base @0: Waits;
  vpiConditions @1 : List(ObjIndexType);
  vpiElseStmt @2 : ObjIndexType;
}

struct Disables {
  base @0: Atomicstmt;
}

struct Disable {
  base @0: Disables;
  vpiExpr @1 : ObjIndexType;
}

struct Disablefork {
  base @0: Disables;
}

struct Continuestmt {
  base @0: Atomicstmt;
}

struct Breakstmt {
  base @0: Atomicstmt;
}

struct Returnstmt {
  base @0: Atomicstmt;
  vpiCondition @1 : ObjIndexType;
}

struct Whilestmt {
  base @0: Atomicstmt;
  vpiCondition @1 : ObjIndexType;
  vpiStmt @2 : ObjIndexType;
}

struct Repeat {
  base @0: Atomicstmt;
  vpiCondition @1 : ObjIndexType;
  vpiStmt @2 : ObjIndexType;
}

struct Dowhile {
  base @0: Atomicstmt;
  vpiCondition @1 : ObjIndexType;
  vpiStmt @2 : ObjIndexType;
}

struct Ifelse {
  base @0: Atomicstmt;
  vpiQualifier @1 : Int64;
  vpiCondition @2 : ObjIndexType;
  vpiStmt @3 : ObjIndexType;
  vpiElseStmt @4 : ObjIndexType;
}

struct Casestmt {
  base @0: Atomicstmt;
  vpiRandType @1 : UInt64;
  vpiCaseType @2 : Int64;
  vpiQualifier @3 : Int64;
  vpiCondition @4 : ObjIndexType;
  caseitems @5 : List(UInt64);
}

struct Force {
  base @0: Atomicstmt;
  rhs @1 : ObjIndexType;
  lhs @2 : ObjIndexType;
}

struct Assignstmt {
  base @0: Atomicstmt;
  rhs @1 : ObjIndexType;
  lhs @2 : ObjIndexType;
}

struct Deassign {
  base @0: Atomicstmt;
  lhs @1 : ObjIndexType;
}

struct Release {
  base @0: Atomicstmt;
  lhs @1 : ObjIndexType;
}

struct Nullstmt {
  base @0: Atomicstmt;
}

struct Expectstmt {
  base @0: Atomicstmt;
  stmt @1 : ObjIndexType;
  elsestmt @2 : ObjIndexType;
  propertyspec @3 : UInt64;
}

struct Foreachstmt {
  base @0: Scope;
  variable @1 : ObjIndexType;
  vpiLoopVars @2 : List(ObjIndexType);
  vpiStmt @3 : ObjIndexType;
}

struct Genscope {
  base @0: Scope;
  vpiIndex @1 : ObjIndexType;
  vpiArrayMember @2 : Bool;
  vpiProtected @3 : Bool;
  vpiImplicitDecl @4 : Bool;
  nets @5 : List(ObjIndexType);
  arraynets @6 : List(UInt64);
  process @7 : List(ObjIndexType);
  contassigns @8 : List(UInt64);
  modules @9 : List(UInt64);
  modulearrays @10 : List(UInt64);
  primitives @11 : List(ObjIndexType);
  primitivearrays @12 : List(ObjIndexType);
  defparams @13 : List(UInt64);
  genscopearrays @14 : List(UInt64);
  programs @15 : List(UInt64);
  programarrays @16 : List(UInt64);
  assertions @17 : List(ObjIndexType);
  interfaces @18 : List(UInt64);
  interfacearrays @19 : List(UInt64);
  aliasstmts @20 : List(UInt64);
  clockingblocks @21 : List(UInt64);
  taskfuncs @22 : List(ObjIndexType);
  elabtasks @23 : List(ObjIndexType);
}

struct Genvar {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  genscopearrays @3 : List(UInt64);
}

struct Genscopearray {
  base @0: Any;
  vpiSize @1 : Int64;
  vpiName @2 : UInt64;
  vpiFullName @3 : UInt64;
  genvar @4 : UInt64;
  genscopes @5 : List(UInt64);
  vpiInstance @6 : ObjIndexType;
}

struct Assertstmt {
  base @0: Concurrentassertions;
  elsestmt @1 : ObjIndexType;
  clockingblock @2 : UInt64;
}

struct Cover {
  base @0: Concurrentassertions;
  vpiIsCoverSequence @1 : Bool;
  clockingblock @2 : UInt64;
}

struct Assume {
  base @0: Concurrentassertions;
  clockingblock @1 : UInt64;
}

struct Restrict {
  base @0: Concurrentassertions;
  clockingblock @1 : UInt64;
}

struct Immediateassert {
  base @0: Atomicstmt;
  vpiIsDeferred @1 : Int64;
  vpiIsFinal @2 : Int64;
  expr @3 : ObjIndexType;
  stmt @4 : ObjIndexType;
  elsestmt @5 : ObjIndexType;
  clockingblock @6 : UInt64;
}

struct Immediateassume {
  base @0: Atomicstmt;
  vpiIsDeferred @1 : Int64;
  vpiIsFinal @2 : Int64;
  expr @3 : ObjIndexType;
  stmt @4 : ObjIndexType;
  elsestmt @5 : ObjIndexType;
  clockingblock @6 : UInt64;
}

struct Immediatecover {
  base @0: Atomicstmt;
  vpiIsDeferred @1 : Int64;
  vpiIsFinal @2 : Int64;
  expr @3 : ObjIndexType;
  stmt @4 : ObjIndexType;
  clockingblock @5 : UInt64;
}

struct Expr {
  base @0: Any;
  vpiDecompile @1 : UInt64;
  vpiSize @2 : Int64;
  vpiValue @3 : UInt64;
  typespec @4 : ObjIndexType;
}

struct Caseitem {
  base @0: Any;
  vpiExprs @1 : List(ObjIndexType);
  stmt @2 : ObjIndexType;
}

struct Assignment {
  base @0: Atomicstmt;
  vpiOpType @1 : Int64;
  vpiBlocking @2 : Bool;
  rhs @3 : ObjIndexType;
  lhs @4 : ObjIndexType;
  delaycontrol @5 : UInt64;
  eventcontrol @6 : UInt64;
  repeatcontrol @7 : UInt64;
}

struct Anypattern {
  base @0: Any;
  vpiName @1 : UInt64;
}

struct Taggedpattern {
  base @0: Any;
  vpiName @1 : UInt64;
  pattern @2 : ObjIndexType;
  typespec @3 : ObjIndexType;
}

struct Structpattern {
  base @0: Any;
  vpiName @1 : UInt64;
  pattern @2 : ObjIndexType;
}

struct Unsupportedexpr {
  base @0: Expr;
}

struct Unsupportedstmt {
  base @0: Atomicstmt;
  vpiValue @1 : UInt64;
}

struct Includefileinfo {
  base @0: Any;
  vpiIncludedFile @1 : UInt64;
}

struct Sequenceinst {
  base @0: Any;
  sequencedecl @1 : UInt64;
  namedeventsequenceexprgroups @2 : List(ObjIndexType);
  vpiName @3 : UInt64;
  clockingblock @4 : UInt64;
}

struct Seqformaldecl {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiDirection @2 : Int64;
  attributes @3 : List(UInt64);
  namedeventsequenceexprgroup @4 : ObjIndexType;
  typespec @5 : ObjIndexType;
}

struct Sequencedecl {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  attributes @3 : List(UInt64);
  variables @4 : List(ObjIndexType);
  sequenceexprmulticlockgroup @5 : ObjIndexType;
  seqformaldecls @6 : List(UInt64);
}

struct Propformaldecl {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiDirection @2 : Int64;
  vpiExpr @3 : ObjIndexType;
  typespec @4 : ObjIndexType;
}

struct Propertyinst {
  base @0: Any;
  vpiDisableCondition @1 : ObjIndexType;
  vpiArguments @2 : List(ObjIndexType);
  propertydecl @3 : UInt64;
  vpiName @4 : UInt64;
  clockingblock @5 : UInt64;
}

struct Propertyspec {
  base @0: Any;
  vpiDisableCondition @1 : ObjIndexType;
  vpiClockingEvent @2 : ObjIndexType;
  vpiPropertyExpr @3 : ObjIndexType;
}

struct Propertydecl {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  attributes @3 : List(UInt64);
  propformaldecls @4 : List(UInt64);
  variables @5 : List(ObjIndexType);
  propertyspec @6 : UInt64;
}

struct Clockedproperty {
  base @0: Any;
  vpiClockingEvent @1 : ObjIndexType;
  vpiPropertyExpr @2 : ObjIndexType;
}

struct Casepropertyitem {
  base @0: Any;
  expressions @1 : List(ObjIndexType);
  propertyexpr @2 : ObjIndexType;
}

struct Caseproperty {
  base @0: Any;
  vpiCondition @1 : ObjIndexType;
  casepropertyitems @2 : List(UInt64);
}

struct Multiclocksequenceexpr {
  base @0: Any;
  clockedseqs @1 : List(UInt64);
}

struct Clockedseq {
  base @0: Any;
  vpiClockingEvent @1 : ObjIndexType;
  vpiSequenceExpr @2 : ObjIndexType;
}

struct Simpleexpr {
  base @0: Expr;
  vpiUses @1 : List(ObjIndexType);
}

struct Constant {
  base @0: Expr;
  vpiConstType @1 : Int64;
}

struct Letexpr {
  base @0: Expr;
  arguments @1 : List(ObjIndexType);
  letdecl @2 : UInt64;
}

struct Operation {
  base @0: Expr;
  vpiOpType @1 : Int64;
  vpiReordered @2 : Bool;
  vpiFlattened @3 : Bool;
  vpiOpStrong @4 : Bool;
  operands @5 : List(ObjIndexType);
  attributes @6 : List(UInt64);
}

struct Refobj {
  base @0: Simpleexpr;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  vpiDefName @3 : UInt64;
  vpiGeneric @4 : Bool;
  actualgroup @5 : ObjIndexType;
  vpiStructMember @6 : Bool;
}

struct Refmodule {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiDefName @2 : UInt64;
  actualgroup @3 : ObjIndexType;
  ports @4 : List(UInt64);
}

struct Reftypespec {
  base @0: Simpleexpr;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  vpiDefName @3 : UInt64;
  actualtypespec @4 : ObjIndexType;
}

struct Partselect {
  base @0: Refobj;
  vpiConstantSelect @1 : Bool;
  leftrange @2 : ObjIndexType;
  rightrange @3 : ObjIndexType;
}

struct Indexedpartselect {
  base @0: Refobj;
  vpiConstantSelect @1 : Bool;
  vpiIndexedPartSelectType @2 : Int64;
  baseexpr @3 : ObjIndexType;
  widthexpr @4 : ObjIndexType;
}

struct Varselect {
  base @0: Refobj;
  vpiConstantSelect @1 : Bool;
  expr @2 : ObjIndexType;
  exprs @3 : List(ObjIndexType);
}

struct Bitselect {
  base @0: Refobj;
  vpiConstantSelect @1 : Bool;
  vpiIndex @2 : ObjIndexType;
}

struct Variables {
  base @0: Simpleexpr;
  vpiArrayMember @1 : Bool;
  vpiName @2 : UInt64;
  vpiFullName @3 : UInt64;
  vpiSigned @4 : Bool;
  vpiAutomatic @5 : Bool;
  vpiAllocScheme @6 : Int64;
  vpiConstantVariable @7 : Bool;
  vpiIsRandomized @8 : Bool;
  vpiRandType @9 : Int64;
  vpiStructUnionMember @10 : Bool;
  vpiScalar @11 : Bool;
  vpiVisibility @12 : Int64;
  vpiVector @13 : Bool;
  ports @14 : List(ObjIndexType);
  variabledrivers @15 : List(ObjIndexType);
  variableloads @16 : List(ObjIndexType);
  primterms @17 : List(UInt64);
  contassigns @18 : List(UInt64);
  pathterm @19 : UInt64;
  tchkterm @20 : UInt64;
  moduleinst @21 : UInt64;
  instance @22 : ObjIndexType;
  scope @23 : ObjIndexType;
  expr @24 : ObjIndexType;
  indexes @25 : List(ObjIndexType);
  attributes @26 : List(UInt64);
}

struct Hierpath {
  base @0: Simpleexpr;
  pathelems @1 : List(ObjIndexType);
  rootvalue @2 : ObjIndexType;
  vpiName @3 : UInt64;
  vpiFullName @4 : UInt64;
}

struct Refvar {
  base @0: Variables;
  vpiDefName @1 : UInt64;
  vpiGeneric @2 : Bool;
  actualgroup @3 : ObjIndexType;
  taskfunc @4 : ObjIndexType;
  vpiStructMember @5 : Bool;
}

struct Shortrealvar {
  base @0: Variables;
}

struct Realvar {
  base @0: Variables;
}

struct Bytevar {
  base @0: Variables;
}

struct Shortintvar {
  base @0: Variables;
}

struct Intvar {
  base @0: Variables;
}

struct Longintvar {
  base @0: Variables;
}

struct Integervar {
  base @0: Variables;
}

struct Timevar {
  base @0: Variables;
}

struct Arrayvar {
  base @0: Variables;
  vpiArrayType @1 : Int64;
  varselects @2 : List(UInt64);
  ranges @3 : List(UInt64);
  leftexpr @4 : ObjIndexType;
  rightexpr @5 : ObjIndexType;
  variables @6 : List(ObjIndexType);
}

struct Arrayexpr {
  base @0: Expr;
  exprs @1 : List(ObjIndexType);
}

struct Regarray {
  base @0: Any;
  vpiIsMemory @1 : Bool;
  leftexpr @2 : ObjIndexType;
  rightexpr @3 : ObjIndexType;
  regs @4 : List(UInt64);
}

struct Reg {
  base @0: Any;
  leftexpr @1 : ObjIndexType;
  rightexpr @2 : ObjIndexType;
  index @3 : ObjIndexType;
}

struct Packedarrayvar {
  base @0: Variables;
  vpiPackedArrayMember @1 : Bool;
  vpiConstantSelect @2 : Bool;
  vpiPacked @3 : Bool;
  ranges @4 : List(UInt64);
  leftexpr @5 : ObjIndexType;
  rightexpr @6 : ObjIndexType;
  varbits @7 : List(UInt64);
  elements @8 : List(ObjIndexType);
  exprindex @9 : ObjIndexType;
}

struct Bitvar {
  base @0: Variables;
  ranges @1 : List(UInt64);
  leftexpr @2 : ObjIndexType;
  rightexpr @3 : ObjIndexType;
  varbits @4 : List(UInt64);
}

struct Logicvar {
  base @0: Variables;
  ranges @1 : List(UInt64);
  leftexpr @2 : ObjIndexType;
  rightexpr @3 : ObjIndexType;
  varbits @4 : List(UInt64);
}

struct Structvar {
  base @0: Variables;
  vpiPackedArrayMember @1 : Bool;
  vpiConstantSelect @2 : Bool;
  varbits @3 : List(UInt64);
  variables @4 : List(ObjIndexType);
  exprindex @5 : ObjIndexType;
}

struct Unionvar {
  base @0: Variables;
  vpiPackedArrayMember @1 : Bool;
  vpiConstantSelect @2 : Bool;
  varbits @3 : List(UInt64);
  variables @4 : List(ObjIndexType);
  exprindex @5 : ObjIndexType;
}

struct Enumvar {
  base @0: Variables;
  vpiPackedArrayMember @1 : Bool;
  vpiConstantSelect @2 : Bool;
  exprindex @3 : ObjIndexType;
}

struct Stringvar {
  base @0: Variables;
}

struct Chandlevar {
  base @0: Variables;
  actualgroup @1 : ObjIndexType;
}

struct Varbit {
  base @0: Variables;
  vpiConstantSelect @1 : Bool;
  exprindex @2 : ObjIndexType;
  exprindexes @3 : List(ObjIndexType);
}

struct Taskfunc {
  base @0: Scope;
  vpiMethod @1 : Bool;
  vpiAccessType @2 : Int64;
  vpiVisibility @3 : Int64;
  vpiVirtual @4 : Bool;
  vpiAutomatic @5 : Bool;
  vpiDPIPure @6 : Bool;
  vpiDPIContext @7 : Bool;
  vpiDPICStr @8 : Int64;
  vpiDPICIdentifier @9 : UInt64;
  leftrange @10 : ObjIndexType;
  rightrange @11 : ObjIndexType;
  return @12 : ObjIndexType;
  classdefn @13 : UInt64;
  iodecls @14 : List(UInt64);
  stmt @15 : ObjIndexType;
  instance @16 : ObjIndexType;
}

struct Task {
  base @0: Taskfunc;
}

struct Function {
  base @0: Taskfunc;
  vpiSigned @1 : Bool;
  vpiSize @2 : Int64;
  vpiFuncType @3 : Int64;
}

struct Modport {
  base @0: Any;
  vpiName @1 : UInt64;
  iodecls @2 : List(UInt64);
  interfaceinst @3 : UInt64;
}

struct Interfacetfdecl {
  base @0: Any;
  vpiAccessType @1 : UInt64;
  tasks @2 : List(UInt64);
  functions @3 : List(UInt64);
}

struct Contassign {
  base @0: Any;
  vpiNetDeclAssign @1 : Bool;
  vpiStrength0 @2 : Int64;
  vpiStrength1 @3 : Int64;
  vpiValue @4 : UInt64;
  delay @5 : ObjIndexType;
  rhs @6 : ObjIndexType;
  lhs @7 : ObjIndexType;
  contassignbits @8 : List(UInt64);
}

struct Contassignbit {
  base @0: Any;
  vpiOffset @1 : Int64;
  vpiNetDeclAssign @2 : Bool;
  vpiStrength0 @3 : Int64;
  vpiStrength1 @4 : Int64;
  vpiValue @5 : UInt64;
  delay @6 : ObjIndexType;
  rhs @7 : ObjIndexType;
  lhs @8 : ObjIndexType;
}

struct Ports {
  base @0: Any;
  vpiPortIndex @1 : Int64;
  vpiName @2 : UInt64;
  vpiPortType @3 : Int64;
  vpiScalar @4 : Bool;
  vpiVector @5 : Bool;
  vpiConnByName @6 : Bool;
  vpiDirection @7 : Int64;
  vpiSize @8 : Int64;
  vpiExplicitName @9 : UInt64;
  highconn @10 : ObjIndexType;
  lowconn @11 : ObjIndexType;
  typespec @12 : ObjIndexType;
  instance @13 : ObjIndexType;
  moduleinst @14 : UInt64;
}

struct Port {
  base @0: Ports;
  bits @1 : List(UInt64);
  attributes @2 : List(UInt64);
}

struct Portbit {
  base @0: Ports;
}

struct Checkerport {
  base @0: Ports;
  attributes @1 : List(UInt64);
  property @2 : UInt64;
  sequence @3 : UInt64;
}

struct Checkerinstport {
  base @0: Any;
  property @1 : UInt64;
  sequence @2 : UInt64;
}

struct Primitive {
  base @0: Any;
  vpiArrayMember @1 : Bool;
  vpiDefName @2 : UInt64;
  vpiDelay @3 : UInt64;
  vpiName @4 : UInt64;
  vpiFullName @5 : UInt64;
  vpiPrimType @6 : Int64;
  vpiStrength0 @7 : Int64;
  vpiStrength1 @8 : Int64;
  attributes @9 : List(UInt64);
  vpiValue @10 : UInt64;
  delay @11 : ObjIndexType;
  index @12 : ObjIndexType;
  primterms @13 : List(UInt64);
}

struct Gate {
  base @0: Primitive;
}

struct Switchtran {
  base @0: Primitive;
}

struct Udp {
  base @0: Primitive;
  udpdefn @1 : UInt64;
}

struct Modpath {
  base @0: Any;
  attributes @1 : List(UInt64);
}

struct Tchk {
  base @0: Any;
  moduleinst @1 : UInt64;
  expr @2 : ObjIndexType;
  exprtchkterms @3 : List(ObjIndexType);
  tchkrefterm @4 : UInt64;
  tchkdataterm @5 : UInt64;
  reg @6 : UInt64;
  vpiDelay @7 : UInt64;
  vpiTchkType @8 : Int64;
  attributes @9 : List(UInt64);
}

struct Range {
  base @0: Any;
  vpiSize @1 : Int64;
  leftexpr @2 : ObjIndexType;
  rightexpr @3 : ObjIndexType;
}

struct Udpdefn {
  base @0: Any;
  vpiDefName @1 : UInt64;
  vpiSize @2 : Int64;
  vpiProtected @3 : Bool;
  vpiPrimType @4 : Int64;
  attributes @5 : List(UInt64);
  iodecls @6 : List(UInt64);
  tableentrys @7 : List(UInt64);
  initial @8 : UInt64;
}

struct Tableentry {
  base @0: Any;
  vpiSize @1 : Int64;
  vpiValue @2 : UInt64;
  attributes @3 : List(UInt64);
}

struct Iodecl {
  base @0: Any;
  vpiDirection @1 : Int64;
  vpiName @2 : UInt64;
  vpiScalar @3 : Bool;
  vpiSigned @4 : Bool;
  vpiSize @5 : Int64;
  vpiVector @6 : Bool;
  expr @7 : ObjIndexType;
  leftexpr @8 : ObjIndexType;
  rightexpr @9 : ObjIndexType;
  ranges @10 : List(UInt64);
  typespec @11 : ObjIndexType;
}

struct Aliasstmt {
  base @0: Any;
}

struct Clockingblock {
  base @0: Scope;
  vpiInputEdge @1 : Int64;
  vpiOutputEdge @2 : Int64;
  inputskew @3 : UInt64;
  outputskew @4 : UInt64;
  clockingevent @5 : UInt64;
  instance @6 : ObjIndexType;
  clockingiodecls @7 : List(UInt64);
  prefix @8 : UInt64;
  actual @9 : UInt64;
}

struct Clockingiodecl {
  base @0: Any;
  vpiDirection @1 : Int64;
  vpiName @2 : UInt64;
  vpiInputEdge @3 : Int64;
  vpiOutputEdge @4 : Int64;
  inputskew @5 : UInt64;
  outputskew @6 : UInt64;
  expr @7 : ObjIndexType;
}

struct Paramassign {
  base @0: Any;
  vpiConnByName @1 : Bool;
  vpiOverriden @2 : Bool;
  rhs @3 : ObjIndexType;
  lhs @4 : ObjIndexType;
  attributes @5 : List(UInt64);
}

struct Instancearray {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  vpiSize @3 : Int64;
  expr @4 : ObjIndexType;
  ranges @5 : List(UInt64);
  leftexpr @6 : ObjIndexType;
  rightexpr @7 : ObjIndexType;
  instances @8 : List(ObjIndexType);
  modules @9 : List(UInt64);
  elemtypespec @10 : ObjIndexType;
  ports @11 : List(UInt64);
}

struct Interfacearray {
  base @0: Instancearray;
  paramassigns @1 : List(UInt64);
}

struct Programarray {
  base @0: Instancearray;
}

struct Modulearray {
  base @0: Instancearray;
  paramassigns @1 : List(UInt64);
}

struct Primitivearray {
  base @0: Instancearray;
  delay @1 : ObjIndexType;
  primitives @2 : List(ObjIndexType);
}

struct Gatearray {
  base @0: Primitivearray;
}

struct Switcharray {
  base @0: Primitivearray;
}

struct Udparray {
  base @0: Primitivearray;
}

struct Typespec {
  base @0: Any;
  vpiName @1 : UInt64;
  typedefalias @2 : ObjIndexType;
  instance @3 : ObjIndexType;
}

struct Netdrivers {
  base @0: Any;
}

struct Netloads {
  base @0: Any;
}

struct Primterm {
  base @0: Any;
  vpiDirection @1 : Int64;
  vpiTermIndex @2 : Int64;
  vpiValue @3 : UInt64;
  attributes @4 : List(UInt64);
  expr @5 : ObjIndexType;
}

struct Pathterm {
  base @0: Any;
  attributes @1 : List(UInt64);
}

struct Tchkterm {
  base @0: Any;
  expr @1 : ObjIndexType;
  condition @2 : ObjIndexType;
  vpiEdge @3 : Int64;
}

struct Nets {
  base @0: Simpleexpr;
  vpiArrayMember @1 : Bool;
  vpiConstantSelect @2 : Bool;
  vpiExpanded @3 : Bool;
  vpiImplicitDecl @4 : Bool;
  vpiName @5 : UInt64;
  vpiFullName @6 : UInt64;
  vpiNetDeclAssign @7 : Bool;
  vpiNetType @8 : Int64;
  vpiResolvedNetType @9 : Int64;
  vpiScalar @10 : Bool;
  vpiExplicitScalared @11 : Bool;
  vpiSigned @12 : Bool;
  vpiStrength0 @13 : Int64;
  vpiStrength1 @14 : Int64;
  vpiChargeStrength @15 : Int64;
  vpiVector @16 : Bool;
  vpiExplicitVectored @17 : Bool;
  vpiStructUnionMember @18 : Bool;
  ports @19 : List(ObjIndexType);
  drivers @20 : List(ObjIndexType);
  loads @21 : List(ObjIndexType);
  localdrivers @22 : List(ObjIndexType);
  localloads @23 : List(ObjIndexType);
  primterms @24 : List(UInt64);
  contassigns @25 : List(UInt64);
  pathterms @26 : List(UInt64);
  tchkterms @27 : List(UInt64);
  simnet @28 : ObjIndexType;
  moduleinst @29 : UInt64;
}

struct Netbit {
  base @0: Nets;
  exprs @1 : List(ObjIndexType);
}

struct Net {
  base @0: Nets;
  netbits @1 : List(UInt64);
  attributes @2 : List(UInt64);
  exprs @3 : List(ObjIndexType);
}

struct Structnet {
  base @0: Net;
  vpiPackedArrayMember @1 : Bool;
  nets @2 : List(ObjIndexType);
}

struct Enumnet {
  base @0: Net;
  vpiPackedArrayMember @1 : Bool;
}

struct Integernet {
  base @0: Net;
}

struct Timenet {
  base @0: Net;
}

struct Logicnet {
  base @0: Net;
  leftexpr @1 : ObjIndexType;
  rightexpr @2 : ObjIndexType;
  ranges @3 : List(UInt64);
}

struct Arraynet {
  base @0: Nets;
  ranges @1 : List(UInt64);
  nets @2 : List(ObjIndexType);
  attributes @3 : List(UInt64);
}

struct Packedarraynet {
  base @0: Net;
  vpiPackedArrayMember @1 : Bool;
  leftexpr @2 : ObjIndexType;
  rightexpr @3 : ObjIndexType;
  ranges @4 : List(UInt64);
  elements @5 : List(ObjIndexType);
}

struct Eventtypespec {
  base @0: Typespec;
}

struct Namedevent {
  base @0: Any;
  vpiArrayMember @1 : Bool;
  vpiName @2 : UInt64;
  vpiFullName @3 : UInt64;
  vpiAutomatic @4 : Bool;
  vpiAllocScheme @5 : Int64;
  attributes @6 : List(UInt64);
  eventtypespec @7 : UInt64;
  threads @8 : List(UInt64);
  vpiEndLabel @9 : UInt64;
}

struct Namedeventarray {
  base @0: Any;
}

struct Parameter {
  base @0: Simpleexpr;
  vpiConstType @1 : Int64;
  vpiSigned @2 : Bool;
  expr @3 : ObjIndexType;
  ranges @4 : List(UInt64);
  leftrange @5 : ObjIndexType;
  rightrange @6 : ObjIndexType;
  vpiLocalParam @7 : Bool;
  vpiName @8 : UInt64;
  vpiFullName @9 : UInt64;
  vpiImported @10 : UInt64;
}

struct Defparam {
  base @0: Any;
  rhs @1 : ObjIndexType;
  lhs @2 : UInt64;
}

struct Specparam {
  base @0: Simpleexpr;
  attributes @1 : List(UInt64);
}

struct Classtypespec {
  base @0: Typespec;
  vpiClassType @1 : Int64;
  vpiAutomatic @2 : Bool;
  extends @3 : UInt64;
  variables @4 : List(ObjIndexType);
  taskfuncs @5 : List(ObjIndexType);
  constraints @6 : List(UInt64);
  parameters @7 : List(ObjIndexType);
  paramassigns @8 : List(UInt64);
  virtualinterfacevars @9 : List(UInt64);
  namedevents @10 : List(UInt64);
  namedeventarrays @11 : List(UInt64);
  scopes @12 : List(ObjIndexType);
  classdefn @13 : UInt64;
}

struct Extends {
  base @0: Any;
  classtypespec @1 : UInt64;
  arguments @2 : List(ObjIndexType);
}

struct Classdefn {
  base @0: Scope;
  vpiVirtual @1 : Bool;
  vpiAutomatic @2 : Bool;
  extends @3 : UInt64;
  taskfuncs @4 : List(ObjIndexType);
  constraints @5 : List(UInt64);
  deriveds @6 : List(UInt64);
  classtypespecs @7 : List(UInt64);
  vpiEndLabel @8 : UInt64;
}

struct Classobj {
  base @0: Scope;
  vpiObjId @1 : Int64;
  classtypespec @2 : UInt64;
  threads @3 : List(UInt64);
  messages @4 : List(ObjIndexType);
  taskfuncs @5 : List(ObjIndexType);
  constraints @6 : List(UInt64);
}

struct Classvar {
  base @0: Variables;
  vpiObjId @1 : Int64;
  classobj @2 : UInt64;
}

struct Instance {
  base @0: Scope;
  vpiDefName @1 : UInt64;
  vpiArrayMember @2 : Bool;
  vpiCellInstance @3 : Bool;
  vpiDefNetType @4 : Int64;
  vpiDefFile @5 : UInt64;
  vpiDefLineNo @6 : Int64;
  vpiDefDelayMode @7 : Int64;
  vpiProtected @8 : Bool;
  vpiTimePrecision @9 : Int64;
  vpiTimeUnit @10 : Int64;
  vpiUnconnDrive @11 : Int64;
  vpiLibrary @12 : UInt64;
  vpiCell @13 : UInt64;
  vpiConfig @14 : UInt64;
  vpiAutomatic @15 : Bool;
  vpiTop @16 : Bool;
  programs @17 : List(UInt64);
  programarrays @18 : List(UInt64);
  classdefns @19 : List(UInt64);
  taskfuncs @20 : List(ObjIndexType);
  nets @21 : List(ObjIndexType);
  arraynets @22 : List(UInt64);
  specparams @23 : List(UInt64);
  assertions @24 : List(ObjIndexType);
  moduleinst @25 : UInt64;
  instance @26 : ObjIndexType;
}

struct Interfaceinst {
  base @0: Instance;
  vpiIndex @1 : Int64;
  interfacetfdecls @2 : List(UInt64);
  modports @3 : List(UInt64);
  globalclocking @4 : UInt64;
  defaultclocking @5 : UInt64;
  exprdist @6 : ObjIndexType;
  instancearray @7 : ObjIndexType;
  modpaths @8 : List(UInt64);
  contassigns @9 : List(UInt64);
  clockingblocks @10 : List(UInt64);
  interfaces @11 : List(UInt64);
  interfacearrays @12 : List(UInt64);
  process @13 : List(ObjIndexType);
  ports @14 : List(UInt64);
  genscopearrays @15 : List(UInt64);
  elabtasks @16 : List(ObjIndexType);
  genstmts @17 : List(ObjIndexType);
  vpiEndLabel @18 : UInt64;
}

struct Program {
  base @0: Instance;
  vpiIndex @1 : Int64;
  defaultclocking @2 : UInt64;
  instancearray @3 : ObjIndexType;
  interfaces @4 : List(UInt64);
  exprdist @5 : ObjIndexType;
  interfacearrays @6 : List(UInt64);
  process @7 : List(ObjIndexType);
  contassigns @8 : List(UInt64);
  clockingblocks @9 : List(UInt64);
  ports @10 : List(UInt64);
  genscopearrays @11 : List(UInt64);
  vpiEndLabel @12 : UInt64;
}

struct Package {
  base @0: Instance;
  vpiUnit @1 : Bool;
  vpiEndLabel @2 : UInt64;
}

struct Moduleinst {
  base @0: Instance;
  vpiIndex @1 : Int64;
  vpiTopModule @2 : Bool;
  vpiDefDecayTime @3 : Int64;
  globalclocking @4 : UInt64;
  defaultclocking @5 : UInt64;
  exprdist @6 : ObjIndexType;
  modulearray @7 : UInt64;
  instancearray @8 : ObjIndexType;
  ports @9 : List(UInt64);
  interfaces @10 : List(UInt64);
  interfacearrays @11 : List(UInt64);
  process @12 : List(ObjIndexType);
  modules @13 : List(UInt64);
  modulearrays @14 : List(UInt64);
  genscopearrays @15 : List(UInt64);
  contassigns @16 : List(UInt64);
  primitives @17 : List(ObjIndexType);
  primitivearrays @18 : List(ObjIndexType);
  modpaths @19 : List(UInt64);
  tchks @20 : List(UInt64);
  defparams @21 : List(UInt64);
  iodecls @22 : List(UInt64);
  aliasstmts @23 : List(UInt64);
  clockingblocks @24 : List(UInt64);
  elabtasks @25 : List(ObjIndexType);
  refmodules @26 : List(UInt64);
  genstmts @27 : List(ObjIndexType);
  vpiEndLabel @28 : UInt64;
}

struct Checkerdecl {
  base @0: Instance;
  defaultclocking @1 : UInt64;
  process @2 : List(ObjIndexType);
  contassigns @3 : List(UInt64);
  ports @4 : List(UInt64);
}

struct Checkerinst {
  base @0: Instance;
  ports @1 : List(UInt64);
}

struct Shortrealtypespec {
  base @0: Typespec;
  resolutionfunc @1 : UInt64;
}

struct Realtypespec {
  base @0: Typespec;
  resolutionfunc @1 : UInt64;
}

struct Bytetypespec {
  base @0: Typespec;
  vpiSigned @1 : Bool;
}

struct Shortinttypespec {
  base @0: Typespec;
  vpiSigned @1 : Bool;
}

struct Inttypespec {
  base @0: Typespec;
  vpiValue @1 : UInt64;
  casttoexpr @2 : ObjIndexType;
  vpiSigned @3 : Bool;
  ranges @4 : List(UInt64);
}

struct Longinttypespec {
  base @0: Typespec;
  vpiSigned @1 : Bool;
}

struct Integertypespec {
  base @0: Typespec;
  vpiValue @1 : UInt64;
  expr @2 : ObjIndexType;
  vpiSigned @3 : Bool;
}

struct Timetypespec {
  base @0: Typespec;
  vpiSigned @1 : Bool;
}

struct Enumtypespec {
  base @0: Typespec;
  basetypespec @1 : ObjIndexType;
  enumconsts @2 : List(UInt64);
}

struct Stringtypespec {
  base @0: Typespec;
}

struct Chandletypespec {
  base @0: Typespec;
}

struct Moduletypespec {
  base @0: Typespec;
}

struct Structtypespec {
  base @0: Typespec;
  vpiPacked @1 : Bool;
  members @2 : List(UInt64);
  resolutionfunc @3 : UInt64;
}

struct Uniontypespec {
  base @0: Typespec;
  vpiPacked @1 : Bool;
  vpiTagged @2 : Bool;
  members @3 : List(UInt64);
}

struct Logictypespec {
  base @0: Typespec;
  vpiVector @1 : Bool;
  elemtypespec @2 : UInt64;
  ranges @3 : List(UInt64);
  leftexpr @4 : ObjIndexType;
  rightexpr @5 : ObjIndexType;
  indextypespec @6 : ObjIndexType;
  vpiSigned @7 : Bool;
  resolutionfunc @8 : UInt64;
}

struct Packedarraytypespec {
  base @0: Typespec;
  vpiVector @1 : Bool;
  ranges @2 : List(UInt64);
  leftexpr @3 : ObjIndexType;
  rightexpr @4 : ObjIndexType;
  elemtypespec @5 : ObjIndexType;
  typespec @6 : ObjIndexType;
  resolutionfunc @7 : UInt64;
}

struct Arraytypespec {
  base @0: Typespec;
  vpiArrayType @1 : Int64;
  ranges @2 : List(UInt64);
  leftexpr @3 : ObjIndexType;
  rightexpr @4 : ObjIndexType;
  indextypespec @5 : ObjIndexType;
  elemtypespec @6 : ObjIndexType;
  resolutionfunc @7 : UInt64;
}

struct Voidtypespec {
  base @0: Typespec;
}

struct Unsupportedtypespec {
  base @0: Typespec;
  vpiPacked @1 : Bool;
  ranges @2 : List(UInt64);
}

struct Sequencetypespec {
  base @0: Typespec;
}

struct Propertytypespec {
  base @0: Typespec;
}

struct Interfacetypespec {
  base @0: Typespec;
  vpiDefName @1 : UInt64;
  vpiIsModPort @2 : Bool;
  paramassigns @3 : List(UInt64);
}

struct Typeparameter {
  base @0: Typespec;
  vpiLocalParam @1 : Bool;
  vpiFullName @2 : UInt64;
  typespec @3 : ObjIndexType;
  expr @4 : ObjIndexType;
  vpiImported @5 : UInt64;
}

struct Typespecmember {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiRandType @2 : Bool;
  typespec @3 : ObjIndexType;
  defaultvalue @4 : ObjIndexType;
  vpiRefFile @5 : UInt64;
  vpiRefLineNo @6 : Int64;
  vpiRefColumnNo @7 : Int64;
  vpiRefEndLineNo @8 : Int64;
  vpiRefEndColumnNo @9 : Int64;
}

struct Enumconst {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiValue @2 : UInt64;
  vpiDecompile @3 : UInt64;
  vpiSize @4 : Int64;
}

struct Bittypespec {
  base @0: Typespec;
  vpiVector @1 : Bool;
  bittypespec @2 : UInt64;
  ranges @3 : List(UInt64);
  leftexpr @4 : ObjIndexType;
  rightexpr @5 : ObjIndexType;
  typespec @6 : ObjIndexType;
  vpiSigned @7 : Bool;
  resolutionfunc @8 : UInt64;
}

struct Tfcall {
  base @0: Expr;
  scope @1 : ObjIndexType;
  tfcallargs @2 : List(ObjIndexType);
  vpiName @3 : UInt64;
}

struct Usersystf {
  base @0: Any;
}

struct Sysfunccall {
  base @0: Tfcall;
  vpiFuncType @1 : Int64;
  vpiUserDefn @2 : Bool;
  usersystf @3 : UInt64;
}

struct Systaskcall {
  base @0: Tfcall;
  vpiUserDefn @1 : Bool;
  usersystf @2 : UInt64;
}

struct Methodfunccall {
  base @0: Tfcall;
  vpiUserDefn @1 : Bool;
  prefix @2 : ObjIndexType;
  with @3 : ObjIndexType;
  function @4 : UInt64;
}

struct Methodtaskcall {
  base @0: Tfcall;
  vpiUserDefn @1 : Bool;
  prefix @2 : ObjIndexType;
  with @3 : ObjIndexType;
  task @4 : UInt64;
}

struct Funccall {
  base @0: Tfcall;
  vpiFuncType @1 : Int64;
  function @2 : UInt64;
}

struct Taskcall {
  base @0: Tfcall;
  task @1 : UInt64;
}

struct Constraintexpr {
  base @0: Any;
}

struct Constraintordering {
  base @0: Any;
  solvebefores @1 : List(ObjIndexType);
  solveafters @2 : List(ObjIndexType);
}

struct Constraint {
  base @0: Any;
  vpiName @1 : UInt64;
  vpiFullName @2 : UInt64;
  vpiVirtual @3 : Bool;
  vpiAutomatic @4 : Bool;
  vpiAllocScheme @5 : Int64;
  vpiAccessType @6 : Int64;
  attributes @7 : List(UInt64);
  vpiIsConstraintEnabled @8 : Bool;
  constraintitems @9 : List(ObjIndexType);
}

struct Importtypespec {
  base @0: Typespec;
  item @1 : UInt64;
}

struct Distitem {
  base @0: Any;
  vpiDistType @1 : Int64;
  valuerange @2 : ObjIndexType;
  weight @3 : ObjIndexType;
}

struct Distribution {
  base @0: Constraintexpr;
  vpiSoft @1 : Bool;
  distitems @2 : List(UInt64);
  expr @3 : ObjIndexType;
}

struct Implication {
  base @0: Constraintexpr;
  condition @1 : ObjIndexType;
  constraintexprs @2 : List(ObjIndexType);
}

struct Constrif {
  base @0: Constraintexpr;
  condition @1 : ObjIndexType;
  constraintexprs @2 : List(ObjIndexType);
}

struct Constrifelse {
  base @0: Constraintexpr;
  condition @1 : ObjIndexType;
  constraintexprs @2 : List(ObjIndexType);
  elseconstraintexprs @3 : List(ObjIndexType);
}

struct Constrforeach {
  base @0: Constraintexpr;
  variable @1 : ObjIndexType;
  vpiLoopVars @2 : List(ObjIndexType);
  constraintexprs @3 : List(ObjIndexType);
}

struct Softdisable {
  base @0: Constraintexpr;
  expr @1 : ObjIndexType;
}

struct Genstmt {
  base @0: Any;
  vpiName @1 : UInt64;
  attributes @2 : List(UInt64);
}

struct Genif {
  base @0: Genstmt;
  vpiCondition @1 : ObjIndexType;
  vpiStmt @2 : ObjIndexType;
}

struct Genifelse {
  base @0: Genstmt;
  vpiCondition @1 : ObjIndexType;
  vpiStmt @2 : ObjIndexType;
  vpiElseStmt @3 : ObjIndexType;
}

struct Genfor {
  base @0: Genstmt;
  vpiLocalVarDecls @1 : Int64;
  vpiForInitStmts @2 : List(ObjIndexType);
  vpiForIncStmts @3 : List(ObjIndexType);
  vpiForInitStmt @4 : ObjIndexType;
  vpiCondition @5 : ObjIndexType;
  vpiForIncStmt @6 : ObjIndexType;
  vpiStmt @7 : ObjIndexType;
}

struct Gencase {
  base @0: Genstmt;
  vpiCondition @1 : ObjIndexType;
  caseitems @2 : List(UInt64);
}

struct Genregion {
  base @0: Genstmt;
  vpiStmt @1 : ObjIndexType;
}

struct Design {
  base @0: Any;
  vpiElaborated @1 : Bool;
  vpiName @2 : UInt64;
  includefileinfos @3 : List(UInt64);
  allPackages @4 : List(UInt64);
  topPackages @5 : List(UInt64);
  allClasses @6 : List(UInt64);
  allInterfaces @7 : List(UInt64);
  allUdps @8 : List(UInt64);
  allPrograms @9 : List(UInt64);
  allModules @10 : List(UInt64);
  typespecs @11 : List(ObjIndexType);
  letdecls @12 : List(UInt64);
  taskfuncs @13 : List(ObjIndexType);
  parameters @14 : List(ObjIndexType);
  paramassigns @15 : List(UInt64);
  topModules @16 : List(UInt64);
}

