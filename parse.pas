
/(**************************************************************************
/(**
/(** parse.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

#include 'common.h'
#include 'parse.h'
#include 'symbol.h'
#include 'pcode.h'
#include 'token.h'
#include 'error.h'
#include 'misc.h'
#include 'strlist.h'

// MACROS ------------------------------------------------------------------

#define MAX_STATEMENT_DEPTH 128
#define MAX_BREAK 128
#define MAX_CONTINUE 128
#define MAX_CASE 128
#define EXPR_STACK_DEPTH 64

// TYPES -------------------------------------------------------------------

typedef enum
begin
  STMT_SCRIPT,
  STMT_IF,
  STMT_ELSE,
  STMT_DO,
  STMT_WHILEUNTIL,
  STMT_SWITCH,
  STMT_FOR
  end; statement_t;

typedef struct
begin
  level: integer;
  addressPtr: integer;
  end; breakInfo_t;

typedef struct
begin
  level: integer;
  addressPtr: integer;
  end; continueInfo_t;

typedef struct
begin
  level: integer;
  value: integer;
  boolean isDefault;
  address: integer;
  end; caseInfo_t;

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

static void Outside;
static void OuterScript;
static void OuterMapVar;
static void OuterWorldVar;
static void OuterSpecialDef;
static void OuterDefine;
static void OuterInclude;
static boolean ProcessStatement(statement_t owner);
static void LeadingCompoundStatement(statement_t owner);
static void LeadingVarDeclare;
static void LeadingLineSpecial;
static void LeadingIdentifier;
static void LeadingPrint;
static void LeadingVarAssign(symbolNode_t *sym);
static pcd_t GetAssignPCD(tokenType_t token, symbolType_t symbol);
static void LeadingInternFunc(symbolNode_t *sym);
static void LeadingSuspend;
static void LeadingTerminate;
static void LeadingRestart;
static void LeadingIf;
static void LeadingFor;
static void LeadingWhileUntil;
static void LeadingDo;
static void LeadingSwitch;
static void LeadingCase;
static void LeadingDefault;
static void LeadingBreak;
static void LeadingContinue;
static void PushCase(int value, boolean isDefault);
static caseInfo_t *GetCaseInfo;
static boolean DefaultInCurrent;
static void PushBreak;
static void WriteBreaks;
static boolean BreakAncestor;
static void PushContinue;
static void WriteContinues(int address);
static boolean ContinueAncestor;
static void ProcessInternFunc(symbolNode_t *sym);
static void EvalExpression;
static void ExprLevA;
static void ExprLevB;
static void ExprLevC;
static void ExprLevD;
static void ExprLevE;
static void ExprLevF;
static void ExprLevG;
static void ExprLevH;
static void ExprLevI;
static void ExprLevJ;
static void ExprFactor;
static void ConstExprFactor;
static void SendExprCommand(pcd_t pcd);
static void PushExStk(int value);
static int PopExStk;
static pcd_t TokenToPCD(tokenType_t token);
static pcd_t GetPushVarPCD(symbolType_t symType);
static pcd_t GetIncDecPCD(tokenType_t token, symbolType_t symbol);
static int EvalConstExpression;
static symbolNode_t *DemandSymbol(char *name);

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

// PUBLIC DATA DEFINITIONS -------------------------------------------------

  pa_ScriptCount: integer;
  pa_OpenScriptCount: integer;
  pa_MapVarCount: integer;
  pa_WorldVarCount: integer;

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static int ScriptVarCount;
static statement_t StatementHistory[MAX_STATEMENT_DEPTH];
static int StatementIndex;
static breakInfo_t BreakInfo[MAX_BREAK];
static int BreakIndex;
static continueInfo_t ContinueInfo[MAX_CONTINUE];
static int ContinueIndex;
static caseInfo_t CaseInfo[MAX_CASE];
static int CaseIndex;
static int StatementLevel;
static int ExprStack[EXPR_STACK_DEPTH];
static int ExprStackIndex;
static boolean ConstantExpression;

static int AdjustStmtLevel[] := 
begin
  0,    // STMT_SCRIPT
  0,    // STMT_IF
  0,    // STMT_ELSE
  1,    // STMT_DO
  1,    // STMT_WHILEUNTIL
  1,    // STMT_SWITCH
  1    // STMT_FOR
  end;

static boolean IsBreakRoot[] := 
begin
  NO,    // STMT_SCRIPT
  NO,    // STMT_IF
  NO,    // STMT_ELSE
  YES,  // STMT_DO
  YES,  // STMT_WHILEUNTIL
  YES,  // STMT_SWITCH
  YES    // STMT_FOR
  end;

static boolean IsContinueRoot[] := 
begin
  NO,    // STMT_SCRIPT
  NO,    // STMT_IF
  NO,    // STMT_ELSE
  YES,  // STMT_DO
  YES,  // STMT_WHILEUNTIL
  NO,    // STMT_SWITCH
  YES    // STMT_FOR
  end;

static tokenType_t LevFOps[] := 
begin
  TK_EQ,
  TK_NE,
  TK_NONE
  end;

static tokenType_t LevGOps[] := 
begin
  TK_LT,
  TK_LE,
  TK_GT,
  TK_GE,
  TK_NONE
  end;

static tokenType_t LevHOps[] := 
begin
  TK_LSHIFT,
  TK_RSHIFT,
  TK_NONE
  end;

static tokenType_t LevIOps[] := 
begin
  TK_PLUS,
  TK_MINUS,
  TK_NONE
  end;

static tokenType_t LevJOps[] := 
begin
  TK_ASTERISK,
  TK_SLASH,
  TK_PERCENT,
  TK_NONE
  end;

static tokenType_t AssignOps[] := 
begin
  TK_ASSIGN,
  TK_ADDASSIGN,
  TK_SUBASSIGN,
  TK_MULASSIGN,
  TK_DIVASSIGN,
  TK_MODASSIGN,
  TK_NONE
  end;

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PA_Parse
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure PA_Parse;
begin
  pa_ScriptCount :=  0;
  pa_OpenScriptCount :=  0;
  pa_MapVarCount :=  0;
  pa_WorldVarCount :=  0;
  TK_NextToken;
  Outside;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// Outside
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void Outside;
begin
  boolean done;

  done :=  NO;
  while done = NO do
  begin
    switch(tk_Token)
    begin
      TK_EOF:
        done :=  YES;
        break;
      TK_SCRIPT:
        OuterScript;
        break;
      TK_INT:
      TK_STR:
        OuterMapVar;
        break;
      TK_WORLD:
        OuterWorldVar;
        break;
      TK_SPECIAL:
        OuterSpecialDef;
        break;
      TK_NUMBERSIGN:
        TK_NextToken;
        switch(tk_Token)
        begin
          TK_DEFINE:
            OuterDefine;
            break;
          TK_INCLUDE:
            OuterInclude;
            break;
          default:
            ERR_Exit(ERR_INVALID_DIRECTIVE, YES, NULL);
            break;
         end;
        break;
      default:
        ERR_Exit(ERR_INVALID_DECLARATOR, YES, NULL);
        break;
        end;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OuterScript
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OuterScript;
begin
  scriptNumber: integer;
  symbolNode_t *sym;

  MS_Message(MSG_DEBUG, '---- OuterScript ----\n');
  BreakIndex :=  0;
  CaseIndex :=  0;
  StatementLevel :=  0;
  ScriptVarCount :=  0;
  SY_FreeLocals;
  TK_NextToken;
  scriptNumber :=  EvalConstExpression;
  MS_Message(MSG_DEBUG, 'Script number: %d\n', scriptNumber);
  if tk_Token = TK_LPAREN then
  begin
    if TK_NextToken = TK_VOID then
    begin
      TK_NextTokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
     end;
    else
    begin
      TK_Undo;
      do
      begin
        TK_NextTokenMustBe(TK_INT, ERR_BAD_VAR_TYPE);
        TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INVALID_IDENTIFIER);
        if (SY_FindLocal(tk_String) <> NULL) then
         begin  // Redefined
          ERR_Exit(ERR_REDEFINED_IDENTIFIER, YES,
            'Identifier: %s', tk_String);
         end;
        sym :=  SY_InsertLocal(tk_String, SY_SCRIPTVAR);
        sym.info.var.index :=  ScriptVarCount;
        ScriptVarCount++;
        TK_NextToken;
       end; while(tk_Token = TK_COMMA);
      TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
      if ScriptVarCount > 3 then
      begin
        ERR_Exit(ERR_TOO_MANY_SCRIPT_ARGS, YES, NULL);
       end;
     end;
    MS_Message(MSG_DEBUG, 'Script type: CLOSED (%d %s)\n',
      ScriptVarCount, ScriptVarCount = 1 ? 'arg' : 'args');
  end
  else if tk_Token = TK_OPEN then
  begin
    MS_Message(MSG_DEBUG, 'Script type: OPEN\n');
    scriptNumber := scriptNumber + OPEN_SCRIPTS_BASE;
    pa_OpenScriptCount++;
   end;
  else
  begin
    ERR_Exit(ERR_BAD_SCRIPT_DECL, YES, NULL);
   end;
  PC_AddScript(scriptNumber, ScriptVarCount);
  TK_NextToken;
  if (ProcessStatement(STMT_SCRIPT) = NO) then
  begin
    ERR_Exit(ERR_INVALID_STATEMENT, YES, NULL);
   end;
  PC_AppendCmd(PCD_TERMINATE);
  pa_ScriptCount++;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OuterMapVar
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OuterMapVar;
begin
  symbolNode_t *sym;

  MS_Message(MSG_DEBUG, '---- OuterMapVar ----\n');
  do
  begin
    if pa_MapVarCount = MAX_MAP_VARIABLES then
    begin
      ERR_Exit(ERR_TOO_MANY_MAP_VARS, YES, NULL);
     end;
    TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INVALID_IDENTIFIER);
    if (SY_FindGlobal(tk_String) <> NULL) then
     begin  // Redefined
      ERR_Exit(ERR_REDEFINED_IDENTIFIER, YES,
        'Identifier: %s', tk_String);
     end;
    sym :=  SY_InsertGlobal(tk_String, SY_MAPVAR);
    sym.info.var.index :=  pa_MapVarCount;
    pa_MapVarCount++;
    TK_NextToken;
   end; while(tk_Token = TK_COMMA);
  TK_TokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OuterWorldVar
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OuterWorldVar;
begin
  index: integer;
  symbolNode_t *sym;

  MS_Message(MSG_DEBUG, '---- OuterWorldVar ----\n');
  if TK_NextToken <> TK_INT then
  begin
    TK_TokenMustBe(TK_STR, ERR_BAD_VAR_TYPE);
   end;
  do
  begin
    TK_NextTokenMustBe(TK_NUMBER, ERR_MISSING_WVAR_INDEX);
    if tk_Number >= MAX_WORLD_VARIABLES then
    begin
      ERR_Exit(ERR_BAD_WVAR_INDEX, YES, NULL);
     end;
    index :=  tk_Number;
    TK_NextTokenMustBe(TK_COLON, ERR_MISSING_WVAR_COLON);
    TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INVALID_IDENTIFIER);
    if (SY_FindGlobal(tk_String) <> NULL) then
     begin  // Redefined
      ERR_Exit(ERR_REDEFINED_IDENTIFIER, YES,
        'Identifier: %s', tk_String);
     end;
    sym :=  SY_InsertGlobal(tk_String, SY_WORLDVAR);
    sym.info.var.index :=  index;
    TK_NextToken;
    pa_WorldVarCount++;
   end; while(tk_Token = TK_COMMA);
  TK_TokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OuterSpecialDef
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OuterSpecialDef;
begin
  special: integer;
  symbolNode_t *sym;

  MS_Message(MSG_DEBUG, '---- OuterSpecialDef ----\n');
  do
  begin
    TK_NextTokenMustBe(TK_NUMBER, ERR_MISSING_SPEC_VAL);
    special :=  tk_Number;
    TK_NextTokenMustBe(TK_COLON, ERR_MISSING_SPEC_COLON);
    TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INVALID_IDENTIFIER);
    if (SY_FindGlobal(tk_String) <> NULL) then
     begin  // Redefined
      ERR_Exit(ERR_REDEFINED_IDENTIFIER, YES,
        'Identifier: %s', tk_String);
     end;
    sym :=  SY_InsertGlobal(tk_String, SY_SPECIAL);
    TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
    TK_NextTokenMustBe(TK_NUMBER, ERR_MISSING_SPEC_ARGC);
    sym.info.special.value :=  special;
    sym.info.special.argCount :=  tk_Number;
    TK_NextTokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
    TK_NextToken;
   end; while(tk_Token = TK_COMMA);
  TK_TokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OuterDefine
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OuterDefine;
begin
  value: integer;
  symbolNode_t *sym;

  MS_Message(MSG_DEBUG, '---- OuterDefine ----\n');
  TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INVALID_IDENTIFIER);
  if (SY_FindGlobal(tk_String) <> NULL) then
   begin  // Redefined
    ERR_Exit(ERR_REDEFINED_IDENTIFIER, YES,
      'Identifier: %s', tk_String);
   end;
  sym :=  SY_InsertGlobal(tk_String, SY_CONSTANT);
  TK_NextToken;
  value :=  EvalConstExpression;
  MS_Message(MSG_DEBUG, 'Constant value: %d\n', value);
  sym.info.constant.value :=  value;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OuterInclude
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OuterInclude;
begin
  MS_Message(MSG_DEBUG, '---- OuterInclude ----\n');
  TK_NextTokenMustBe(TK_STRING, ERR_STRING_LIT_NOT_FOUND);
  TK_Include(tk_String);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessStatement
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean ProcessStatement(statement_t owner)
begin
  if StatementIndex = MAX_STATEMENT_DEPTH then
  begin
    ERR_Exit(ERR_STATEMENT_OVERFLOW, YES, NULL);
   end;
  StatementHistory[StatementIndex++] :=  owner;
  switch(tk_Token)
  begin
    TK_INT:
    TK_STR:
      LeadingVarDeclare;
      break;
    TK_LINESPECIAL:
      LeadingLineSpecial;
      break;
    TK_RESTART:
      LeadingRestart;
      break;
    TK_SUSPEND:
      LeadingSuspend;
      break;
    TK_TERMINATE:
      LeadingTerminate;
      break;
    TK_IDENTIFIER:
      LeadingIdentifier;
      break;
    TK_PRINT:
    TK_PRINTBOLD:
      LeadingPrint;
      break;
    TK_IF:
      LeadingIf;
      break;
    TK_FOR:
      LeadingFor;
      break;
    TK_WHILE:
    TK_UNTIL:
      LeadingWhileUntil;
      break;
    TK_DO:
      LeadingDo;
      break;
    TK_SWITCH:
      LeadingSwitch;
      break;
    TK_CASE:
      if owner <> STMT_SWITCH then
      begin
        ERR_Exit(ERR_CASE_NOT_IN_SWITCH, YES, NULL);
       end;
      LeadingCase;
      break;
    TK_DEFAULT:
      if owner <> STMT_SWITCH then
      begin
        ERR_Exit(ERR_DEFAULT_NOT_IN_SWITCH, YES, NULL);
       end;
      if DefaultInCurrent = YES then
      begin
        ERR_Exit(ERR_MULTIPLE_DEFAULT, YES, NULL);
       end;
      LeadingDefault;
      break;
    TK_BREAK:
      if BreakAncestor = NO then
      begin
        ERR_Exit(ERR_MISPLACED_BREAK, YES, NULL);
       end;
      LeadingBreak;
      break;
    TK_CONTINUE:
      if ContinueAncestor = NO then
      begin
        ERR_Exit(ERR_MISPLACED_CONTINUE, YES, NULL);
       end;
      LeadingContinue;
      break;
    TK_LBRACE:
      LeadingCompoundStatement(owner);
      break;
    TK_SEMICOLON:
      TK_NextToken;
      break;
    default:
      StatementIndex--;
      return NO;
      break;
   end;
  StatementIndex--;
  return YES;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingCompoundStatement
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingCompoundStatement(statement_t owner)
begin
  StatementLevel := StatementLevel + AdjustStmtLevel[owner];
  TK_NextToken; // Eat the TK_LBRACE
  do ; while(ProcessStatement(owner) = YES);
  TK_TokenMustBe(TK_RBRACE, ERR_INVALID_STATEMENT);
  TK_NextToken;
  StatementLevel := StatementLevel - AdjustStmtLevel[owner];
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingVarDeclare
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingVarDeclare;
begin
  symbolNode_t *sym;

  MS_Message(MSG_DEBUG, '---- LeadingVarDeclare ----\n');
  do
  begin
    if ScriptVarCount = MAX_SCRIPT_VARIABLES then
    begin
      ERR_Exit(ERR_TOO_MANY_SCRIPT_VARS, YES, NULL);
     end;
    TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INVALID_IDENTIFIER);
    if (SY_FindLocal(tk_String) <> NULL) then
     begin  // Redefined
      ERR_Exit(ERR_REDEFINED_IDENTIFIER, YES,
        'Identifier: %s', tk_String);
     end;
    sym :=  SY_InsertLocal(tk_String, SY_SCRIPTVAR);
    sym.info.var.index :=  ScriptVarCount;
    ScriptVarCount++;
    TK_NextToken;
   end; while(tk_Token = TK_COMMA);
  TK_TokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingLineSpecial
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingLineSpecial;
begin
  i: integer;
  argCount: integer;
  specialValue: integer;
  boolean direct;

  MS_Message(MSG_DEBUG, '---- LeadingLineSpecial ----\n');
  argCount :=  tk_SpecialArgCount;
  specialValue :=  tk_SpecialValue;
  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  if TK_NextToken = TK_CONST then
  begin
    TK_NextTokenMustBe(TK_COLON, ERR_MISSING_COLON);
    PC_AppendCmd(PCD_LSPEC1DIRECT+(argCount-1));
    PC_AppendLong(specialValue);
    direct :=  YES;
   end;
  else
  begin
    TK_Undo;
    direct :=  NO;
   end;
  i :=  0;
  do
  begin
    if i = argCount then
    begin
      ERR_Exit(ERR_BAD_LSPEC_ARG_COUNT, YES, NULL);
     end;
    TK_NextToken;
    if direct = YES then
    begin
      PC_AppendLong(EvalConstExpression);
     end;
    else
    begin
      EvalExpression;
     end;
    i++;
   end; while(tk_Token = TK_COMMA);
  if i <> argCount then
  begin
    ERR_Exit(ERR_BAD_LSPEC_ARG_COUNT, YES, NULL);
   end;
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  if direct = NO then
  begin
    PC_AppendCmd(PCD_LSPEC1+(argCount-1));
    PC_AppendLong(specialValue);
   end;
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingIdentifier
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingIdentifier;
begin
  symbolNode_t *sym;

  sym :=  DemandSymbol(tk_String);
  switch(sym.type)
  begin
    SY_SCRIPTVAR:
    SY_MAPVAR:
    SY_WORLDVAR:
      LeadingVarAssign(sym);
      break;
    SY_INTERNFUNC:
      LeadingInternFunc(sym);
      break;
    default:
      break;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingInternFunc
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingInternFunc(symbolNode_t *sym)
begin
  ProcessInternFunc(sym);
  if sym.info.internFunc.hasReturnValue = YES then
  begin
    PC_AppendCmd(PCD_DROP);
   end;
  TK_TokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessInternFunc
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void ProcessInternFunc(symbolNode_t *sym)
begin
  i: integer;
  argCount: integer;
  boolean direct;

  MS_Message(MSG_DEBUG, '---- ProcessInternFunc ----\n');
  argCount :=  sym.info.internFunc.argCount;
  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  if TK_NextToken = TK_CONST then
  begin
    TK_NextTokenMustBe(TK_COLON, ERR_MISSING_COLON);
    if sym.info.internFunc.directCommand = PCD_NOP then
    begin
      ERR_Exit(ERR_NO_DIRECT_VER, YES, NULL);
     end;
    PC_AppendCmd(sym.info.internFunc.directCommand);
    direct :=  YES;
    TK_NextToken;
   end;
  else
  begin
    direct :=  NO;
   end;
  i :=  0;
  if argCount > 0 then
  begin
    TK_Undo; // Adjust for first expression
    do
    begin
      if i = argCount then
      begin
        ERR_Exit(ERR_BAD_ARG_COUNT, YES, NULL);
       end;
      TK_NextToken;
      if direct = YES then
      begin
        PC_AppendLong(EvalConstExpression);
       end;
      else
      begin
        EvalExpression;
       end;
      i++;
     end; while(tk_Token = TK_COMMA);
   end;
  if i <> argCount then
  begin
    ERR_Exit(ERR_BAD_ARG_COUNT, YES, NULL);
   end;
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
  if direct = NO then
  begin
    PC_AppendCmd(sym.info.internFunc.stackCommand);
   end;
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingPrint
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingPrint;
begin
  pcd_t printCmd;
  tokenType_t stmtToken;

  MS_Message(MSG_DEBUG, '---- LeadingPrint ----\n');
  stmtToken :=  tk_Token; // Will be TK_PRINT or TK_PRINTBOLD
  PC_AppendCmd(PCD_BEGINPRINT);
  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  do
  begin
    switch(TK_NextCharacter)
    begin
      's': // string
        printCmd :=  PCD_PRINTSTRING;
        break;
      'i': // integer
      'd': // decimal
        printCmd :=  PCD_PRINTNUMBER;
        break;
      'c': // character
        printCmd :=  PCD_PRINTCHARACTER;
        break;
      default:
        ERR_Exit(ERR_UNKNOWN_PRTYPE, YES, NULL);
        break;
     end;
    TK_NextTokenMustBe(TK_COLON, ERR_MISSING_COLON);
    TK_NextToken;
    EvalExpression;
    PC_AppendCmd(printCmd);
   end; while(tk_Token = TK_COMMA);
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
  if stmtToken = TK_PRINT then
  begin
    PC_AppendCmd(PCD_ENDPRINT);
   end;
  else
  begin
    PC_AppendCmd(PCD_ENDPRINTBOLD);
   end;
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingIf
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingIf;
begin
  jumpAddrPtr1: integer;
  jumpAddrPtr2: integer;

  MS_Message(MSG_DEBUG, '---- LeadingIf ----\n');
  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  TK_NextToken;
  EvalExpression;
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
  PC_AppendCmd(PCD_IFNOTGOTO);
  jumpAddrPtr1 :=  pc_Address;
  PC_SkipLong;
  TK_NextToken;
  if (ProcessStatement(STMT_IF) = NO) then
  begin
    ERR_Exit(ERR_INVALID_STATEMENT, YES, NULL);
   end;
  if tk_Token = TK_ELSE then
  begin
    PC_AppendCmd(PCD_GOTO);
    jumpAddrPtr2 :=  pc_Address;
    PC_SkipLong;
    PC_WriteLong(pc_Address, jumpAddrPtr1);
    TK_NextToken;
    if (ProcessStatement(STMT_ELSE) = NO) then
    begin
      ERR_Exit(ERR_INVALID_STATEMENT, YES, NULL);
     end;
    PC_WriteLong(pc_Address, jumpAddrPtr2);
   end;
  else
  begin
    PC_WriteLong(pc_Address, jumpAddrPtr1);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingFor
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingFor;
begin
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingWhileUntil
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingWhileUntil;
begin
  tokenType_t stmtToken;
  topAddr: integer;
  outAddrPtr: integer;

  MS_Message(MSG_DEBUG, '---- LeadingWhileUntil ----\n');
  stmtToken :=  tk_Token;
  topAddr :=  pc_Address;
  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  TK_NextToken;
  EvalExpression;
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
  PC_AppendCmd(stmtToken = TK_WHILE ? PCD_IFNOTGOTO : PCD_IFGOTO);
  outAddrPtr :=  pc_Address;
  PC_SkipLong;
  TK_NextToken;
  if (ProcessStatement(STMT_WHILEUNTIL) = NO) then
  begin
    ERR_Exit(ERR_INVALID_STATEMENT, YES, NULL);
   end;
  PC_AppendCmd(PCD_GOTO);
  PC_AppendLong(topAddr);

  PC_WriteLong(pc_Address, outAddrPtr);

  WriteContinues(topAddr);
  WriteBreaks;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingDo
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingDo;
begin
  topAddr: integer;
  exprAddr: integer;
  tokenType_t stmtToken;

  MS_Message(MSG_DEBUG, '---- LeadingDo ----\n');
  topAddr :=  pc_Address;
  TK_NextToken;
  if (ProcessStatement(STMT_DO) = NO) then
  begin
    ERR_Exit(ERR_INVALID_STATEMENT, YES, NULL);
   end;
  if (tk_Token <> TK_WHILE) and (tk_Token <> TK_UNTIL) then
  begin
    ERR_Exit(ERR_BAD_DO_STATEMENT, YES, NULL);
   end;
  stmtToken :=  tk_Token;
  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  exprAddr :=  pc_Address;
  TK_NextToken;
  EvalExpression;
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  PC_AppendCmd(stmtToken = TK_WHILE ? PCD_IFGOTO : PCD_IFNOTGOTO);
  PC_AppendLong(topAddr);
  WriteContinues(exprAddr);
  WriteBreaks;
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingSwitch
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingSwitch;
begin
  switcherAddrPtr: integer;
  outAddrPtr: integer;
  caseInfo_t *cInfo;
  defaultAddress: integer;

  MS_Message(MSG_DEBUG, '---- LeadingSwitch ----\n');

  TK_NextTokenMustBe(TK_LPAREN, ERR_MISSING_LPAREN);
  TK_NextToken;
  EvalExpression;
  TK_TokenMustBe(TK_RPAREN, ERR_MISSING_RPAREN);

  PC_AppendCmd(PCD_GOTO);
  switcherAddrPtr :=  pc_Address;
  PC_SkipLong;

  TK_NextToken;
  if (ProcessStatement(STMT_SWITCH) = NO) then
  begin
    ERR_Exit(ERR_INVALID_STATEMENT, YES, NULL);
   end;

  PC_AppendCmd(PCD_GOTO);
  outAddrPtr :=  pc_Address;
  PC_SkipLong;

  PC_WriteLong(pc_Address, switcherAddrPtr);
  defaultAddress :=  0;
  while ((cInfo :=  GetCaseInfo) <> NULL) do
  begin
    if cInfo.isDefault = YES then
    begin
      defaultAddress :=  cInfo.address;
      continue;
     end;
    PC_AppendCmd(PCD_CASEGOTO);
    PC_AppendLong(cInfo.value);
    PC_AppendLong(cInfo.address);
   end;
  PC_AppendCmd(PCD_DROP);

  if defaultAddress <> 0 then
  begin
    PC_AppendCmd(PCD_GOTO);
    PC_AppendLong(defaultAddress);
   end;

  PC_WriteLong(pc_Address, outAddrPtr);

  WriteBreaks;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingCase
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingCase;
begin
  MS_Message(MSG_DEBUG, '---- LeadingCase ----\n');
  TK_NextToken;
  PushCase(EvalConstExpression, NO);
  TK_TokenMustBe(TK_COLON, ERR_MISSING_COLON);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingDefault
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingDefault;
begin
  MS_Message(MSG_DEBUG, '---- LeadingDefault ----\n');
  TK_NextTokenMustBe(TK_COLON, ERR_MISSING_COLON);
  PushCase(0, YES);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PushCase
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void PushCase(int value, boolean isDefault)
begin
  if CaseIndex = MAX_CASE then
  begin
    ERR_Exit(ERR_CASE_OVERFLOW, YES, NULL);
   end;
  CaseInfo[CaseIndex].level :=  StatementLevel;
  CaseInfo[CaseIndex].value :=  value;
  CaseInfo[CaseIndex].isDefault :=  isDefault;
  CaseInfo[CaseIndex].address :=  pc_Address;
  CaseIndex++;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// GetCaseInfo
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static caseInfo_t *GetCaseInfo;
begin
  if CaseIndex = 0 then
  begin
    return NULL;
   end;
  if CaseInfo[CaseIndex-1].level > StatementLevel then
  begin
    return) and (CaseInfo[--CaseIndex];
   end;
  return NULL;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// DefaultInCurrent
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean DefaultInCurrent;
begin
  i: integer;

  for(i :=  0; i < CaseIndex; i++)
  begin
    if(CaseInfo[i].isDefault = YES
     ) and (CaseInfo[i].level = StatementLevel)
     begin
      return YES;
     end;
   end;
  return NO;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingBreak
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingBreak;
begin
  MS_Message(MSG_DEBUG, '---- LeadingBreak ----\n');
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  PC_AppendCmd(PCD_GOTO);
  PushBreak;
  PC_SkipLong;
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PushBreak
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void PushBreak;
begin
  if BreakIndex = MAX_CASE then
  begin
    ERR_Exit(ERR_BREAK_OVERFLOW, YES, NULL);
   end;
  BreakInfo[BreakIndex].level :=  StatementLevel;
  BreakInfo[BreakIndex].addressPtr :=  pc_Address;
  BreakIndex++;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// WriteBreaks
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void WriteBreaks;
begin
  if BreakIndex = 0 then
  begin
    exit;
   end;
  while BreakInfo[BreakIndex-1].level > StatementLevel do
  begin
    PC_WriteLong(pc_Address, BreakInfo[--BreakIndex].addressPtr);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// BreakAncestor
//
// Returns YES if the current statement history contains a break root
// statement.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean BreakAncestor;
begin
  i: integer;

  for(i :=  0; i < StatementIndex; i++)
  begin
    if IsBreakRoot[StatementHistory[i]] then
    begin
      return YES;
     end;
   end;
  return NO;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingContinue
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingContinue;
begin
  MS_Message(MSG_DEBUG, '---- LeadingContinue ----\n');
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  PC_AppendCmd(PCD_GOTO);
  PushContinue;
  PC_SkipLong;
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PushContinue
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void PushContinue;
begin
  if ContinueIndex = MAX_CONTINUE then
  begin
    ERR_Exit(ERR_CONTINUE_OVERFLOW, YES, NULL);
   end;
  ContinueInfo[ContinueIndex].level :=  StatementLevel;
  ContinueInfo[ContinueIndex].addressPtr :=  pc_Address;
  ContinueIndex++;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// WriteContinues
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void WriteContinues(int address)
begin
  if ContinueIndex = 0 then
  begin
    exit;
   end;
  while ContinueInfo[ContinueIndex-1].level > StatementLevel do
  begin
    PC_WriteLong(address, ContinueInfo[--ContinueIndex].addressPtr);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ContinueAncestor
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean ContinueAncestor;
begin
  i: integer;

  for(i :=  0; i < StatementIndex; i++)
  begin
    if IsContinueRoot[StatementHistory[i]] then
    begin
      return YES;
     end;
   end;
  return NO;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingVarAssign
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingVarAssign(symbolNode_t *sym)
begin
  boolean done;
  tokenType_t assignToken;

  MS_Message(MSG_DEBUG, '---- LeadingVarAssign ----\n');
  done :=  NO;
  do
  begin
    TK_NextToken; // Fetch assignment operator
    if (tk_Token = TK_INC) or (tk_Token = TK_DEC) then
     begin  // Postfix increment or decrement
      PC_AppendCmd(GetIncDecPCD(tk_Token, sym.type));
      PC_AppendLong(sym.info.var.index);
      TK_NextToken;
     end;
    else
     begin  // Normal operator
      if (TK_Member(AssignOps) = NO) then
      begin
        ERR_Exit(ERR_MISSING_ASSIGN_OP, YES, NULL);
       end;
      assignToken :=  tk_Token;
      TK_NextToken;
      EvalExpression;
      PC_AppendCmd(GetAssignPCD(assignToken, sym.type));
      PC_AppendLong(sym.info.var.index);
     end;
    if tk_Token = TK_COMMA then
    begin
      TK_NextTokenMustBe(TK_IDENTIFIER, ERR_BAD_ASSIGNMENT);
      sym :=  DemandSymbol(tk_String);
      if(sym.type <> SY_SCRIPTVAR) and (sym.type <> SY_MAPVAR
       ) and (sym.type <> SY_WORLDVAR)
       begin
        ERR_Exit(ERR_BAD_ASSIGNMENT, YES, NULL);
       end;
     end;
    else
    begin
      TK_TokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
      TK_NextToken;
      done :=  YES;
     end;
   end; while(done = NO);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// GetAssignPCD
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static pcd_t GetAssignPCD(tokenType_t token, symbolType_t symbol)
begin
  i: integer;
  static struct
  begin
    tokenType_t token;
    symbolType_t symbol;
    pcd_t pcd;
   end;  assignmentLookup[] := 
   begin
    TK_ASSIGN, SY_SCRIPTVAR, PCD_ASSIGNSCRIPTVAR,
    TK_ASSIGN, SY_MAPVAR, PCD_ASSIGNMAPVAR,
    TK_ASSIGN, SY_WORLDVAR, PCD_ASSIGNWORLDVAR,
    TK_ADDASSIGN, SY_SCRIPTVAR, PCD_ADDSCRIPTVAR,
    TK_ADDASSIGN, SY_MAPVAR, PCD_ADDMAPVAR,
    TK_ADDASSIGN, SY_WORLDVAR, PCD_ADDWORLDVAR,
    TK_SUBASSIGN, SY_SCRIPTVAR, PCD_SUBSCRIPTVAR,
    TK_SUBASSIGN, SY_MAPVAR, PCD_SUBMAPVAR,
    TK_SUBASSIGN, SY_WORLDVAR, PCD_SUBWORLDVAR,
    TK_MULASSIGN, SY_SCRIPTVAR, PCD_MULSCRIPTVAR,
    TK_MULASSIGN, SY_MAPVAR, PCD_MULMAPVAR,
    TK_MULASSIGN, SY_WORLDVAR, PCD_MULWORLDVAR,
    TK_DIVASSIGN, SY_SCRIPTVAR, PCD_DIVSCRIPTVAR,
    TK_DIVASSIGN, SY_MAPVAR, PCD_DIVMAPVAR,
    TK_DIVASSIGN, SY_WORLDVAR, PCD_DIVWORLDVAR,
    TK_MODASSIGN, SY_SCRIPTVAR, PCD_MODSCRIPTVAR,
    TK_MODASSIGN, SY_MAPVAR, PCD_MODMAPVAR,
    TK_MODASSIGN, SY_WORLDVAR, PCD_MODWORLDVAR,
    TK_NONE
   end;

  for(i :=  0; assignmentLookup[i].token <> TK_NONE; i++)
  begin
    if(assignmentLookup[i].token = token
     ) and (assignmentLookup[i].symbol = symbol)
     begin
      return assignmentLookup[i].pcd;
     end;
   end;
  return PCD_NOP;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingSuspend
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingSuspend;
begin
  MS_Message(MSG_DEBUG, '---- LeadingSuspend ----\n');
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  PC_AppendCmd(PCD_SUSPEND);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingTerminate
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingTerminate;
begin
  MS_Message(MSG_DEBUG, '---- LeadingTerminate ----\n');
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  PC_AppendCmd(PCD_TERMINATE);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// LeadingRestart
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void LeadingRestart;
begin
  MS_Message(MSG_DEBUG, '---- LeadingRestart ----\n');
  TK_NextTokenMustBe(TK_SEMICOLON, ERR_MISSING_SEMICOLON);
  PC_AppendCmd(PCD_RESTART);
  TK_NextToken;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// EvalConstExpression
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static int EvalConstExpression;
begin
  ExprStackIndex :=  0;
  ConstantExpression :=  YES;
  ExprLevA;
  if ExprStackIndex <> 1 then
  begin
    ERR_Exit(ERR_BAD_CONST_EXPR, YES, NULL);
   end;
  return PopExStk;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// EvalExpression
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void EvalExpression;
begin
  ConstantExpression :=  NO;
  ExprLevA;
  end;

// Operator:) or (
static void ExprLevA;
begin
  ExprLevB;
  while tk_Token = TK_ORLOGICAL do
  begin
    TK_NextToken;
    ExprLevB;
    SendExprCommand(PCD_ORLOGICAL);
   end;
  end;

// Operator:) and (
static void ExprLevB;
begin
  ExprLevC;
  while tk_Token = TK_ANDLOGICAL do
  begin
    TK_NextToken;
    ExprLevC;
    SendExprCommand(PCD_ANDLOGICAL);
   end;
  end;

// Operator:) or (
static void ExprLevC;
begin
  ExprLevD;
  while tk_Token = TK_ORBITWISE do
  begin
    TK_NextToken;
    ExprLevD;
    SendExprCommand(PCD_ORBITWISE);
   end;
  end;

// Operator:) xor (
static void ExprLevD;
begin
  ExprLevE;
  while tk_Token = TK_EORBITWISE do
  begin
    TK_NextToken;
    ExprLevE;
    SendExprCommand(PCD_EORBITWISE);
   end;
  end;

// Operator:) and (
static void ExprLevE;
begin
  ExprLevF;
  while tk_Token = TK_ANDBITWISE do
  begin
    TK_NextToken;
    ExprLevF;
    SendExprCommand(PCD_ANDBITWISE);
   end;
  end;

// Operators: = <> 
static void ExprLevF;
begin
  tokenType_t token;

  ExprLevG;
  while (TK_Member(LevFOps)) do
  begin
    token :=  tk_Token;
    TK_NextToken;
    ExprLevG;
    SendExprCommand(TokenToPCD(token));
   end;
  end;

// Operators: < <= > >= 
static void ExprLevG;
begin
  tokenType_t token;

  ExprLevH;
  while (TK_Member(LevGOps)) do
  begin
    token :=  tk_Token;
    TK_NextToken;
    ExprLevH;
    SendExprCommand(TokenToPCD(token));
   end;
  end;

// Operators:  shl   shr 
static void ExprLevH;
begin
  tokenType_t token;

  ExprLevI;
  while (TK_Member(LevHOps)) do
  begin
    token :=  tk_Token;
    TK_NextToken;
    ExprLevI;
    SendExprCommand(TokenToPCD(token));
   end;
  end;

// Operators: + -
static void ExprLevI;
begin
  tokenType_t token;

  ExprLevJ;
  while (TK_Member(LevIOps)) do
  begin
    token :=  tk_Token;
    TK_NextToken;
    ExprLevJ;
    SendExprCommand(TokenToPCD(token));
   end;
  end;

// Operators: * /  mod 
static void ExprLevJ;
begin
  tokenType_t token;
  boolean unaryMinus;

  unaryMinus :=  FALSE;
  if tk_Token = TK_MINUS then
  begin
    unaryMinus :=  TRUE;
    TK_NextToken;
   end;
  if ConstantExpression = YES then
  begin
    ConstExprFactor;
   end;
  else
  begin
    ExprFactor;
   end;
  if unaryMinus = TRUE then
  begin
    SendExprCommand(PCD_UNARYMINUS);
   end;
  while (TK_Member(LevJOps)) do
  begin
    token :=  tk_Token;
    TK_NextToken;
    if ConstantExpression = YES then
    begin
      ConstExprFactor;
     end;
    else
    begin
      ExprFactor;
     end;
    SendExprCommand(TokenToPCD(token));
   end;
  end;

static void ExprFactor;
begin
  symbolNode_t *sym;
  tokenType_t opToken;

  switch(tk_Token)
  begin
    TK_STRING:
      PC_AppendCmd(PCD_PUSHNUMBER);
      PC_AppendLong(STR_Find(tk_String));
      TK_NextToken;
      break;
    TK_NUMBER:
      PC_AppendCmd(PCD_PUSHNUMBER);
      PC_AppendLong(tk_Number);
      TK_NextToken;
      break;
    TK_LPAREN:
      TK_NextToken;
      ExprLevA;
      if tk_Token <> TK_RPAREN then
      begin
        ERR_Exit(ERR_BAD_EXPR, YES, NULL);
       end;
      TK_NextToken;
      break;
    TK_NOT:
      TK_NextToken;
      ExprFactor;
      PC_AppendCmd(PCD_NEGATELOGICAL);
      break;
    TK_INC:
    TK_DEC:
      opToken :=  tk_Token;
      TK_NextTokenMustBe(TK_IDENTIFIER, ERR_INCDEC_OP_ON_NON_VAR);
      sym :=  DemandSymbol(tk_String);
      if(sym.type <> SY_SCRIPTVAR) and (sym.type <> SY_MAPVAR
       ) and (sym.type <> SY_WORLDVAR)
       begin
        ERR_Exit(ERR_INCDEC_OP_ON_NON_VAR, YES, NULL);
       end;
      PC_AppendCmd(GetIncDecPCD(opToken, sym.type));
      PC_AppendLong(sym.info.var.index);
      PC_AppendCmd(GetPushVarPCD(sym.type));
      PC_AppendLong(sym.info.var.index);
      TK_NextToken;
      break;
    TK_IDENTIFIER:
      sym :=  DemandSymbol(tk_String);
      switch(sym.type)
      begin
        SY_SCRIPTVAR:
        SY_MAPVAR:
        SY_WORLDVAR:
          PC_AppendCmd(GetPushVarPCD(sym.type));
          PC_AppendLong(sym.info.var.index);
          TK_NextToken;
          if (tk_Token = TK_INC) or (tk_Token = TK_DEC) then
          begin
            PC_AppendCmd(GetIncDecPCD(tk_Token, sym.type));
            PC_AppendLong(sym.info.var.index);
            TK_NextToken;
           end;
          break;
        SY_INTERNFUNC:
          if sym.info.internFunc.hasReturnValue = NO then
          begin
            ERR_Exit(ERR_EXPR_FUNC_NO_RET_VAL, YES, NULL);
           end;
          ProcessInternFunc(sym);
          break;
        default:
          ERR_Exit(ERR_ILLEGAL_EXPR_IDENT, YES,
            'Identifier: %s', tk_String);
          break;
       end;
      break;
    default:
      ERR_Exit(ERR_BAD_EXPR, YES, NULL);
      break;
   end;
  end;

static void ConstExprFactor;
begin
  switch(tk_Token)
  begin
    TK_STRING:
      PushExStk(STR_Find(tk_String));
      TK_NextToken;
      break;
    TK_NUMBER:
      PushExStk(tk_Number);
      TK_NextToken;
      break;
    TK_LPAREN:
      TK_NextToken;
      ExprLevA;
      if tk_Token <> TK_RPAREN then
      begin
        ERR_Exit(ERR_BAD_CONST_EXPR, YES, NULL);
       end;
      TK_NextToken;
      break;
    TK_NOT:
      TK_NextToken;
      ConstExprFactor;
      SendExprCommand(PCD_NEGATELOGICAL);
      break;
    default:
      ERR_Exit(ERR_BAD_CONST_EXPR, YES, NULL);
      break;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SendExprCommand
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void SendExprCommand(pcd_t pcd)
begin
  operand2: integer;

  if ConstantExpression = NO then
  begin
    PC_AppendCmd(pcd);
    exit;
   end;
  switch(pcd)
  begin
    PCD_ADD:
      PushExStk(PopExStk+PopExStk);
      break;
    PCD_SUBTRACT:
      operand2 :=  PopExStk;
      PushExStk(PopExStk-operand2);
      break;
    PCD_MULTIPLY:
      PushExStk(PopExStk*PopExStk);
      break;
    PCD_DIVIDE:
      operand2 :=  PopExStk;
      PushExStk(PopExStk/operand2);
      break;
    PCD_MODULUS:
      operand2 :=  PopExStk;
      PushExStk(PopExStk mod operand2);
      break;
    PCD_EQ:
      PushExStk(PopExStk = PopExStk);
      break;
    PCD_NE:
      PushExStk(PopExStk <> PopExStk);
      break;
    PCD_LT:
      PushExStk(PopExStk >= PopExStk);
      break;
    PCD_GT:
      PushExStk(PopExStk <= PopExStk);
      break;
    PCD_LE:
      PushExStk(PopExStk > PopExStk);
      break;
    PCD_GE:
      PushExStk(PopExStk < PopExStk);
      break;
    PCD_ANDLOGICAL:
      PushExStk(PopExStk) and (PopExStk);
      break;
    PCD_ORLOGICAL:
      PushExStk(PopExStk) or (PopExStk);
      break;
    PCD_ANDBITWISE:
      PushExStk(PopExStk) and (PopExStk);
      break;
    PCD_ORBITWISE:
      PushExStk(PopExStk) or (PopExStk);
      break;
    PCD_EORBITWISE:
      PushExStk(PopExStk) xor (PopExStk);
      break;
    PCD_NEGATELOGICAL:
      PushExStk(not PopExStk);
      break;
    PCD_LSHIFT:
      operand2 :=  PopExStk;
      PushExStk(PopExStk shr operand2);
      break;
    PCD_RSHIFT:
      operand2 :=  PopExStk;
      PushExStk(PopExStk shl operand2);
      break;
    PCD_UNARYMINUS:
      PushExStk(-PopExStk);
      break;
    default:
      ERR_Exit(ERR_UNKNOWN_CONST_EXPR_PCD, YES, NULL);
      break;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PushExStk
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void PushExStk(int value)
begin
  if ExprStackIndex = EXPR_STACK_DEPTH then
  begin
    ERR_Exit(ERR_EXPR_STACK_OVERFLOW, YES, NULL);
   end;
  ExprStack[ExprStackIndex++] :=  value;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PopExStk
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static int PopExStk;
begin
  if ExprStackIndex < 1 then
  begin
    ERR_Exit(ERR_EXPR_STACK_EMPTY, YES, NULL);
   end;
  return ExprStack[--ExprStackIndex];
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TokenToPCD
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static pcd_t TokenToPCD(tokenType_t token)
begin
  i: integer;
  static struct
  begin
    tokenType_t token;
    pcd_t pcd;
   end;  operatorLookup[] := 
   begin
    TK_EQ, PCD_EQ,
    TK_NE, PCD_NE,
    TK_LT, PCD_LT,
    TK_LE, PCD_LE,
    TK_GT, PCD_GT,
    TK_GE, PCD_GE,
    TK_LSHIFT, PCD_LSHIFT,
    TK_RSHIFT, PCD_RSHIFT,
    TK_PLUS, PCD_ADD,
    TK_MINUS, PCD_SUBTRACT,
    TK_ASTERISK, PCD_MULTIPLY,
    TK_SLASH, PCD_DIVIDE,
    TK_PERCENT, PCD_MODULUS,
    TK_NONE
   end;

  for(i :=  0; operatorLookup[i].token <> TK_NONE; i++)
  begin
    if operatorLookup[i].token = token then
    begin
      return operatorLookup[i].pcd;
     end;
   end;
  return PCD_NOP;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// GetPushVarPCD
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static pcd_t GetPushVarPCD(symbolType_t symType)
begin
  switch(symType)
  begin
    SY_SCRIPTVAR:
      return PCD_PUSHSCRIPTVAR;
    SY_MAPVAR:
      return PCD_PUSHMAPVAR;
    SY_WORLDVAR:
      return PCD_PUSHWORLDVAR;
    default:
      break;
   end;
  return PCD_NOP;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// GetIncDecPCD
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static pcd_t GetIncDecPCD(tokenType_t token, symbolType_t symbol)
begin
  i: integer;
  static struct
  begin
    tokenType_t token;
    symbolType_t symbol;
    pcd_t pcd;
   end;  incDecLookup[] := 
   begin
    TK_INC, SY_SCRIPTVAR, PCD_INCSCRIPTVAR,
    TK_INC, SY_MAPVAR, PCD_INCMAPVAR,
    TK_INC, SY_WORLDVAR, PCD_INCWORLDVAR,
    TK_DEC, SY_SCRIPTVAR, PCD_DECSCRIPTVAR,
    TK_DEC, SY_MAPVAR, PCD_DECMAPVAR,
    TK_DEC, SY_WORLDVAR, PCD_DECWORLDVAR,
    TK_NONE
   end;

  for(i :=  0; incDecLookup[i].token <> TK_NONE; i++)
  begin
    if(incDecLookup[i].token = token
     ) and (incDecLookup[i].symbol = symbol)
     begin
      return incDecLookup[i].pcd;
     end;
   end;
  return PCD_NOP;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// DemandSymbol
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static symbolNode_t *DemandSymbol(char *name)
begin
  symbolNode_t *sym;

  if ((sym :=  SY_Find(name)) = NULL) then
  begin
    ERR_Exit(ERR_UNKNOWN_IDENTIFIER, YES,
      'Identifier: %s', name);
   end;
  return sym;
  end;
