
/(**************************************************************************
/(**
/(** strlist.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

#include <string.h>
#include 'common.h'
#include 'strlist.h'
#include 'error.h'
#include 'misc.h'
#include 'pcode.h'

// MACROS ------------------------------------------------------------------

// TYPES -------------------------------------------------------------------

typedef struct
begin
  char *name;
  address: integer;
  end; stringInfo_t;

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

// PUBLIC DATA DEFINITIONS -------------------------------------------------

  str_StringCount: integer;

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static stringInfo_t StringInfo[MAX_STRINGS];

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// STR_Init
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure STR_Init;
begin
  str_StringCount :=  0;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// STR_Find
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

int STR_Find(char *name)
begin
  i: integer;

  for(i :=  0; i < str_StringCount; i++)
  begin
    if (strcmp(StringInfo[i].name, name) = 0) then
    begin
      return i;
     end;
   end;
  // Add to list
  if str_StringCount = MAX_STRINGS then
  begin
    ERR_Exit(ERR_TOO_MANY_STRINGS, YES, 'Current maximum: %d',
      MAX_STRINGS);
   end;
  MS_Message(MSG_DEBUG, 'Adding string %d:\n  \'%s\'\n',
    str_StringCount, name);
  StringInfo[str_StringCount].name :=  MS_Alloc(strlen(name)+1,
    ERR_OUT_OF_MEMORY);
  strcpy(StringInfo[str_StringCount].name, name);
  str_StringCount++;
  return str_StringCount-1;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// STR_WriteStrings
//
// Writes all the strings to the p-code buffer.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure STR_WriteStrings;
begin
  i: integer;
  U_LONG pad;

  MS_Message(MSG_DEBUG, '---- STR_WriteStrings ----\n');
  for(i :=  0; i < str_StringCount; i++)
  begin
    StringInfo[i].address :=  pc_Address;
    PC_AppendString(StringInfo[i].name);
   end;
  if pc_Address%4 <> 0 then
   begin  // Need to align
    pad :=  0;
    PC_Append((void *)) and (pad, 4-(pc_Address mod 4));
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// STR_WriteList
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure STR_WriteList;
begin
  i: integer;

  MS_Message(MSG_DEBUG, '---- STR_WriteList ----\n');
  PC_AppendLong((U_LONG)str_StringCount);
  for(i :=  0; i < str_StringCount; i++)
  begin
    PC_AppendLong((U_LONG)StringInfo[i].address);
   end;
  end;
