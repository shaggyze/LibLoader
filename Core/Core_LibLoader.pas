// Utility class LibLoader
// Intended for chain-loading DLL modules
// Author: RiiStar
// 2023

unit Core_LibLoader;

interface

uses Windows, SysUtils, Classes, inifiles;

 type
   // Define the new class instance
   TLibLoader = Class

   // These variables and methods are not visible outside this class
   private

      //Variables
      Locale : TFormatSettings;
      DLLmodule  : Array[0..MAX_PATH] of Char;
      CfgFile: TIniFile;

      // Private/Internal Functions
      function    WhereIs( path: string; const filename: string ): string;
      procedure   LoadLib(dllname: PWideChar);

   // The following methods/functions/procedures and properties are all usable by instances of the class
   published

      constructor Create; // Called when creating an instance (object) from this class
      Procedure Execute;
      Procedure WriteLog(Data : string; Enabled: Boolean);
      // Functions to read ini config file types
      function ReadCFGs(Section: String; Key: String): string;
      function ReadCFGi(Section: String; Key: String): Integer;
      function ReadCFGb(Section: String; Key: String): Boolean;

   end;

   const
    MODULE_NAME     = 'Lib-Loader (Chain Loading)';
    LOG_FILENAME    = 'Loader.log';
    CONFIG_FILENAME = 'Loader.cfg';

   var
    DEBUG : Boolean = TRUE;
    Success : Boolean = FALSE;
    Files2Load, FilesLoaded : TStringList;

implementation

// Constructor : Create an instance of the class. Takes a string as argument.
// -----------------------------------------------------------------------------
constructor TLibLoader.Create();
begin
  DeleteFile(LOG_FILENAME);
  FilesLoaded := TStringList.Create();

  WriteLog(MODULE_NAME, TRUE);
  WriteLog('====================================================================================================================', TRUE);
  WriteLog('    Initializing...', TRUE);

  GetModuleFileName(hInstance, DLLmodule, Length(DLLmodule));

  CfgFile := TIniFile.Create(ExtractFilePath(DLLmodule)+CONFIG_FILENAME);

  with CfgFile do
  begin
    case CfgFile.ReadBool('Debug', 'Enabled', FALSE) of
      FALSE:
      begin
        DEBUG := FALSE;
        WriteLog('    Debug Output: FALSE', TRUE);
      end;
      TRUE:
      begin
        DEBUG := TRUE;
        WriteLog('    Debug Output: TRUE', TRUE);
      end;
    end;
  end;

  WriteLog('    [Debug] Module Name: '+ExtractFileName(DLLmodule), DEBUG);
  WriteLog('    Config File: '+ExtractFilePath(DLLmodule)+CONFIG_FILENAME, TRUE);
  CfgFile.Free;
end;

Procedure TLibLoader.WriteLog(Data : string; Enabled: Boolean);
var
   LogFile : TextFile;
   formattedDateTime : string;
begin
  IF ENABLED = TRUE THEN
  Begin
    AssignFile(LogFile, LOG_FILENAME) ;

    IF FileExists(LOG_FILENAME) <> TRUE THEN
      Rewrite(LogFile)
    ELSE
      Append(LogFile);
      GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT, Locale);
      DateTimeToString(formattedDateTime, Locale.ShortDateFormat+' hh:nnampm', now);
      WriteLn(LogFile, '['+formattedDateTime+'] '+DATA);
      CloseFile(LogFile) ;
  end;
end;

// ReadCFGb : Read Boolean (0 or 1) from config file
// ----------------------------------------------------------------------------
function TLibLoader.ReadCFGb(Section: String; Key: String): Boolean;
begin
  GetModuleFileName(hInstance, DLLmodule, Length(DLLmodule));
  CfgFile := TIniFile.Create(ExtractFilePath(DLLmodule)+CONFIG_FILENAME);

  with CfgFile do
  begin
      Result := ReadBool(Section, Key, FALSE);
  end;
  CfgFile.Free;
end;

// ReadCFGi : Read Integer (Number) from config file
// ----------------------------------------------------------------------------
function TLibLoader.ReadCFGi(Section: String; Key: String): Integer;
begin
  GetModuleFileName(hInstance, DLLmodule, Length(DLLmodule));
  CfgFile := TIniFile.Create(ExtractFilePath(DLLmodule)+CONFIG_FILENAME);

  with CfgFile do
  begin
      Result := ReadInteger(Section, Key, 0);
  end;
  CfgFile.Free;
end;

// ReadCFGs : Read String from config file
// ----------------------------------------------------------------------------
function TLibLoader.ReadCFGs(Section: String; Key: String): string;
begin
  GetModuleFileName(hInstance, DLLmodule, Length(DLLmodule));
  CfgFile := TIniFile.Create(ExtractFilePath(DLLmodule)+CONFIG_FILENAME);

  with CfgFile do
  begin
      Result := ReadString(Section, Key, '');
  end;
  CfgFile.Free;
end;

//========================================================================================================================
// Recursive file search, returning location if found.
function TLibLoader.WhereIs( path: string; const filename: string ): string;

  function IsDirectory ( const tsr: TSearchRec ): boolean;
  begin
    result := ( tsr.Attr and faDirectory ) = faDirectory;
  end;

  procedure RecursiveWhereIs ( path: string; filename: string );
  var
  tsr: TSearchRec;
  begin
    path := IncludeTrailingPathDelimiter(path);
    if FindFirst ( path + '*.*', faDirectory, tsr ) = 0 then begin
    repeat
      if AnsiCompareText ( tsr.Name, filename ) = 0 then
      result := path
      else if IsDirectory ( tsr ) and ( tsr.Name[1] <> '.' ) then
      RecursiveWhereIs ( path + tsr.Name, filename );
      if result <> '' then
    exit;
    until FindNext (tsr) <> 0;
      FindClose(tsr);
    end;
  end;

begin
  result := '';
  RecursiveWhereIs ( path, filename );
end;

//========================================================================================================================
// Load DLL libs
procedure TLibLoader.LoadLib(dllname: PWideChar);
var
  h:  HMODULE;
  Index : Integer;
  ModFile : String;
begin
  if FileExists(dllname) then
  begin
    h := LoadLibrary(dllname);
    ModFile := ExtractFileName(dllname);
    WriteLog('    -- [Debug] LoadLibrary returned: '+IntToStr(h), DEBUG);

    if h = 0 then
    begin;
      WriteLog(Format('    [Error] %s', ['LoadLib failed, unable to load '+dllname]),TRUE);
      Success := FALSE;
    end
    else
    begin
      WriteLog(Format('    [LoadLib] %s', ['Success, loaded '+dllname]),TRUE);
      Success := TRUE;

      FilesLoaded.Add(ExtractFileName(dllname));
      WriteLog('    -- [Debug] Added '+ExtractFileName(dllname)+' to Files Loaded list', DEBUG);
      WriteLog('    -- [Debug] Updated Files Loaded list: '+FilesLoaded.CommaText, DEBUG);

      Index := Files2Load.IndexOf(ModFile);
      WriteLog('    -- [Debug] Get '+ModFile+' file index in File2Load list: '+IntToStr(Index), DEBUG);

      Try
         if Index <> -1 then
         begin
           WriteLog('    -- [Debug] Removing: '+ModFile, DEBUG);
           ModFile := Files2Load.ValueFromIndex[0];
           Files2Load.Delete(Index);
           WriteLog('    -- [Debug] Amended Files2Load List: '+Files2Load.CommaText, DEBUG);
         end
         else WriteLog('    -- [Debug] Index of Files2Load was not removed...', DEBUG);

      except
        on E : Exception do
        begin
          WriteLog('[Error] '+E.ClassName+' error raised, with message : '+E.Message, TRUE);
          WriteLog('    -- [Debug] Failed? Amended Files2Load List: '+Files2Load.CommaText, DEBUG);
        end;
      End;
    end;

  end
  else
  begin
      WriteLog('    -- [Debug] File '+dllname+' not found at this location...', DEBUG);
      WriteLog(Format('    [Error] %s', ['LoadLib failed, unable to load '+dllname]),TRUE);
      Success := FALSE;
  end;

end;

Procedure TLibLoader.Execute;
var
    File2Load, ModLoaded, LoadFile, ModFile, ModFolder : String;
    ModFolders : TStringList;
    Index : Integer;
begin

    WriteLog('    Lib-Loader will recursively search for specified files in listed mod directories and sub dirs...', TRUE);

//-------------------------------------------------------------------------------------------
// Multi Mod dir

    ModFolders := TStringList.Create();
    Files2Load := TStringList.Create();

    try
      ModFolders.CommaText := ReadCFGs('Loader','ModFolders');
      WriteLog('    [Debug] '+IntToStr(ModFolders.Count)+' mod directories listed in config.', DEBUG);
      WriteLog('    [Debug] Mod directory list in CFG: '+ModFolders.CommaText, DEBUG);

      Files2Load.CommaText := ReadCFGs('Loader','Files');
      WriteLog('    [Debug] CFG -> Files2Load list: '+Files2Load.CommaText, DEBUG);

      if ModFolders.Count <> 0 then
      begin

        WriteLog('', TRUE);
        WriteLog('    Search for mods in specified directories and sub dirs', TRUE);
        WriteLog('    ----------------------------------------------------------------------------------------------------------------', TRUE);

        try

          for ModFolder in ModFolders do
          begin
            WriteLog('    [Debug] Search Folder: '+ModFolder, DEBUG);
            WriteLog('    -- Search Mod Folder: '+ModFolder, TRUE);

            for File2Load in Files2Load do
            begin

              ModFile := File2Load;

              WriteLog('    ---- [Debug] Files2Load List: '+Files2Load.CommaText, DEBUG);
              WriteLog('    [Debug] Recursively Looking for file: '+ModFile+' in '+ModFolder+' and sub dirs...', DEBUG);
              LoadFile := WhereIs(ModFolder,ModFile)+File2Load;
              WriteLog('    [Debug] WhereIs returned: '+LoadFile, DEBUG);

              if FileExists(LoadFile) then
              begin
                WriteLog(Format('    [LoadLib] %s', ['Mod file found, loading '+ModFile+' ...']),TRUE);
                LoadLib(PWideChar(LoadFile));
              end
              else WriteLog(Format('    [Error] %s', ['LoadLib failed, unable to find '+LoadFile+' !']),TRUE);

            end;

            WriteLog('    [Debug] Loaded File list: '+FilesLoaded.CommaText, DEBUG);
            WriteLog('    -- [Debug] Remaining unloaded files: '+Files2Load.CommaText, DEBUG);

          end;

        finally
          WriteLog('    [LoadLib] Recursive directory loading has completed...', TRUE);
        end;

      end
      else
      begin
        ModFolder := GetCurrentDir;
        WriteLog('    Mod Folder(s): None specified, defaulting to application/client dir.', TRUE);
      end;


    finally
      ModFolders.Free;

    end;

    WriteLog('    [Debug] Files remaining: '+IntToStr(Files2Load.Count), DEBUG);


//-------------------------------------------------------------------------------------------
// Default to application/client dir

    WriteLog('', TRUE);
    WriteLog('    Search for mods in application/client dir', TRUE);
    WriteLog('    ----------------------------------------------------------------------------------------------------------------', TRUE);

    try

      ModFolder := GetCurrentDir;

      if ModFolder <> '' then
      begin
        WriteLog('    Application/Client Folder: '+ModFolder, TRUE);
        WriteLog('    Lib-Loader will recursively search for specified files in '+ModFolder+' and sub dirs...', TRUE)
      end
      else
      begin
        WriteLog('    Mod Folder: None specified, defaulting to application/client dir.', TRUE);
        WriteLog('    Lib-Loader will recursively search for specified files in the application dir and sub dirs...', TRUE);
      end;

      WriteLog('    [Debug] Search folder: '+ModFolder, DEBUG);

      WriteLog('    [Debug] Files2Load list: '+Files2Load.CommaText, DEBUG);

      for File2Load in Files2Load do
      begin

        ModFile := File2Load;

        WriteLog('    ---- [Debug] Files2Load List: '+Files2Load.CommaText, DEBUG);
        WriteLog('    [Debug] Recursively Looking for file: '+ModFile+' in '+ModFolder+' and sub dirs...', DEBUG);
        LoadFile := WhereIs(ModFolder,ModFile)+File2Load;
        WriteLog('    [Debug] WhereIs returned: '+LoadFile, DEBUG);

        if FileExists(LoadFile) then
        begin
          WriteLog(Format('    [LoadLib] %s', ['Mod file found, loading '+ModFile+' ...']),TRUE);
          LoadLib(PWideChar(LoadFile));
        end
        else WriteLog(Format('    [Error] %s', ['LoadLib failed, unable to find '+LoadFile+' !']),TRUE);

      end;

    finally

    end;

    WriteLog('', TRUE);
    WriteLog('    ----------------------------------------------------------------------------------------------------------------', TRUE);
    WriteLog('    Loaded File list: '+FilesLoaded.CommaText, TRUE);
    WriteLog('    ('+IntToStr(Files2Load.Count)+') Remaining unloaded files: '+Files2Load.CommaText, TRUE);
    WriteLog('    Operation completed.', TRUE);

    Files2Load.Free;
    FilesLoaded.Free;

end;


//========================================================================================================================
//All code below is excuted when this module is loaded according to compile order
var
  LibLoading  : TLibLoader;

initialization

  LibLoading := TLibLoader.Create();

  LibLoading.WriteLog('', TRUE);
  LibLoading.WriteLog('Chain Loader Initializing...', TRUE);
  LibLoading.WriteLog('====================================================================================================================', TRUE);

  if LibLoading.ReadCFGb('Loader','Enabled') = TRUE and (LibLoading.ReadCFGs('Loader','Files') <> '') then
  begin
    LibLoading.WriteLog('    Executing...', TRUE);
    LibLoading.Execute;
  end
  else
  begin
    if LibLoading.ReadCFGs('Loader','Files') = '' then LibLoading.WriteLog('    [Notice] No files specified.', TRUE);
    LibLoading.WriteLog('    [Notice] LoadLib (Chain loading) skipped.', TRUE);
    LibLoading.Free;
  end;

//========================================================================================================================
//All code below is excuted when this module is unloaded according to compile order
finalization

  LibLoading.Free;

end.

