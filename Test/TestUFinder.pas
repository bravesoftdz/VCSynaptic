unit TestUFinder;

interface

uses
  UFinder,
  pFIBDatabase, pFIBQuery,
  Test.DataModule,
  TestFramework, SysUtils, Classes, Generics.Collections, Forms, Types, IOUtils;

type
  TestFinde = class(TTestCase)
  strict private
    FDataModule: TDataModuleTest;
    FFiles: TStrings;
    FFinder: TFinder;
  protected
    property DataModule: TDataModuleTest read FDataModule;
    property Files: TStrings read FFiles;
    property Finder: TFinder read FFinder;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFindRootOwner;
    procedure TestFinderFiles;
    procedure TestFinderDirectory;
  end;

implementation

uses
  VCSynaptic.Classes,
  VCSynaptic.Database,
  ULogger,
  UHash;

procedure TestFinde.SetUp;
begin
  FileLogFinder := IncludeTrailingPathDelimiter(ExtractFilePath(
      Application.ExeName)) + 'TestFinder.log';

  FDataModule := TDataModuleTest.Create(nil);
  FDataModule.Database.Connected := True;

  FFiles := TStringList.Create;
  FFinder := TFinder.Create;
end;

procedure TestFinde.TearDown;
begin
  FreeAndNil(FFinder);
  FreeAndNil(FFiles);

  FDataModule.Database.Connected := False;
  FDataModule.Free;
  FDataModule := nil;
end;

procedure TestFinde.TestFinderDirectory;
var files       : TStringDynArray;
    finderNodes : TFinderNodeList;
begin
  files := TDirectory.GetFiles('C:\VCS2\OptiFlow2\Ausreo\Release\Win32');
  Finder.Finder(DataModule.Database, DataModule.Transaction, files);

  //finderNodes := Finder.InterLeaveList['Library2'];
  //Assert(finderNodes.ToString = 'patata', finderNodes.ToString);
end;

procedure TestFinde.TestFinderFiles;
begin
  Files.Add('C:\VCS2\OptiFlow2\Ausreo\Release\Win32\OptiFlowCommon.bpl');
  Files.Add('C:\VCS2\OptiFlow2\Ausreo\Release\Win32\OptiFlowVarLog.bpl');
  Files.Add('C:\VCS2\OptiFlow2\Ausreo\Release\Win32\fbclient.dll');
  Finder.Finder(DataModule.Database, DataModule.Transaction, Files);
end;

procedure TestFinde.TestFindRootOwner;
var itemOwner: string;
begin
  itemOwner := TItemRelation.GetOwnerFromName(DataModule.Database,
      DataModule.Transaction, 'OptiFlowCommonBpl');
  Assert(SameText(itemOwner, 'OptiFlowCommon'));

  itemOwner := TItemRelation.GetRootOwnerFromName(DataModule.Database,
      DataModule.Transaction, 'OptiFlowCommonBpl');
  Assert(SameText(itemOwner, 'OptiFlowLibrary'));
end;

initialization
  RegisterTest(TestFinde.Suite);

end.

