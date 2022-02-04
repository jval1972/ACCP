
/(**************************************************************************
/(**
/(** pcode.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

#include <string.h>
#include <stddef.h>
#include 'pcode.h'
#include 'common.h'
#include 'error.h'
#include 'misc.h'
#include 'strlist.h'

const
  OPEN_SCRIPTS_BASE = 1000;

const
  PCD_NOP = 0;
  PCD_TERMINATE = 1;
  PCD_SUSPEND = 2;
  PCD_PUSHNUMBER = 3;
  PCD_LSPEC1 = 4;
  PCD_LSPEC2 = 5;
  PCD_LSPEC3 = 6;
  PCD_LSPEC4 = 7;
  PCD_LSPEC5 = 8;
  PCD_LSPEC1DIRECT = 9;
  PCD_LSPEC2DIRECT = 10;
  PCD_LSPEC3DIRECT = 11;
  PCD_LSPEC4DIRECT = 12;
  PCD_LSPEC5DIRECT = 13;
  PCD_ADD = 14;
  PCD_SUBTRACT = 15;
  PCD_MULTIPLY = 16;
  PCD_DIVIDE = 17;
  PCD_MODULUS = 18;
  PCD_EQ = 19;
  PCD_NE = 20;
  PCD_LT = 21;
  PCD_GT = 22;
  PCD_LE = 23;
  PCD_GE = 24;
  PCD_ASSIGNSCRIPTVAR = 25;
  PCD_ASSIGNMAPVAR = 26;
  PCD_ASSIGNWORLDVAR = 27;
  PCD_PUSHSCRIPTVAR = 28;
  PCD_PUSHMAPVAR = 29;
  PCD_PUSHWORLDVAR = 30;
  PCD_ADDSCRIPTVAR = 31;
  PCD_ADDMAPVAR = 32;
  PCD_ADDWORLDVAR = 33;
  PCD_SUBSCRIPTVAR = 34;
  PCD_SUBMAPVAR = 35;
  PCD_SUBWORLDVAR = 36;
  PCD_MULSCRIPTVAR = 37;
  PCD_MULMAPVAR = 38;
  PCD_MULWORLDVAR = 39;
  PCD_DIVSCRIPTVAR = 40;
  PCD_DIVMAPVAR = 41;
  PCD_DIVWORLDVAR = 42;
  PCD_MODSCRIPTVAR = 43;
  PCD_MODMAPVAR = 44;
  PCD_MODWORLDVAR = 45;
  PCD_INCSCRIPTVAR = 46;
  PCD_INCMAPVAR = 47;
  PCD_INCWORLDVAR = 48;
  PCD_DECSCRIPTVAR = 49;
  PCD_DECMAPVAR = 50;
  PCD_DECWORLDVAR = 51;
  PCD_GOTO = 52;
  PCD_IFGOTO = 53;
  PCD_DROP = 54;
  PCD_DELAY = 55;
  PCD_DELAYDIRECT = 56;
  PCD_RANDOM = 57;
  PCD_RANDOMDIRECT = 58;
  PCD_THINGCOUNT = 59;
  PCD_THINGCOUNTDIRECT = 60;
  PCD_TAGWAIT = 61;
  PCD_TAGWAITDIRECT = 62;
  PCD_POLYWAIT = 63;
  PCD_POLYWAITDIRECT = 64;
  PCD_CHANGEFLOOR = 65;
  PCD_CHANGEFLOORDIRECT = 66;
  PCD_CHANGECEILING = 67;
  PCD_CHANGECEILINGDIRECT = 68;
  PCD_RESTART = 69;
  PCD_ANDLOGICAL = 70;
  PCD_ORLOGICAL = 71;
  PCD_ANDBITWISE = 72;
  PCD_ORBITWISE = 73;
  PCD_EORBITWISE = 74;
  PCD_NEGATELOGICAL = 75;
  PCD_LSHIFT = 76;
  PCD_RSHIFT = 77;
  PCD_UNARYMINUS = 78;
  PCD_IFNOTGOTO = 79;
  PCD_LINESIDE = 80;
  PCD_SCRIPTWAIT = 81;
  PCD_SCRIPTWAITDIRECT = 82;
  PCD_CLEARLINESPECIAL = 83;
  PCD_CASEGOTO = 84;
  PCD_BEGINPRINT = 85;
  PCD_ENDPRINT = 86;
  PCD_PRINTSTRING = 87;
  PCD_PRINTNUMBER = 88;
  PCD_PRINTCHARACTER = 89;
  PCD_PLAYERCOUNT = 90;
  PCD_GAMETYPE = 91;
  PCD_GAMESKILL = 92;
  PCD_TIMER = 93;
  PCD_SECTORSOUND = 94;
  PCD_AMBIENTSOUND = 95;
  PCD_SOUNDSEQUENCE = 96;
  PCD_SETLINETEXTURE = 97;
  PCD_SETLINEBLOCKING = 98;
  PCD_SETLINESPECIAL = 99;
  PCD_THINGSOUND = 100;
  PCD_ENDPRINTBOLD = 101;
  PCODE_COMMAND_COUNT = 102;

// TYPES -------------------------------------------------------------------

typedef struct scriptInfo_s
begin
  number: integer;
  address: integer;
  argCount: integer;
  end; scriptInfo_t;

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

static void Append(void *buffer, size_t size);
static void Write(void *buffer, size_t size, int address);
static void Skip(size_t size);

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

// PUBLIC DATA DEFINITIONS -------------------------------------------------

  pc_Address: integer;
byte *pc_Buffer;
byte *pc_BufferPtr;
  pc_ScriptCount: integer;

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static int BufferSize;
static boolean ObjectOpened :=  NO;
static scriptInfo_t ScriptInfo[MAX_SCRIPT_COUNT];
static char ObjectName[MAX_FILE_NAME_LENGTH];
static int ObjectFlags;

static char *PCDNames[PCODE_COMMAND_COUNT] := 
begin
  'PCD_NOP',
  'PCD_TERMINATE',
  'PCD_SUSPEND',
  'PCD_PUSHNUMBER',
  'PCD_LSPEC1',
  'PCD_LSPEC2',
  'PCD_LSPEC3',
  'PCD_LSPEC4',
  'PCD_LSPEC5',
  'PCD_LSPEC1DIRECT',
  'PCD_LSPEC2DIRECT',
  'PCD_LSPEC3DIRECT',
  'PCD_LSPEC4DIRECT',
  'PCD_LSPEC5DIRECT',
  'PCD_ADD',
  'PCD_SUBTRACT',
  'PCD_MULTIPLY',
  'PCD_DIVIDE',
  'PCD_MODULUS',
  'PCD_EQ',
  'PCD_NE',
  'PCD_LT',
  'PCD_GT',
  'PCD_LE',
  'PCD_GE',
  'PCD_ASSIGNSCRIPTVAR',
  'PCD_ASSIGNMAPVAR',
  'PCD_ASSIGNWORLDVAR',
  'PCD_PUSHSCRIPTVAR',
  'PCD_PUSHMAPVAR',
  'PCD_PUSHWORLDVAR',
  'PCD_ADDSCRIPTVAR',
  'PCD_ADDMAPVAR',
  'PCD_ADDWORLDVAR',
  'PCD_SUBSCRIPTVAR',
  'PCD_SUBMAPVAR',
  'PCD_SUBWORLDVAR',
  'PCD_MULSCRIPTVAR',
  'PCD_MULMAPVAR',
  'PCD_MULWORLDVAR',
  'PCD_DIVSCRIPTVAR',
  'PCD_DIVMAPVAR',
  'PCD_DIVWORLDVAR',
  'PCD_MODSCRIPTVAR',
  'PCD_MODMAPVAR',
  'PCD_MODWORLDVAR',
  'PCD_INCSCRIPTVAR',
  'PCD_INCMAPVAR',
  'PCD_INCWORLDVAR',
  'PCD_DECSCRIPTVAR',
  'PCD_DECMAPVAR',
  'PCD_DECWORLDVAR',
  'PCD_GOTO',
  'PCD_IFGOTO',
  'PCD_DROP',
  'PCD_DELAY',
  'PCD_DELAYDIRECT',
  'PCD_RANDOM',
  'PCD_RANDOMDIRECT',
  'PCD_THINGCOUNT',
  'PCD_THINGCOUNTDIRECT',
  'PCD_TAGWAIT',
  'PCD_TAGWAITDIRECT',
  'PCD_POLYWAIT',
  'PCD_POLYWAITDIRECT',
  'PCD_CHANGEFLOOR',
  'PCD_CHANGEFLOORDIRECT',
  'PCD_CHANGECEILING',
  'PCD_CHANGECEILINGDIRECT',
  'PCD_RESTART',
  'PCD_ANDLOGICAL',
  'PCD_ORLOGICAL',
  'PCD_ANDBITWISE',
  'PCD_ORBITWISE',
  'PCD_EORBITWISE',
  'PCD_NEGATELOGICAL',
  'PCD_LSHIFT',
  'PCD_RSHIFT',
  'PCD_UNARYMINUS',
  'PCD_IFNOTGOTO',
  'PCD_LINESIDE',
  'PCD_SCRIPTWAIT',
  'PCD_SCRIPTWAITDIRECT',
  'PCD_CLEARLINESPECIAL',
  'PCD_CASEGOTO',
  'PCD_BEGINPRINT',
  'PCD_ENDPRINT',
  'PCD_PRINTSTRING',
  'PCD_PRINTNUMBER',
  'PCD_PRINTCHARACTER',
  'PCD_PLAYERCOUNT',
  'PCD_GAMETYPE',
  'PCD_GAMESKILL',
  'PCD_TIMER',
  'PCD_SECTORSOUND',
  'PCD_AMBIENTSOUND',
  'PCD_SOUNDSEQUENCE',
  'PCD_SETLINETEXTURE',
  'PCD_SETLINEBLOCKING',
  'PCD_SETLINESPECIAL',
  'PCD_THINGSOUND',
  'PCD_ENDPRINTBOLD'
  end;

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PC_OpenObject
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure PC_OpenObject(char *name, size_t size, int flags);
begin
  if ObjectOpened = YES then
  begin
    PC_CloseObject;
   end;
  if (strlen(name) >= MAX_FILE_NAME_LENGTH) then
  begin
    ERR_Exit(ERR_FILE_NAME_TOO_LONG, NO, 'File: \'%s\'.', name);
   end;
  strcpy(ObjectName, name);
  pc_Buffer :=  MS_Alloc(size, ERR_ALLOC_PCODE_BUFFER);
  pc_BufferPtr :=  pc_Buffer;
  pc_Address :=  0;
  ObjectFlags :=  flags;
  BufferSize :=  size;
  pc_ScriptCount :=  0;
  ObjectOpened :=  YES;
  PC_AppendString('ACS');
  PC_SkipLong; // Script table offset
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PC_CloseObject
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure PC_CloseObject;
begin
  i: integer;
  scriptInfo_t *info;

  MS_Message(MSG_DEBUG, '---- PC_CloseObject ----\n');
  STR_WriteStrings;
  PC_WriteLong((U_LONG)pc_Address, 4);
  PC_AppendLong((U_LONG)pc_ScriptCount);
  for(i :=  0; i < pc_ScriptCount; i++)
  begin
    info := ) and (ScriptInfo[i];
    MS_Message(MSG_DEBUG, 'Script %d, address :=  %d, arg count :=  %d\n',
      info.number, info.address, info.argCount);
    PC_AppendLong((U_LONG)info.number);
    PC_AppendLong((U_LONG)info.address);
    PC_AppendLong((U_LONG)info.argCount);
   end;
  STR_WriteList;
  if (MS_SaveFile(ObjectName, pc_Buffer, pc_Address) = FALSE) then
  begin
    ERR_Exit(ERR_SAVE_OBJECT_FAILED, NO, NULL);
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PC_Append functions
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void Append(void *buffer, size_t size)
begin
  if pc_Address+size > BufferSize then
  begin
    ERR_Exit(ERR_PCODE_BUFFER_OVERFLOW, NO, NULL);
   end;
  memcpy(pc_BufferPtr, buffer, size);
  pc_BufferPtr := pc_BufferPtr + size;
  pc_Address := pc_Address + size;
  end;

procedure PC_Append(void *buffer, size_t size);
begin
  MS_Message(MSG_DEBUG, 'AD> %06d :=  (%d bytes)\n', pc_Address, size);
  Append(buffer, size);
  end;

(*
procedure PC_AppendByte(U_BYTE val);
begin
  MS_Message(MSG_DEBUG, 'AB> %06d :=  %d\n', pc_Address, val);
  Append and (val, sizeof(U_BYTE));
  end;
*)

(*
procedure PC_AppendWord(U_WORD val);
begin
  MS_Message(MSG_DEBUG, 'AW> %06d :=  %d\n', pc_Address, val);
  val :=  MS_LittleUWORD(val);
  Append and (val, sizeof(U_WORD));
  end;
*)

procedure PC_AppendLong(U_LONG val);
begin
  MS_Message(MSG_DEBUG, 'AL> %06d :=  %d\n', pc_Address, val);
  val :=  MS_LittleULONG(val);
  Append and (val, sizeof(U_LONG));
  end;

procedure PC_AppendString(char *string);
begin
  length: integer;

  length :=  strlen(string)+1;
  MS_Message(MSG_DEBUG, 'AS> %06d :=  \'%s\' (%d bytes)\n',
    pc_Address, string, length);
  Append(string, length);
  end;

procedure PC_AppendCmd(pcd_t command);
begin
  MS_Message(MSG_DEBUG, 'AC> %06d :=  #%d:%s\n', pc_Address,
    command, PCDNames[command]);
  command :=  MS_LittleULONG(command);
  Append and (command, sizeof(U_LONG));
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PC_Write functions
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void Write(void *buffer, size_t size, int address)
begin
  if address+size > BufferSize then
  begin
    ERR_Exit(ERR_PCODE_BUFFER_OVERFLOW, NO, NULL);
   end;
  memcpy(pc_Buffer+address, buffer, size);
  end;

procedure PC_Write(void *buffer, size_t size, int address);
begin
  MS_Message(MSG_DEBUG, 'WD> %06d :=  (%d bytes)\n', address, size);
  Write(buffer, size, address);
  end;

(*
procedure PC_WriteByte(U_BYTE val, int address);
begin
  MS_Message(MSG_DEBUG, 'WB> %06d :=  %d\n', address, val);
  Write and (val, sizeof(U_BYTE), address);
  end;
*)

(*
procedure PC_WriteWord(U_WORD val, int address);
begin
  MS_Message(MSG_DEBUG, 'WW> %06d :=  %d\n', address, val);
  val :=  MS_LittleUWORD(val);
  Write and (val, sizeof(U_WORD), address);
  end;
*)

procedure PC_WriteLong(U_LONG val, int address);
begin
  MS_Message(MSG_DEBUG, 'WL> %06d :=  %d\n', address, val);
  val :=  MS_LittleULONG(val);
  Write and (val, sizeof(U_LONG), address);
  end;

procedure PC_WriteString(char *string, int address);
begin
  length: integer;

  length :=  strlen(string)+1;
  MS_Message(MSG_DEBUG, 'WS> %06d :=  \'%s\' (%d bytes)\n',
    address, string, length);
  Write(string, length, address);
  end;

procedure PC_WriteCmd(pcd_t command, int address);
begin
  MS_Message(MSG_DEBUG, 'WC> %06d :=  #%d:%s\n', address,
    command, PCDNames[command]);
  command :=  MS_LittleULONG(command);
  Write and (command, sizeof(U_LONG), address);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PC_Skip functions
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void Skip(size_t size)
begin
  if pc_Address+size > BufferSize then
  begin
    ERR_Exit(ERR_PCODE_BUFFER_OVERFLOW, NO, NULL);
   end;
  pc_BufferPtr := pc_BufferPtr + size;
  pc_Address := pc_Address + size;
  end;

procedure PC_Skip(size_t size);
begin
  MS_Message(MSG_DEBUG, 'SD> %06d (skip %d bytes)\n',
    pc_Address, size);
  Skip(size);
  end;

(*
procedure PC_SkipByte;
begin
  MS_Message(MSG_DEBUG, 'SB> %06d (skip byte)\n', pc_Address);
  Skip(sizeof(U_BYTE));
  end;
*)

(*
procedure PC_SkipWord;
begin
  MS_Message(MSG_DEBUG, 'SW> %06d (skip word)\n', pc_Address);
  Skip(sizeof(U_WORD));
  end;
*)

procedure PC_SkipLong;
begin
  MS_Message(MSG_DEBUG, 'SL> %06d (skip long)\n', pc_Address);
  Skip(sizeof(U_LONG));
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// PC_AddScript
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure PC_AddScript(int number, int argCount);
begin
  scriptInfo_t *script;

  if pc_ScriptCount = MAX_SCRIPT_COUNT then
  begin
    ERR_Exit(ERR_TOO_MANY_SCRIPTS, YES, NULL);
   end;
  script := ) and (ScriptInfo[pc_ScriptCount];
  script.number :=  number;
  script.address :=  pc_Address;
  script.argCount :=  argCount;
  pc_ScriptCount++;
  end;
