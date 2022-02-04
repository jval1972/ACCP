
/(**************************************************************************
/(**
/(** symbol.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

#include <string.h>
#include <stdlib.h>
#include 'common.h'
#include 'symbol.h'
#include 'misc.h'

// MACROS ------------------------------------------------------------------
typedef enum
{
	SY_LABEL,
	SY_SCRIPTVAR,
	SY_MAPVAR,
	SY_WORLDVAR,
	SY_SPECIAL,
	SY_CONSTANT,
	SY_INTERNFUNC
} symbolType_t;

typedef struct
{
	int index;
} symVar_t;

typedef struct
{
	int address;
} symLabel_t;

typedef struct
{
	int value;
	int argCount;
} symSpecial_t;

typedef struct
{
	int value;
} symConstant_t;

typedef struct
{
	pcd_t directCommand;
	pcd_t stackCommand;
	int argCount;
	boolean hasReturnValue;
} symInternFunc_t;

typedef struct symbolNode_s
{
	struct symbolNode_s *left;
	struct symbolNode_s *right;
	char *name;
	symbolType_t type;
	union
	{
		symVar_t var;
		symLabel_t label;
		symSpecial_t special;
		symConstant_t constant;
		symInternFunc_t internFunc;
	} info;
} symbolNode_t;

// TYPES -------------------------------------------------------------------

typedef struct
begin
  char *name;
  pcd_t directCommand;
  pcd_t stackCommand;
  argCount: integer;
  boolean hasReturnValue;
  end; internFuncDef_t;

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

static symbolNode_t *Find(char *name, symbolNode_t *root);
static symbolNode_t *Insert(char *name, symbolType_t type,
  symbolNode_t **root);
static void FreeNodes(symbolNode_t *root);

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

// PUBLIC DATA DEFINITIONS -------------------------------------------------

// PRIVATE DATA DEFINITIONS ------------------------------------------------

static symbolNode_t *LocalRoot;
static symbolNode_t *GlobalRoot;

static internFuncDef_t InternalFunctions[] := 
begin
  'tagwait', PCD_TAGWAITDIRECT, PCD_TAGWAIT, 1, NO,
  'polywait', PCD_POLYWAITDIRECT, PCD_POLYWAIT, 1, NO,
  'scriptwait', PCD_SCRIPTWAITDIRECT, PCD_SCRIPTWAIT, 1, NO,
  'delay', PCD_DELAYDIRECT, PCD_DELAY, 1, NO,
  'random', PCD_RANDOMDIRECT, PCD_RANDOM, 2, YES,
  'thingcount', PCD_THINGCOUNTDIRECT, PCD_THINGCOUNT, 2, YES,
  'changefloor', PCD_CHANGEFLOORDIRECT, PCD_CHANGEFLOOR, 2, NO,
  'changeceiling', PCD_CHANGECEILINGDIRECT, PCD_CHANGECEILING, 2, NO,
  'lineside', PCD_NOP, PCD_LINESIDE, 0, YES,
  'clearlinespecial', PCD_NOP, PCD_CLEARLINESPECIAL, 0, NO,
  'playercount', PCD_NOP, PCD_PLAYERCOUNT, 0, YES,
  'gametype', PCD_NOP, PCD_GAMETYPE, 0, YES,
  'gameskill', PCD_NOP, PCD_GAMESKILL, 0, YES,
  'timer', PCD_NOP, PCD_TIMER, 0, YES,
  'sectorsound', PCD_NOP, PCD_SECTORSOUND, 2, NO,
  'ambientsound', PCD_NOP, PCD_AMBIENTSOUND, 2, NO,
  'soundsequence', PCD_NOP, PCD_SOUNDSEQUENCE, 1, NO,
  'setlinetexture', PCD_NOP, PCD_SETLINETEXTURE, 4, NO,
  'setlineblocking', PCD_NOP, PCD_SETLINEBLOCKING, 2, NO,
  'setlinespecial', PCD_NOP, PCD_SETLINESPECIAL, 7, NO,
  'thingsound', PCD_NOP, PCD_THINGSOUND, 3, NO,
  NULL
  end;

static char *SymbolTypeNames[] := 
begin
  'SY_LABEL',
  'SY_SCRIPTVAR',
  'SY_MAPVAR',
  'SY_WORLDVAR',
  'SY_SPECIAL',
  'SY_CONSTANT',
  'SY_INTERNFUNC'
  end;

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_Init
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure SY_Init;
begin
  symbolNode_t *sym;
  internFuncDef_t *def;

  LocalRoot :=  NULL;
  GlobalRoot :=  NULL;
  for(def :=  InternalFunctions; def.name <> NULL; def++)
  begin
    sym :=  SY_InsertGlobal(def.name, SY_INTERNFUNC);
    sym.info.internFunc.directCommand :=  def.directCommand;
    sym.info.internFunc.stackCommand :=  def.stackCommand;
    sym.info.internFunc.argCount :=  def.argCount;
    sym.info.internFunc.hasReturnValue :=  def.hasReturnValue;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_Find
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

symbolNode_t *SY_Find(char *name)
begin
  symbolNode_t *node;

  if ((node :=  SY_FindGlobal(name)) = NULL) then
  begin
    return SY_FindLocal(name);
   end;
  return node;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_FindGlobal
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

symbolNode_t *SY_FindGlobal(char *name)
begin
  return Find(name, GlobalRoot);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_Findlocal
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

symbolNode_t *SY_FindLocal(char *name)
begin
  return Find(name, LocalRoot);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// Find
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static symbolNode_t *Find(char *name, symbolNode_t *root)
begin
  compare: integer;
  symbolNode_t *node;

  node :=  root;
  while node <> NULL do
  begin
    compare :=  strcmp(name, node.name);
    if compare = 0 then
    begin
      return node;
     end;
    node :=  compare < 0 ? node.left : node.right;
   end;
  return NULL;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_InsertLocal
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

symbolNode_t *SY_InsertLocal(char *name, symbolType_t type)
begin
  MS_Message(MSG_DEBUG, 'Inserting local identifier: %s (%s)\n',
    name, SymbolTypeNames[type]);
  return Insert(name, type,) and (LocalRoot);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_InsertGlobal
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

symbolNode_t *SY_InsertGlobal(char *name, symbolType_t type)
begin
  MS_Message(MSG_DEBUG, 'Inserting global identifier: %s (%s)\n',
    name, SymbolTypeNames[type]);
  return Insert(name, type,) and (GlobalRoot);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// Insert
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static symbolNode_t *Insert(char *name, symbolType_t type,
  symbolNode_t **root)
  begin
  compare: integer;
  symbolNode_t *newNode;
  symbolNode_t *node;

  newNode :=  MS_Alloc(sizeof(symbolNode_t), ERR_NO_SYMBOL_MEM);
  newNode.name :=  MS_Alloc(strlen(name)+1, ERR_NO_SYMBOL_MEM);
  strcpy(newNode.name, name);
  newNode.left :=  newNode.right :=  NULL;
  newNode.type :=  type;
  while ((node :=  *root) <> NULL) do
  begin
    compare :=  strcmp(name, node.name);
    root :=  compare < 0 ?) and ((node.left) :) and ((node.right);
   end;
  *root :=  newNode;
  return(newNode);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_FreeLocals
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure SY_FreeLocals;
begin
  MS_Message(MSG_DEBUG, 'Freeing local identifiers\n');
  FreeNodes(LocalRoot);
  LocalRoot :=  NULL;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// SY_FreeGlobals
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure SY_FreeGlobals;
begin
  MS_Message(MSG_DEBUG, 'Freeing global identifiers\n');
  FreeNodes(GlobalRoot);
  GlobalRoot :=  NULL;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// FreeNodes
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

static void FreeNodes(symbolNode_t *root)
begin
  if root = NULL then
  begin
    exit;
   end;
  FreeNodes(root.left);
  FreeNodes(root.right);
  free(root.name);
  free(root);
  end;
