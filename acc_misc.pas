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

unit acc_misc;

interface

const
  MSG_NORMAL = 0;
  MSG_VERBOSE = 1;
  MSG_DEBUG = 2;

function MS_LoadFile(const name: string; var buffer: pointer): integer;

procedure MS_StripFileExt(var name: string);

procedure MS_Message(const typ: integer; const fmt: string; const args: array of const);

function MS_Alloc(const size: integer; const error: integer): pointer;

implementation

uses
  d_delphi,
  acc,
  acc_error,
  acc_common;

const
  ASCII_SLASH = 47;
  ASCII_BACKSLASH = 92;
  O_BINARY = 0;

function MS_Alloc(const size: integer; const error: integer): pointer;
begin
  result := malloc(size);
  if result = nil then
    ERR_Exit(error, false, '', []);
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_LittleUWORD
//
// Converts a host U_WORD (2 bytes) to little endian byte order.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

function MS_LittleUWORD(const v: U_WORD): U_WORD;
begin
  if not acs_BigEndianHost then
  begin
    result := v;
    exit;
  end;
  result := (v and 255) shl 8 + (v shr 8) and 255;
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_LittleULONG
//
// Converts a host U_LONG (4 bytes) to little endian byte order.
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

function MS_LittleULONG(const v: U_LONG): U_LONG;
begin
  if not acs_BigEndianHost then
  begin
    result := v;
    exit;
   end;
  result := (v and 255) shl 24 + (((v shr 8) and 255) shl 16) + (((v shr 16) and 255) shl 8) +
    (v shr 24) and 255;
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_LoadFile
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

function MS_LoadFile(const name: string; var buffer: pointer): integer;
var
  handle: file;
  size, cnt: integer;
begin
  if not fopen(handle, name, fOpenReadOnly) then
    ERR_Exit(ERR_CANT_OPEN_FILE, false, 'File: ''%s''.', [name]);

  size := filesize(handle);
  buffer := malloc(size);
  if buffer = nil then
    ERR_Exit(ERR_NONE, false, 'Couldn''t malloc %d bytes for file ''%s''.', [size, name]);

  BlockRead(handle, buffer, size, cnt);
  close(handle);
  if cnt < size then
    ERR_Exit(ERR_CANT_READ_FILE, false, 'File: ''%s''.', [name]);

  result := size;
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_SaveFile
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

function MS_SaveFile(const name: string; const buffer: pointer; const len: integer): boolean;
var
  handle: file;
begin
  if not fopen(handle, name, fCreate) then
  begin
    result := false;
    exit;
  end;

  result := fwrite(buffer, len, 1, handle);
  close(handle);
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_SuggestFileExt
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

procedure MS_SuggestFileExt(var base: string; const extension: string);
begin
  base := fname(base) + '.' + extension;
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_StripFileExt
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

procedure MS_StripFileExt(var name: string);
var
  i: integer;
begin
  for i := Length(name) downto 1 do
  begin
    if name[i] = '.' then
      SetLength(name, i - 1)
    else if name[i] in ['\', '/'] then
      break;
  end;
end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
//
// MS_Message
//
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

procedure MS_Message(const typ: integer; const fmt: string; const args: array of const);
begin
  if typ = MSG_VERBOSE then
    if not acs_VerboseMode then
      exit;

  if typ = MSG_DEBUG then
    if not acs_DebugMode then
      exit;

  printf(fmt, args);
end;

end.
