
/(**************************************************************************
/(**
/(** acc.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include 'common.h'
#include 'token.h'
#include 'error.h'
#include 'symbol.h'
#include 'misc.h'
#include 'pcode.h'
#include 'parse.h'
#include 'strlist.h'

// MACROS ------------------------------------------------------------------

#define VERSION_TEXT '1.10'
#define COPYRIGHT_YEARS_TEXT '1995'

// TYPES -------------------------------------------------------------------

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

static void Init;
static void DisplayBanner;
static void DisplayUsage;
static void OpenDebugFile(char *name);
static void ProcessArgs;

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

// PUBLIC DATA DEFINITIONS -------------------------------------------------

boolean acs_BigEndianHost;
boolean acs_VerboseMode;
boolean acs_DebugMode;
   acs_DebugFile: file;
char acs_SourceFileName[MAX_FILE_NAME_LENGTH];

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static int ArgCount;
static char **ArgVector;
static char ObjectFileName[MAX_FILE_NAME_LENGTH];

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// main
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

int main(int argc, char **argv)
begin
  ArgCount :=  argc;
  ArgVector :=  argv;
  DisplayBanner;
  Init;

  TK_OpenSource(acs_SourceFileName);
  PC_OpenObject(ObjectFileName, DEFAULT_OBJECT_SIZE, 0);
  PA_Parse;
  PC_CloseObject;
  TK_CloseSource;

  MS_Message(MSG_NORMAL, '\n\'%s\':\n  %d %s (%d included),',
    acs_SourceFileName, tk_Line, tk_Line = 1 ? 'line' : 'lines',
    tk_IncludedLines);
  MS_Message(MSG_NORMAL, ' %d %s (%d open), %d functions\n',
    pa_ScriptCount, pa_ScriptCount = 1 ? 'script' : 'scripts',
    pa_OpenScriptCount, 0);
  MS_Message(MSG_NORMAL, '  %d world %s, %d map %s\n',
    pa_WorldVarCount, pa_WorldVarCount = 1 ? 'variable' :
    'variables', pa_MapVarCount, pa_MapVarCount = 1 ?
    'variable' : 'variables');
  MS_Message(MSG_NORMAL, '  object \'%s\': %d bytes\n',
    ObjectFileName, pc_Address);
  ERR_RemoveErrorFile;
  return 0;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// DisplayBanner
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void DisplayBanner;
begin
  fprintf(stderr, '\nACC Version 'VERSION_TEXT' ('__DATE__')'
    ' by Ben Gokey\n');
  fprintf(stderr, 'Copyright (c) 'COPYRIGHT_YEARS_TEXT
    ' Raven Software, Corp.\n');
{$IFDEF __WATCOMC__}
  fprintf(stderr, 'Uses the PMODE/W DOS extender, v1.21\n');
{$ENDIF}
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// Init
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void Init;
begin
{$IFDEF __NeXT__}
  // Fix this to properly detect host byte order on NeXT systems
  acs_BigEndianHost :=  NO;
{$ELSE}
  acs_BigEndianHost :=  NO;
{$ENDIF}
  acs_VerboseMode :=  YES;
  acs_DebugMode :=  NO;
  acs_DebugFile :=  NULL;
  TK_Init;
  SY_Init;
  STR_Init;
  ProcessArgs;
  MS_Message(MSG_NORMAL, 'Host byte order: %s endian\n',
    acs_BigEndianHost ? 'BIG' : 'LITTLE');
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// ProcessArgs
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void ProcessArgs;
begin
  i: integer;
  count: integer;
  char *text;
  char option;

  count :=  0;
  for(i :=  1; i < ArgCount; i++)
  begin
    text :=  ArgVector[i];
    if *text = '-' then
    begin
      text++;
      if *text = 0 then
      begin
        DisplayUsage;
       end;
      option :=  toupper(*text++);
      switch(option)
      begin
        'B':
          if *text <> 0 then
          begin
            DisplayUsage;
           end;
          acs_BigEndianHost :=  YES;
          break;
        'L':
          if *text <> 0 then
          begin
            DisplayUsage;
           end;
          acs_BigEndianHost :=  NO;
          break;
        'D':
          acs_DebugMode :=  YES;
          acs_VerboseMode :=  YES;
          if *text <> 0 then
          begin
            OpenDebugFile(text);
           end;
          break;
        default:
          DisplayUsage;
          break;
       end;
      continue;
     end;
    count++;
    switch(count)
    begin
      1:
        strcpy(acs_SourceFileName, text);
        MS_SuggestFileExt(acs_SourceFileName, '.acs');
        break;
      2:
        strcpy(ObjectFileName, text);
        MS_SuggestFileExt(ObjectFileName, '.o');
        break;
      default:
        DisplayUsage;
        break;
     end;
   end;
  if count = 0 then
  begin
    DisplayUsage;
   end;
  if count = 1 then
  begin
    strcpy(ObjectFileName, acs_SourceFileName);
    MS_StripFileExt(ObjectFileName);
    MS_SuggestFileExt(ObjectFileName, '.o');
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// DisplayUsage
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void DisplayUsage;
begin
  puts('Usage: ACC [options] source[.acs] [object[.o]]\n');
    puts('-b        Set host native byte order to big endian');
  puts('-l        Set host native byte order to little endian');
  puts('-d[file]  Output debugging information');
  exit(1);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OpenDebugFile
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void OpenDebugFile(char *name)
begin
  if ((acs_DebugFile :=  fopen(name, 'w')) = NULL) then
  begin
    ERR_Exit(ERR_CANT_OPEN_DBGFILE, NO, 'File: \'%s\'.', name);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// OptionExists
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

(*
static boolean OptionExists(char *name)
begin
  i: integer;
  char *arg;

  for(i :=  1; i < ArgCount; i++)
  begin
    arg :=  ArgVector[i];
    if *arg = '-' then
    begin
      arg++;
      if (MS_StrCmp(name, arg) = 0) then
      begin
        return YES;
       end;
     end;
   end;
  return NO;
  end;
*)
