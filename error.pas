
/(**************************************************************************
/(**
/(** error.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include 'common.h'
#include 'error.h'
#include 'token.h'
#include 'misc.h'

const
  ERR_NONE = 0;
  ERR_NO_SYMBOL_MEM = 10;
  ERR_IDENTIFIER_TOO_LONG = 11;
  ERR_STRING_TOO_LONG = 12;
  ERR_FILE_NAME_TOO_LONG = 13;
  ERR_MISSING_LPAREN = 14;
  ERR_MISSING_RPAREN = 15;
  ERR_MISSING_SEMICOLON = 16;
  ERR_MISSING_SCRIPT_NUMBER = 17;
  ERR_ALLOC_PCODE_BUFFER = 18;
  ERR_PCODE_BUFFER_OVERFLOW = 19;
  ERR_TOO_MANY_SCRIPTS = 20;
  ERR_SAVE_OBJECT_FAILED = 21;
  ERR_MISSING_LPAREN_SCR = 22;
  ERR_INVALID_IDENTIFIER = 23;
  ERR_REDEFINED_IDENTIFIER = 24;
  ERR_MISSING_COMMA = 25;
  ERR_BAD_VAR_TYPE = 26;
  ERR_TOO_MANY_SCRIPT_ARGS = 27;
  ERR_MISSING_LBRACE_SCR = 28;
  ERR_MISSING_RBRACE_SCR = 29;
  ERR_TOO_MANY_MAP_VARS = 30;
  ERR_MISSING_WVAR_INDEX = 31;
  ERR_BAD_WVAR_INDEX = 32;
  ERR_MISSING_WVAR_COLON = 33;
  ERR_MISSING_SPEC_VAL = 34;
  ERR_MISSING_SPEC_COLON = 35;
  ERR_MISSING_SPEC_ARGC = 36;
  ERR_CANT_READ_FILE = 37;
  ERR_CANT_OPEN_FILE = 38;
  ERR_CANT_OPEN_DBGFILE = 39;
  ERR_INVALID_DIRECTIVE = 40;
  ERR_BAD_DEFINE = 41;
  ERR_INCL_NESTING_TOO_DEEP = 42;
  ERR_STRING_LIT_NOT_FOUND = 43;
  ERR_TOO_MANY_SCRIPT_VARS = 44;
  ERR_INVALID_DECLARATOR = 45;
  ERR_BAD_LSPEC_ARG_COUNT = 46;
  ERR_BAD_ARG_COUNT = 47;
  ERR_UNKNOWN_IDENTIFIER = 48;
  ERR_MISSING_COLON = 49;
  ERR_BAD_EXPR = 50;
  ERR_BAD_CONST_EXPR = 51;
  ERR_NO_DIRECT_VER = 52;
  ERR_ILLEGAL_EXPR_IDENT = 53;
  ERR_EXPR_FUNC_NO_RET_VAL = 54;
  ERR_MISSING_ASSIGN_OP = 55;
  ERR_INCDEC_OP_ON_NON_VAR = 56;
  ERR_MISSING_RBRACE = 57;
  ERR_INVALID_STATEMENT = 58;
  ERR_BAD_DO_STATEMENT = 59;
  ERR_BAD_SCRIPT_DECL = 60;
  ERR_CASE_OVERFLOW = 61;
  ERR_BREAK_OVERFLOW = 62;
  ERR_CONTINUE_OVERFLOW = 63;
  ERR_STATEMENT_OVERFLOW = 64;
  ERR_MISPLACED_BREAK = 65;
  ERR_MISPLACED_CONTINUE = 66;
  ERR_CASE_NOT_IN_SWITCH = 67;
  ERR_DEFAULT_NOT_IN_SWITCH = 68;
  ERR_MULTIPLE_DEFAULT = 69;
  ERR_EXPR_STACK_OVERFLOW = 70;
  ERR_EXPR_STACK_EMPTY = 71;
  ERR_UNKNOWN_CONST_EXPR_PCD = 72;
  ERR_BAD_RADIX_CONSTANT = 73;
  ERR_BAD_ASSIGNMENT = 74;
  ERR_OUT_OF_MEMORY = 75;
  ERR_TOO_MANY_STRINGS = 76;
  ERR_UNKNOWN_PRTYPE = 77;
  ERR_BAD_CHARACTER = 78;

// MACROS ------------------------------------------------------------------

#define ERROR_FILE_NAME 'acs.err'

// TYPES -------------------------------------------------------------------

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

static char *ErrorFileName;
static char *ErrorText(error_t error);

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

extern char acs_SourceFileName[MAX_FILE_NAME_LENGTH];

// PUBLIC DATA DEFINITIONS -------------------------------------------------

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static struct
begin
  error_t number;
  char *name;
  end; ErrorNames[] :=
  begin
  ERR_MISSING_SEMICOLON,
  'Missing semicolon.',
  ERR_MISSING_LPAREN,
  'Missing '('.',
  ERR_MISSING_RPAREN,
  'Missing ')'.',
  ERR_MISSING_SCRIPT_NUMBER,
  'Missing script number.',
  ERR_IDENTIFIER_TOO_LONG,
  'Identifier too long.',
  ERR_STRING_TOO_LONG,
  'String too long.',
  ERR_FILE_NAME_TOO_LONG,
  'File name too long.',
  ERR_BAD_CHARACTER,
  'Bad character in script text.',
  ERR_ALLOC_PCODE_BUFFER,
  'Failed to allocate PCODE buffer.',
  ERR_PCODE_BUFFER_OVERFLOW,
  'PCODE buffer overflow.',
  ERR_TOO_MANY_SCRIPTS,
  'Too many scripts.',
  ERR_SAVE_OBJECT_FAILED,
  'Couldn't save object file.',
  ERR_MISSING_LPAREN_SCR,
  'Missing '(' in script definition.',
  ERR_INVALID_IDENTIFIER,
  'Invalid identifier.',
  ERR_REDEFINED_IDENTIFIER,
  'Redefined identifier.',
  ERR_MISSING_COMMA,
  'Missing comma.',
  ERR_BAD_VAR_TYPE,
  'Invalid variable type.',
  ERR_TOO_MANY_SCRIPT_ARGS,
  'Too many script arguments.',
  ERR_MISSING_LBRACE_SCR,
  'Missing opening ' begin ' in script definition.',
  ERR_MISSING_RBRACE_SCR,
  'Missing closing ' end;' in script definition.',
  ERR_TOO_MANY_MAP_VARS,
  'Too many map variables.',
  ERR_TOO_MANY_SCRIPT_VARS,
  'Too many script variables.',
  ERR_MISSING_WVAR_INDEX,
  'Missing index in world variable declaration.',
  ERR_BAD_WVAR_INDEX,
  'World variable index out of range.',
  ERR_MISSING_WVAR_COLON,
  'Missing colon in world variable declaration.',
  ERR_MISSING_SPEC_VAL,
  'Missing value in special declaration.',
  ERR_MISSING_SPEC_COLON,
  'Missing colon in special declaration.',
  ERR_MISSING_SPEC_ARGC,
  'Missing argument count in special declaration.',
  ERR_CANT_READ_FILE,
  'Couldn't read file.',
  ERR_CANT_OPEN_FILE,
  'Couldn't open file.',
  ERR_CANT_OPEN_DBGFILE,
  'Couldn't open debug file.',
  ERR_INVALID_DIRECTIVE,
  'Invalid directive.',
  ERR_BAD_DEFINE,
  'Non-numeric constant found in #define.',
  ERR_INCL_NESTING_TOO_DEEP,
  'Include nesting too deep.',
  ERR_STRING_LIT_NOT_FOUND,
  'String literal not found.',
  ERR_INVALID_DECLARATOR,
  'Invalid declarator.',
  ERR_BAD_LSPEC_ARG_COUNT,
  'Incorrect number of special arguments.',
  ERR_BAD_ARG_COUNT,
  'Incorrect number of arguments.',
  ERR_UNKNOWN_IDENTIFIER,
  'Identifier has not been declared.',
  ERR_MISSING_COLON,
  'Missing colon.',
  ERR_BAD_EXPR,
  'Syntax error in expression.',
  ERR_BAD_CONST_EXPR,
  'Syntax error in constant expression.',
  ERR_NO_DIRECT_VER,
  'Internal function has no direct version.',
  ERR_ILLEGAL_EXPR_IDENT,
  'Illegal identifier in expression.',
  ERR_EXPR_FUNC_NO_RET_VAL,
  'Function call in expression has no return value.',
  ERR_MISSING_ASSIGN_OP,
  'Missing assignment operator.',
  ERR_INCDEC_OP_ON_NON_VAR,
  ''++' or '--' used on a non-variable.',
  ERR_MISSING_RBRACE,
  'Missing ' end;' at end of compound statement.',
  ERR_INVALID_STATEMENT,
  'Invalid statement.',
  ERR_BAD_DO_STATEMENT,
  'Do statement not followed by 'while' or 'until'.',
  ERR_BAD_SCRIPT_DECL,
  'Bad script declaration.',
  ERR_CASE_OVERFLOW,
  'Internal Error: stack overflow.',
  ERR_BREAK_OVERFLOW,
  'Internal Error: Break stack overflow.',
  ERR_CONTINUE_OVERFLOW,
  'Internal Error: Continue stack overflow.',
  ERR_STATEMENT_OVERFLOW,
  'Internal Error: Statement overflow.',
  ERR_MISPLACED_BREAK,
  'Misplaced BREAK statement.',
  ERR_MISPLACED_CONTINUE,
  'Misplaced CONTINUE statement.',
  ERR_CASE_NOT_IN_SWITCH,
  'CASE must appear in case statement.',
  ERR_DEFAULT_NOT_IN_SWITCH,
  'DEFAULT must appear in case statement.',
  ERR_MULTIPLE_DEFAULT,
  'Only 1 DEFAULT per case allowed.',
  ERR_EXPR_STACK_OVERFLOW,
  'Expression stack overflow.',
  ERR_EXPR_STACK_EMPTY,
  'Tried to POP empty expression stack.',
  ERR_UNKNOWN_CONST_EXPR_PCD,
  'Unknown PCD in constant expression.',
  ERR_BAD_RADIX_CONSTANT,
  'Radix out of range in integer constant.',
  ERR_BAD_ASSIGNMENT,
  'Syntax error in multiple assignment statement.',
  ERR_OUT_OF_MEMORY,
  'Out of memory.',
  ERR_TOO_MANY_STRINGS,
  'Too many strings.',
  ERR_UNKNOWN_PRTYPE,
  'Unknown cast type in print statement.',
  ERR_NONE, NULL
  end;

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ERR_Exit
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure ERR_Exit(error_t error, boolean info, char *text, ...);
begin
  char workString[256];
  va_list argPtr;
   errFile: file;

  errFile :=  fopen(ErrorFileName, 'w');
  fprintf(stderr, '**** ERROR ****\n');
  if info = YES then
  begin
    sprintf(workString, 'Line %d in file \'%s\' ...\n', tk_Line,
      tk_SourceName);
    fprintf(stderr, workString);
    if errFile then
    begin
      fprintf(errFile, workString);
     end;
   end;
  if error <> ERR_NONE then
  begin
    if (ErrorText(error) <> NULL) then
    begin
      sprintf(workString, 'Error #%d: %s\n', error,
        ErrorText(error));
      fprintf(stderr, workString);
      if errFile then
      begin
        fprintf(errFile, workString);
       end;
     end;
   end;
  if text then
  begin
    va_start(argPtr, text);
    vsprintf(workString, text, argPtr);
    va_end(argPtr);
    fputs(workString, stderr);
    fputc('\n', stderr);
    if errFile then
    begin
      fprintf(errFile, workString);
     end;
   end;
  if errFile then
  begin
    fclose(errFile);
   end;
  exit(1);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ERR_RemoveErrorFile
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure ERR_RemoveErrorFile;
begin
  remove(ErrorFileName);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ErrorFileName
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static char *ErrorFileName;
begin
  static char errFileName[MAX_FILE_NAME_LENGTH];

  strcpy(errFileName, acs_SourceFileName);
  if (MS_StripFilename(errFileName) = NO) then
  begin
    strcpy(errFileName, ERROR_FILE_NAME);
   end;
  else
  begin
    strcat(errFileName, DIRECTORY_DELIMITER ERROR_FILE_NAME);
   end;
  return errFileName;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ErrorText
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static char *ErrorText(error_t error)
begin
  i: integer;

  for(i :=  0; ErrorNames[i].number <> ERR_NONE; i++)
  begin
    if error = ErrorNames[i].number then
    begin
      return ErrorNames[i].name;
     end;
   end;
  return NULL;
  end;
