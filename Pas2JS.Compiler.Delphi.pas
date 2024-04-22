﻿unit Pas2JS.Compiler.Delphi;

{$SCOPEDENUMS ON}

interface

uses System.Classes, System.SysUtils, Pas2JSFScompiler, Pas2JSLogger, Pas2JSCompiler, FPPJsSrcMap;

type
  TCompilerMessage = class;

  TPas2JSCompilerDelphi = class(TPas2JSFSCompiler)
  private
    FOnCompilerMessage: TProc<TCompilerMessage>;
    FOnReadFile: TProc<String>;
    FSearchPath: String;
    FDefines: String;
    FOutputPath: String;
    FOnAddUnit: TProc<String>;

    function LoadFile(FileName: String; var Source: String): Boolean;

    procedure CompilerLog(Sender: TObject; const Info: String);
  protected
    function DoWriteJSFile(const DestFilename, MapFilename: String; Writer: TPas2JSMapper): Boolean; override;
  public
    procedure AddUsedUnit(AFile: TPas2jsCompilerFile); override;
    procedure Run(const FileName: String);

    property Defines: String read FDefines write FDefines;
    property OnCompilerMessage: TProc<TCompilerMessage> read FOnCompilerMessage write FOnCompilerMessage;
    property OnAddUnit: TProc<String> read FOnAddUnit write FOnAddUnit;
    property OnReadFile: TProc<String> read FOnReadFile write FOnReadFile;
    property OutputPath: String read FOutputPath write FOutputPath;
    property SearchPath: String read FSearchPath write FSearchPath;
  end;

  TCompilerMessage = class
  private
    FCol: Integer;
    FFileName: String;
    FLine: Integer;
    FMessage: String;
    FNumber: Integer;
    FType: String;
  public
    property Col: Integer read FCol write FCol;
    property FileName: String read FFileName write FFileName;
    property Line: Integer read FLine write FLine;
    property Message: String read FMessage write FMessage;
    property Number: Integer read FNumber write FNumber;
    property &Type: String read FType write FType;
  end;

implementation

uses System.IOUtils, Rest.JSON, PasUseAnalyzer, FPPas2Js, Pas2JS.Compiler.Options.Form;

{ TPas2JSCompilerDelphi }

procedure TPas2JSCompilerDelphi.AddUsedUnit(AFile: TPas2jsCompilerFile);
begin
  inherited;

  if Assigned(OnAddUnit) then
    OnAddUnit(AFile.PasUnitName);
end;

procedure TPas2JSCompilerDelphi.CompilerLog(Sender: TObject; const Info: String);
begin
  if Assigned(OnCompilerMessage) then
  begin
    var CompilerMessage := TJson.JsonToObject<TCompilerMessage>(Info);

    case CompilerMessage.Number of
      nPAUnitNotUsed: ;

      nPAParameterInOverrideNotUsed: ;
      else
      begin
        if CompilerMessage.Number > 0 then
          CompilerMessage.Message := Format('Code: %d %s %s', [CompilerMessage.Number, CompilerMessage.Message, CompilerMessage.FileName]);

        FOnCompilerMessage(CompilerMessage);
      end;
    end;

    CompilerMessage.Free;
  end;
end;

function TPas2JSCompilerDelphi.DoWriteJSFile(const DestFilename, MapFilename: String; Writer: TPas2JSMapper): Boolean;
begin
  var DestinyFile := TMemoryStream.Create;
  Result := True;

  Writer.SaveJSToStream(False, ExtractFileName(MapFilename), DestinyFile);

  DestinyFile.WriteData(#0);

  TFile.WriteAllText(DestFilename, PChar(DestinyFile.Memory), TEncoding.UTF8);

  DestinyFile.Free;
end;

function TPas2JSCompilerDelphi.LoadFile(FileName: String; var Source: String): Boolean;
begin
  Result := True;
  Source := TFile.ReadAllText(FileName);

  if Assigned(OnReadFile) then
    OnReadFile(Filename);
end;

procedure TPas2JSCompilerDelphi.Run(const FileName: String);
begin
  var CommandLine := TStringList.Create;
  var ErrorMessage := EmptyStr;
  FileCache.OnReadFile := LoadFile;
  FileCache.MainOutputPath := OutputPath;
  Log.Encoding := 'JSON';
  Log.OnLog := CompilerLog;
  MainSrcFile := FileName;
  ModeSwitches := p2jsMode_SwitchSets[p2jmDelphi];
  Options := Options + [coShowErrors, coShowWarnings, coShowHints, coShowMessageNumbers];
  ResourceMode := rmJS;
  ShowFullPaths := True;
  TargetProcessor := ProcessorECMAScript6;

  FileCache.AddUnitPaths(SearchPath, False, ErrorMessage);

  ForceDirectories(OutputPath);

  for var DefineName in Defines.Split([';']) do
    AddDefine(DefineName);

  try
    inherited Run(EmptyStr, EmptyStr, CommandLine, False);
  finally
    CommandLine.Free;
  end;
end;

end.

