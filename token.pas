
/(**************************************************************************
/(**
/(** token.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

{$IFDEF __NeXT__}
#include <libc.h>
{$ELSE}
#include <io.h>
#include <fcntl.h>
#include <stdlib.h>
{$ENDIF}
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include 'common.h'
#include 'token.h'
#include 'error.h'
#include 'misc.h'
#include 'symbol.h'

// MACROS ------------------------------------------------------------------

#define NON_HEX_DIGIT 255
#define MAX_NESTED_SOURCES 16

// TYPES -------------------------------------------------------------------

typedef enum
begin
  CHR_EOF,
  CHR_LETTER,
  CHR_NUMBER,
  CHR_QUOTE,
  CHR_SPECIAL
  end; chr_t;

typedef struct
begin
  char name[MAX_FILE_NAME_LENGTH];
  char *start;
  char *end;
  char *position;
  line: integer;
  boolean incLineNumber;
  char lastChar;
  end; nestInfo_t;

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

static void MakeIncludePath(char *sourceName);
static void PopNestedSource;
static void ProcessLetterToken;
static void ProcessNumberToken;
static void EvalFixedConstant(int whole);
static void EvalHexConstant;
static void EvalRadixConstant;
static int DigitValue(char digit, int radix);
static void ProcessQuoteToken;
static void ProcessSpecialToken;
static boolean CheckForKeyword;
static boolean CheckForLineSpecial;
static boolean CheckForConstant;
static void NextChr;
static void SkipComment;
static void SkipCPPComment;

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

// PUBLIC DATA DEFINITIONS -------------------------------------------------

tokenType_t tk_Token;
  tk_Line: integer;
  tk_Number: integer;
char *tk_String;
  tk_SpecialValue: integer;
  tk_SpecialArgCount: integer;
char tk_SourceName[MAX_FILE_NAME_LENGTH];
  tk_IncludedLines: integer;

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static char Chr;
static char *FileStart;
static char *FilePtr;
static char *FileEnd;
static boolean SourceOpen;
static char ASCIIToChrCode[256];
static byte ASCIIToHexDigit[256];
static char TokenStringBuffer[MAX_QUOTED_LENGTH];
static nestInfo_t OpenFiles[MAX_NESTED_SOURCES];
static boolean AlreadyGot;
static int NestDepth;
static boolean IncLineNumber;
static char IncludePath[MAX_FILE_NAME_LENGTH];

static struct
begin
  char *name;
  tokenType_t token;
  end; Keywords[] :=
  begin
  'break', TK_BREAK,
  'case', TK_CASE,
  'const', TK_CONST,
  'continue', TK_CONTINUE,
  'default', TK_DEFAULT,
  'define', TK_DEFINE,
  'do', TK_DO,
  'else', TK_ELSE,
  'for', TK_FOR,
  'goto', TK_GOTO,
  'if', TK_IF,
  'include', TK_INCLUDE,
  'int', TK_INT,
  'open', TK_OPEN,
  'print', TK_PRINT,
  'printbold', TK_PRINTBOLD,
  'restart', TK_RESTART,
  'script', TK_SCRIPT,
  'special', TK_SPECIAL,
  'str', TK_STR,
  'suspend', TK_SUSPEND,
  'switch', TK_SWITCH,
  'terminate', TK_TERMINATE,
  'until', TK_UNTIL,
  'void', TK_VOID,
  'while', TK_WHILE,
  'world', TK_WORLD,
  NULL, -1
  end;

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_Init
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_Init;
begin
  i: integer;

  for(i :=  0; i < 256; i++)
  begin
    ASCIIToChrCode[i] :=  CHR_SPECIAL;
    ASCIIToHexDigit[i] :=  NON_HEX_DIGIT;
   end;
  for(i :=  '0'; i <= '9'; i++)
  begin
    ASCIIToChrCode[i] :=  CHR_NUMBER;
    ASCIIToHexDigit[i] :=  i-'0';
   end;
  for(i :=  'A'; i <= 'F'; i++)
  begin
    ASCIIToHexDigit[i] :=  10+(i-'A');
   end;
  for(i :=  'a'; i <= 'f'; i++)
  begin
    ASCIIToHexDigit[i] :=  10+(i-'a');
   end;
  for(i :=  'A'; i <= 'Z'; i++)
  begin
    ASCIIToChrCode[i] :=  CHR_LETTER;
   end;
  for(i :=  'a'; i <= 'z'; i++)
  begin
    ASCIIToChrCode[i] :=  CHR_LETTER;
   end;
  ASCIIToChrCode[ASCII_QUOTE] :=  CHR_QUOTE;
  ASCIIToChrCode[ASCII_UNDERSCORE] :=  CHR_LETTER;
  ASCIIToChrCode[EOF_CHARACTER] :=  CHR_EOF;
  tk_String :=  TokenStringBuffer;
  IncLineNumber :=  FALSE;
  tk_IncludedLines :=  0;
  SourceOpen :=  FALSE;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_OpenSource
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_OpenSource(char *fileName);
begin
  size: integer;

  TK_CloseSource;
  size :=  MS_LoadFile(fileName, (void **)) and (FileStart);
  strcpy(tk_SourceName, fileName);
  MakeIncludePath(fileName);
  SourceOpen :=  TRUE;
  FileEnd :=  FileStart+size;
  FilePtr :=  FileStart;
  tk_Line :=  1;
  tk_Token :=  TK_NONE;
  AlreadyGot :=  FALSE;
  NestDepth :=  0;
  NextChr;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MakeIncludePath
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void MakeIncludePath(char *sourceName)
begin
  strcpy(IncludePath, sourceName);
  if (MS_StripFilename(IncludePath) = NO) then
  begin
    IncludePath[0] :=  0;
   end;
  else
   begin  // Add a directory delimiter to the include path
    strcat(IncludePath, DIRECTORY_DELIMITER);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_Include
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_Include(char *fileName);
begin
  size: integer;
  nestInfo_t *info;

  if NestDepth = MAX_NESTED_SOURCES then
  begin
    ERR_Exit(ERR_INCL_NESTING_TOO_DEEP, YES,
      'Unable to include file \'%s\'.', fileName);
   end;
  info := ) and (OpenFiles[NestDepth++];
  strcpy(info.name, tk_SourceName);
  info.start :=  FileStart;
  info.end :=  FileEnd;
  info.position :=  FilePtr;
  info.line :=  tk_Line;
  info.incLineNumber :=  IncLineNumber;
  info.lastChar :=  Chr;
  strcpy(tk_SourceName, IncludePath);
  strcat(tk_SourceName, fileName);
  size :=  MS_LoadFile(tk_SourceName, (void **)) and (FileStart);
  FileEnd :=  FileStart+size;
  FilePtr :=  FileStart;
  tk_Line :=  1;
  IncLineNumber :=  FALSE;
  tk_Token :=  TK_NONE;
  AlreadyGot :=  FALSE;
  NextChr;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PopNestedSource
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void PopNestedSource;
begin
  nestInfo_t *info;

  free(FileStart);
  tk_IncludedLines := tk_IncludedLines + tk_Line;
  info := ) and (OpenFiles[--NestDepth];
  strcpy(tk_SourceName, info.name);
  FileStart :=  info.start;
  FileEnd :=  info.end;
  FilePtr :=  info.position;
  tk_Line :=  info.line;
  IncLineNumber :=  info.incLineNumber;
  Chr :=  info.lastChar;
  tk_Token :=  TK_NONE;
  AlreadyGot :=  FALSE;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_CloseSource
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_CloseSource;
begin
  i: integer;

  if SourceOpen then
  begin
    free(FileStart);
    for(i :=  0; i < NestDepth; i++)
    begin
      free(OpenFiles[i].start);
     end;
    SourceOpen :=  FALSE;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_NextToken
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

tokenType_t TK_NextToken;
begin
  boolean validToken;

  if AlreadyGot = TRUE then
  begin
    AlreadyGot :=  FALSE;
    return tk_Token;
   end;
  validToken :=  NO;
  do
  begin
    while Chr = ASCII_SPACE do
    begin
      NextChr;
     end;
    switch(ASCIIToChrCode[(byte)Chr])
    begin
      CHR_EOF:
        tk_Token :=  TK_EOF;
        break;
      CHR_LETTER:
        ProcessLetterToken;
        break;
      CHR_NUMBER:
        ProcessNumberToken;
        break;
      CHR_QUOTE:
        ProcessQuoteToken;
        break;
      default:
        ProcessSpecialToken;
        break;
     end;
    if tk_Token = TK_STARTCOMMENT then
    begin
      SkipComment;
    end
    else if tk_Token = TK_CPPCOMMENT then
    begin
      SkipCPPComment;
    end
    else if ((tk_Token = TK_EOF)) and ((NestDepth > 0)) then
    begin
      PopNestedSource;
     end;
    else
    begin
      validToken :=  YES;
     end;
   end; while(validToken = NO);
  return tk_Token;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_NextCharacter
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

  TK_NextCharacter: integer;
  begin
  c: integer;

  while Chr = ASCII_SPACE do
  begin
    NextChr;
   end;
  c :=  (int)Chr;
  if c = EOF_CHARACTER then
  begin
    c :=  -1;
   end;
  NextChr;
  return c;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_NextTokenMustBe
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_NextTokenMustBe(tokenType_t token, error_t error);
begin
  if TK_NextToken <> token then
  begin
    ERR_Exit(error, YES, NULL);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_TokenMustBe
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_TokenMustBe(tokenType_t token, error_t error);
begin
  if tk_Token <> token then
  begin
    ERR_Exit(error, YES, NULL);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_Member
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

boolean TK_Member(tokenType_t *list)
begin
  i: integer;

  for(i :=  0; list[i] <> TK_NONE; i++)
  begin
    if tk_Token = list[i] then
    begin
      return YES;
     end;
   end;
  return NO;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// TK_Undo
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure TK_Undo;
begin
  if tk_Token <> TK_NONE then
  begin
    AlreadyGot :=  TRUE;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessLetterToken
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void ProcessLetterToken;
begin
  i: integer;
  char *text;

  i :=  0;
  text :=  TokenStringBuffer;
  while(ASCIIToChrCode[(byte)Chr] = CHR_LETTER
   ) or (ASCIIToChrCode[(byte)Chr] = CHR_NUMBER)
   begin
    if ++i = MAX_IDENTIFIER_LENGTH then
    begin
      ERR_Exit(ERR_IDENTIFIER_TOO_LONG, YES, NULL);
     end;
    *text++:=  Chr;
    NextChr;
   end;
  *text :=  0;
  MS_StrLwr(TokenStringBuffer);
  if(CheckForKeyword = FALSE
   ) and (CheckForLineSpecial = FALSE
   ) and (CheckForConstant = FALSE)
   begin
    tk_Token :=  TK_IDENTIFIER;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// CheckForKeyword
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean CheckForKeyword;
begin
  i: integer;

  for(i :=  0; Keywords[i].name <> NULL; i++)
  begin
    if (strcmp(tk_String, Keywords[i].name) = 0) then
    begin
      tk_Token :=  Keywords[i].token;
      return TRUE;
     end;
   end;
  return FALSE;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// CheckForLineSpecial
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean CheckForLineSpecial;
begin
  symbolNode_t *sym;

  sym :=  SY_FindGlobal(tk_String);
  if sym = NULL then
  begin
    return FALSE;
   end;
  if sym.type <> SY_SPECIAL then
  begin
    return FALSE;
   end;
  tk_Token :=  TK_LINESPECIAL;
  tk_SpecialValue :=  sym.info.special.value;
  tk_SpecialArgCount :=  sym.info.special.argCount;
  return TRUE;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// CheckForConstant
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static boolean CheckForConstant;
begin
  symbolNode_t *sym;

  sym :=  SY_FindGlobal(tk_String);
  if sym = NULL then
  begin
    return FALSE;
   end;
  if sym.type <> SY_CONSTANT then
  begin
    return FALSE;
   end;
  tk_Token :=  TK_NUMBER;
  tk_Number :=  sym.info.constant.value;
  return TRUE;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessNumberToken
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void ProcessNumberToken;
begin
  char c;

  c :=  Chr;
  NextChr;
  if (c = '0') and ((Chr = 'x') or (Chr = 'X')) then
   begin  // Hexadecimal constant
    NextChr;
    EvalHexConstant;
    exit;
   end;
  tk_Number :=  c-'0';
  while (ASCIIToChrCode[(byte)Chr] = CHR_NUMBER) do
  begin
    tk_Number :=  10*tk_Number+(Chr-'0');
    NextChr;
   end;
  if Chr = '.' then
   begin  // Fixed point
    NextChr; // Skip period
    EvalFixedConstant(tk_Number);
    exit;
   end;
  if Chr = ASCII_UNDERSCORE then
  begin
    NextChr; // Skip underscore
    EvalRadixConstant;
    exit;
   end;
  tk_Token :=  TK_NUMBER;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// EvalFixedConstant
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void EvalFixedConstant(int whole)
begin
  frac: integer;
  divisor: integer;

  frac :=  0;
  divisor :=  1;
  while (ASCIIToChrCode[(byte)Chr] = CHR_NUMBER) do
  begin
    frac :=  10*frac+(Chr-'0');
    divisor := divisor * 10;
    NextChr;
   end;
  tk_Number :=  (whole shl 16)+((frac shl 16)/divisor);
  tk_Token :=  TK_NUMBER;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// EvalHexConstant
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void EvalHexConstant;
begin
  tk_Number :=  0;
  while (ASCIIToHexDigit[(byte)Chr] <> NON_HEX_DIGIT) do
  begin
    tk_Number :=  (tk_Number shl 4)+ASCIIToHexDigit[(byte)Chr];
    NextChr;
   end;
  tk_Token :=  TK_NUMBER;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// EvalRadixConstant
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void EvalRadixConstant;
begin
  radix: integer;
  digitVal: integer;

  radix :=  tk_Number;
  if (radix < 2) or (radix > 36) then
  begin
    ERR_Exit(ERR_BAD_RADIX_CONSTANT, YES, NULL);
   end;
  tk_Number :=  0;
  while ((digitVal :=  DigitValue(Chr, radix)) <> -1) do
  begin
    tk_Number :=  radix*tk_Number+digitVal;
    NextChr;
   end;
  tk_Token :=  TK_NUMBER;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// DigitValue
//
// Returns -1 if the digit is not allowed in the specified radix.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static int DigitValue(char digit, int radix)
begin
  digit :=  toupper(digit);
  if (digit < '0') or ((digit > '9') and (digit < 'A')) or (digit > 'Z') then
  begin
    return -1;
   end;
  if digit > '9' then
  begin
    digit :=  10+digit-'A';
   end;
  else
  begin
    digit -:=  '0';
   end;
  if digit >= radix then
  begin
    return -1;
   end;
  return digit;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessQuoteToken
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void ProcessQuoteToken;
begin
  i: integer;
  char *text;

  i :=  0;
  text :=  TokenStringBuffer;
  NextChr;
  while Chr <> EOF_CHARACTER do
  begin
    if Chr = ASCII_QUOTE then
    begin
      break;
     end;
    if ++i > MAX_QUOTED_LENGTH-1 then
    begin
      ERR_Exit(ERR_STRING_TOO_LONG, YES, NULL);
     end;
    *text++:=  Chr;
    NextChr;
   end;
  *text :=  0;
  if Chr = ASCII_QUOTE then
  begin
    NextChr;
   end;
  tk_Token :=  TK_STRING;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessSpecialToken
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void ProcessSpecialToken;
begin
  char c;

  c :=  Chr;
  NextChr;
  switch(c)
  begin
    '+':
      switch(Chr)
      begin
        ' := ':
          tk_Token :=  TK_ADDASSIGN;
          NextChr;
          break;
        '+':
          tk_Token :=  TK_INC;
          NextChr;
          break;
        default:
          tk_Token :=  TK_PLUS;
          break;
       end;
      break;
    '-':
      switch(Chr)
      begin
        ' := ':
          tk_Token :=  TK_SUBASSIGN;
          NextChr;
          break;
        '-':
          tk_Token :=  TK_DEC;
          NextChr;
          break;
        default:
          tk_Token :=  TK_MINUS;
          break;
       end;
      break;
    '*':
      switch(Chr)
      begin
        ' := ':
          tk_Token :=  TK_MULASSIGN;
          NextChr;
          break;
        '/':
          tk_Token :=  TK_ENDCOMMENT;
          NextChr;
          break;
        default:
          tk_Token :=  TK_ASTERISK;
          break;
       end;
      break;
    '/':
      switch(Chr)
      begin
        ' := ':
          tk_Token :=  TK_DIVASSIGN;
          NextChr;
          break;
        '/':
          tk_Token :=  TK_CPPCOMMENT;
          break;
        '*':
          tk_Token :=  TK_STARTCOMMENT;
          NextChr;
          break;
        default:
          tk_Token :=  TK_SLASH;
          break;
       end;
      break;
    '%':
      if Chr = ' := ' then
      begin
        tk_Token :=  TK_MODASSIGN;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_PERCENT;
       end;
      break;
    ' := ':
      if Chr = ' := ' then
      begin
        tk_Token :=  TK_EQ;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_ASSIGN;
       end;
      break;
    '<':
      if Chr = ' := ' then
      begin
        tk_Token :=  TK_LE;
        NextChr;
      end
      else if Chr = '<' then
      begin
        tk_Token :=  TK_LSHIFT;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_LT;
       end;
      break;
    '>':
      if Chr = ' := ' then
      begin
        tk_Token :=  TK_GE;
        NextChr;
      end
      else if Chr = '>' then
      begin
        tk_Token :=  TK_RSHIFT;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_GT;
       end;
      break;
    ' not ':
      if Chr = ' := ' then
      begin
        tk_Token :=  TK_NE;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_NOT;
       end;
      break;
    ') and (':
      if (Chr = ') and (') then
      begin
        tk_Token :=  TK_ANDLOGICAL;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_ANDBITWISE;
       end;
      break;
    ') or (':
      if (Chr = ') or (') then
      begin
        tk_Token :=  TK_ORLOGICAL;
        NextChr;
       end;
      else
      begin
        tk_Token :=  TK_ORBITWISE;
       end;
      break;
    '(':
      tk_Token :=  TK_LPAREN;
      break;
    ')':
      tk_Token :=  TK_RPAREN;
      break;
    ' begin ':
      tk_Token :=  TK_LBRACE;
      break;
    ' end;':
      tk_Token :=  TK_RBRACE;
      break;
    '[':
      tk_Token :=  TK_LBRACKET;
      break;
    ']':
      tk_Token :=  TK_RBRACKET;
      break;
    ':':
      tk_Token :=  TK_COLON;
      break;
    ';':
      tk_Token :=  TK_SEMICOLON;
      break;
    ',':
      tk_Token :=  TK_COMMA;
      break;
    '.':
      tk_Token :=  TK_PERIOD;
      break;
    '#':
      tk_Token :=  TK_NUMBERSIGN;
      break;
    ') xor (':
      tk_Token :=  TK_EORBITWISE;
      break;
    '~':
      tk_Token :=  TK_TILDE;
      break;
    default:
      ERR_Exit(ERR_BAD_CHARACTER, YES, NULL);
      break;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// NextChr
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void NextChr;
begin
  if FilePtr >= FileEnd then
  begin
    Chr :=  EOF_CHARACTER;
    exit;
   end;
  if IncLineNumber = TRUE then
  begin
    tk_Line++;
    IncLineNumber :=  FALSE;
   end;
  Chr :=  *FilePtr++;
  if Chr < ASCII_SPACE then
  begin
    if Chr = '\n' then
    begin
      IncLineNumber :=  TRUE;
     end;
    Chr :=  ASCII_SPACE;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SkipComment
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure SkipComment;
begin
  boolean first;

  first :=  FALSE;
  while Chr <> EOF_CHARACTER do
  begin
    if (first = TRUE) and (Chr = '/') then
    begin
      break;
     end;
    first :=  (Chr = '*');
    NextChr;
   end;
  NextChr;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SkipCPPComment
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure SkipCPPComment;
begin
  while FilePtr < FileEnd do
  begin
    if *FilePtr++ = '\n' then
    begin
      tk_Line++;
      break;
     end;
   end;
  NextChr;
  end;