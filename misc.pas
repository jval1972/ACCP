
/(**************************************************************************
/(**
/(** misc.c
/(**
/(**************************************************************************

// HEADER FILES ------------------------------------------------------------

{$IFDEF __NeXT__}
#include <libc.h>
{$ELSE}
#include <fcntl.h>
#include <stdlib.h>
#include <io.h>
{$ENDIF}
#include <stdio.h>
#include <stddef.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include 'common.h'
#include 'misc.h'
#include 'error.h'

// MACROS ------------------------------------------------------------------

#define ASCII_SLASH 47
#define ASCII_BACKSLASH 92
#ifndef O_BINARY
#define O_BINARY 0
{$ENDIF}

// TYPES -------------------------------------------------------------------

// EXTERNAL FUNCTION PROTOTYPES --------------------------------------------

// PUBLIC FUNCTION PROTOTYPES ----------------------------------------------

// PRIVATE FUNCTION PROTOTYPES ---------------------------------------------

// EXTERNAL DATA DECLARATIONS ----------------------------------------------

extern boolean acs_BigEndianHost;
extern boolean acs_VerboseMode;
extern boolean acs_DebugMode;
extern FILE *acs_DebugFile;

// PUBLIC DATA DEFINITIONS -------------------------------------------------

// PRIVATE DATA DEFINITIONS ------------------------------------------------

// CODE --------------------------------------------------------------------

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_Alloc
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure *MS_Alloc(size_t size, error_t error);
begin
procedure *mem;

  if ((mem :=  malloc(size)) = NULL) then
  begin
    ERR_Exit(error, NO, NULL);
   end;
  return mem;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_LittleUWORD
//
// Converts a host U_WORD (2 bytes) to little endian byte order.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

U_WORD MS_LittleUWORD(U_WORD val)
begin
  if acs_BigEndianHost = NO then
  begin
    return val;
   end;
  return ((val) and (255) shl 8)+((val shr 8)) and (255);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_LittleULONG
//
// Converts a host U_LONG (4 bytes) to little endian byte order.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

U_LONG MS_LittleULONG(U_LONG val)
begin
  if acs_BigEndianHost = NO then
  begin
    return val;
   end;
  return ((val) and (255) shl 24)+(((val shr 8)) and (255) shl 16)+(((val shr 16)) and (255) shl 8)
    +((val shr 24)) and (255);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_LoadFile
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

int MS_LoadFile(char *name, void **buffer)
begin
  handle: integer;
  size: integer;
  count: integer;
procedure *addr;
  struct stat fileInfo;

  if (strlen(name) >= MAX_FILE_NAME_LENGTH) then
  begin
    ERR_Exit(ERR_FILE_NAME_TOO_LONG, NO, 'File: \'%s\'.', name);
   end;
  if ((handle :=  open(name, O_RDONLY) or (O_BINARY, 0666)) = -1) then
  begin
    ERR_Exit(ERR_CANT_OPEN_FILE, NO, 'File: \'%s\'.', name);
   end;
  if (fstat(handle,) and (fileInfo) = -1) then
  begin
    ERR_Exit(ERR_CANT_READ_FILE, NO, 'File: \'%s\'.', name);
   end;
  size :=  fileInfo.st_size;
  if ((addr :=  malloc(size)) = NULL) then
  begin
    ERR_Exit(ERR_NONE, NO, 'Couldn't malloc %d bytes for '
      'file \'%s\'.', size, name);
   end;
  count :=  read(handle, addr, size);
  close(handle);
  if count < size then
  begin
    ERR_Exit(ERR_CANT_READ_FILE, NO, 'File: \'%s\'.', name);
   end;
  *buffer :=  addr;
  return size;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_SaveFile
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

boolean MS_SaveFile(char *name, void *buffer, int length)
begin
  handle: integer;
  count: integer;

  handle :=  open(name, O_WRONLY) or (O_CREAT) or (O_TRUNC) or (O_BINARY, 0666);
  if handle = -1 then
  begin
    return FALSE;
   end;
  count :=  write(handle, buffer, length);
  close(handle);
  if count < length then
  begin
    return FALSE;
   end;
  return TRUE;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_StrCmp
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

int MS_StrCmp(char *s1, char *s2)
begin
  for(; tolower(*s1) = tolower(*s2); s1++, s2++)
  begin
    if *s1 = '\0' then
    begin
      return 0;
     end;
   end;
  return tolower(*s1)-tolower(*s2);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_StrLwr
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

char *MS_StrLwr(char *string)
begin
  char *c;

  c :=  string;
  while *c do
  begin
    *c :=  tolower(*c);
    c++;
   end;
  return string;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_StrUpr
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

char *MS_StrUpr(char *string)
begin
  char *c;

  c :=  string;
  while *c do
  begin
    *c :=  toupper(*c);
    c++;
   end;
  return string;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_SuggestFileExt
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure MS_SuggestFileExt(char *base, char *extension);
begin
  char *search;

  search :=  base+strlen(base)-1;
  while(*search <> ASCII_SLASH) and (*search <> ASCII_BACKSLASH
   ) and (search <> base)
   begin
    if *search-- = '.' then
    begin
      exit;
     end;
   end;
  strcat(base, extension);
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_StripFileExt
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure MS_StripFileExt(char *name);
begin
  char *search;

  search :=  name+strlen(name)-1;
  while(*search <> ASCII_SLASH) and (*search <> ASCII_BACKSLASH
   ) and (search <> name)
   begin
    if *search = '.' then
    begin
      *search :=  '\0';
      exit;
     end;
    search--;
   end;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_StripFilename
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

boolean MS_StripFilename(char *name)
begin
  char *c;

  c :=  name+strlen(name);
  do
  begin
    if --c = name then
     begin  // No directory delimiter
      return NO;
     end;
   end; while(*c <> DIRECTORY_DELIMITER_CHAR);
  *c :=  0;
  return YES;
  end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
//
// MS_Message
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

procedure MS_Message(msg_t type, char *text, ...);
begin
   fp: file;
  va_list argPtr;

  if (type = MSG_VERBOSE) and (acs_VerboseMode = NO) then
  begin
    exit;
   end;
  fp :=  stdout;
  if type = MSG_DEBUG then
  begin
    if acs_DebugMode = NO then
    begin
      exit;
     end;
    if acs_DebugFile <> NULL then
    begin
      fp :=  acs_DebugFile;
     end;
   end;
  if text then
  begin
    va_start(argPtr, text);
    vfprintf(fp, text, argPtr);
    va_end(argPtr);
   end;
  end;
