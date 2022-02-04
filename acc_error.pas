//------------------------------------------------------------------------------
//
//  ACCP Compiler - ACS Compiler (Pascal)
//  Based on ACC code by by Ben Gokey.
//
//  Copyright (C) 1995 by Raven Software
//  Copyright (C) 2022 by Jim Valavanis
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/delphidoom/
//------------------------------------------------------------------------------

{$I Doom32.inc}

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

const
  ERROR_FILE_NAME = 'acs.err';

var
  ErrorFileName: string;

type
  errormessage_t = record
    number: Integer;
    name: string[40];
  end;

const
  NUMERRORNAME = 71;

var
  ErrorNames: array[0..NUMERRORNAME - 1] of errormessage_t = (
    (number: ERR_MISSING_SEMICOLON; name: 'Missing semicolon.'),
    (number: ERR_MISSING_LPAREN; name: 'Missing ''(''.'),
    (number: ERR_MISSING_RPAREN; name: 'Missing '')''.'),
    (number: ERR_MISSING_SCRIPT_NUMBER; name: 'Missing script number.'),
    (number: ERR_IDENTIFIER_TOO_LONG; name: 'Identifier too long.'),
    (number: ERR_STRING_TOO_LONG; name: 'String too long.'),
    (number: ERR_FILE_NAME_TOO_LONG; name: 'File name too long.'),
    (number: ERR_BAD_CHARACTER; name: 'Bad character in script text.'),
    (number: ERR_ALLOC_PCODE_BUFFER; name: 'Failed to allocate PCODE buffer.'),
    (number: ERR_PCODE_BUFFER_OVERFLOW; name: 'PCODE buffer overflow.'),
    (number: ERR_TOO_MANY_SCRIPTS; name: 'Too many scripts.'),
    (number: ERR_SAVE_OBJECT_FAILED; name: 'Couldn''t save object file.'),
    (number: ERR_MISSING_LPAREN_SCR; name: 'Missing ''('' in script definition.'),
    (number: ERR_INVALID_IDENTIFIER; name: 'Invalid identifier.'),
    (number: ERR_REDEFINED_IDENTIFIER; name: 'Redefined identifier.'),
    (number: ERR_MISSING_COMMA; name: 'Missing comma.'),
    (number: ERR_BAD_VAR_TYPE; name: 'Invalid variable type.'),
    (number: ERR_TOO_MANY_SCRIPT_ARGS; name: 'Too many script arguments.'),
    (number: ERR_MISSING_LBRACE_SCR; name: 'Missing opening ''{'' in script definition.'),
    (number: ERR_MISSING_RBRACE_SCR; name: 'Missing closing ''}'' in script definition.'),
    (number: ERR_TOO_MANY_MAP_VARS; name: 'Too many map variables.'),
    (number: ERR_TOO_MANY_SCRIPT_VARS; name: 'Too many script variables.'),
    (number: ERR_MISSING_WVAR_INDEX; name: 'Missing index in world variable declaration.'),
    (number: ERR_BAD_WVAR_INDEX; name: 'World variable index out of range.'),
    (number: ERR_MISSING_WVAR_COLON; name: 'Missing colon in world variable declaration.'),
    (number: ERR_MISSING_SPEC_VAL; name: 'Missing value in special declaration.'),
    (number: ERR_MISSING_SPEC_COLON; name: 'Missing colon in special declaration.'),
    (number: ERR_MISSING_SPEC_ARGC; name: 'Missing argument count in special declaration.'),
    (number: ERR_CANT_READ_FILE; name: 'Couldn''t read file.'),
    (number: ERR_CANT_OPEN_FILE; name: 'Couldn''t open file.'),
    (number: ERR_CANT_OPEN_DBGFILE; name: 'Couldn''t open debug file.'),
    (number: ERR_INVALID_DIRECTIVE; name: 'Invalid directive.'),
    (number: ERR_BAD_DEFINE; name: 'Non-numeric constant found in #define.'),
    (number: ERR_INCL_NESTING_TOO_DEEP; name: 'Include nesting too deep.'),
    (number: ERR_STRING_LIT_NOT_FOUND; name: 'String literal not found.'),
    (number: ERR_INVALID_DECLARATOR; name: 'Invalid declarator.'),
    (number: ERR_BAD_LSPEC_ARG_COUNT; name: 'Incorrect number of special arguments.'),
    (number: ERR_BAD_ARG_COUNT; name: 'Incorrect number of arguments.'),
    (number: ERR_UNKNOWN_IDENTIFIER; name: 'Identifier has not been declared.'),
    (number: ERR_MISSING_COLON; name: 'Missing colon.'),
    (number: ERR_BAD_EXPR; name: 'Syntax error in expression.'),
    (number: ERR_BAD_CONST_EXPR; name: 'Syntax error in constant expression.'),
    (number: ERR_NO_DIRECT_VER; name: 'Internal function has no direct version.'),
    (number: ERR_ILLEGAL_EXPR_IDENT; name: 'Illegal identifier in expression.'),
    (number: ERR_EXPR_FUNC_NO_RET_VAL; name: 'Function call in expression has no return value.'),
    (number: ERR_MISSING_ASSIGN_OP; name: 'Missing assignment operator.'),
    (number: ERR_INCDEC_OP_ON_NON_VAR; name: '''++'' or ''--'' used on a non-variable.'),
    (number: ERR_MISSING_RBRACE; name: 'Missing ''}'' at end of compound statement.'),
    (number: ERR_INVALID_STATEMENT; name: 'Invalid statement.'),
    (number: ERR_BAD_DO_STATEMENT; name: 'Do statement not followed by ''while'' or ''until''.'),
    (number: ERR_BAD_SCRIPT_DECL; name: 'Bad script declaration.'),
    (number: ERR_CASE_OVERFLOW; name: 'Internal Error: stack overflow.'),
    (number: ERR_BREAK_OVERFLOW; name: 'Internal Error: Break stack overflow.'),
    (number: ERR_CONTINUE_OVERFLOW; name: 'Internal Error: Continue stack overflow.'),
    (number: ERR_STATEMENT_OVERFLOW; name: 'Internal Error: Statement overflow.'),
    (number: ERR_MISPLACED_BREAK; name: 'Misplaced BREAK statement.'),
    (number: ERR_MISPLACED_CONTINUE; name: 'Misplaced CONTINUE statement.'),
    (number: ERR_CASE_NOT_IN_SWITCH; name: 'CASE must appear in case statement.'),
    (number: ERR_DEFAULT_NOT_IN_SWITCH; name: 'DEFAULT must appear in case statement.'),
    (number: ERR_MULTIPLE_DEFAULT; name: 'Only 1 DEFAULT per case allowed.'),
    (number: ERR_EXPR_STACK_OVERFLOW; name: 'Expression stack overflow.'),
    (number: ERR_EXPR_STACK_EMPTY; name: 'Tried to POP empty expression stack.'),
    (number: ERR_UNKNOWN_CONST_EXPR_PCD; name: 'Unknown PCD in constant expression.'),
    (number: ERR_BAD_RADIX_CONSTANT; name: 'Radix out of range in integer constant.'),
    (number: ERR_BAD_ASSIGNMENT; name: 'Syntax error in multiple assignment statement.'),
    (number: ERR_OUT_OF_MEMORY; name: 'Out of memory.'),
    (number: ERR_TOO_MANY_STRINGS; name: 'Too many strings.'),
    (number: ERR_UNKNOWN_PRTYPE; name: 'Unknown cast type in print statement.'),
    (number: ERR_NONE; name: '')
  );
  end;

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
