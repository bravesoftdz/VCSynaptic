unit VCSynaptic.Functions;

interface

uses
  pFIBDatabase,
  Forms, Controls;

procedure ShowItemVersion(Database: TpFIBDatabase);
function SelectItemVersion(Database: TpFIBDatabase;
  const ItemName: string): Integer;

implementation

uses
  UDMItemVersion,
  UWMaster,
  UWMasterItemVersion;

procedure ShowItemVersion(Database: TpFIBDatabase);
var data: TDMItemVersion;
    form: TWMasterItemVersion;
begin
  data := TDMItemVersion.Create(nil);
  try
    data.Database := Database;
    data.Connect;
    try
      form := TWMasterItemVersion.Create(nil);
      try
        form.DataSet := data.DataSet;
        form.DataSource := data.DataSource;
        form.ShowModal;
      finally
        form.Free;
      end;
    finally
      data.Disconnect;
    end;
  finally
    data.Free;
  end;
end;

function SelectItemVersion(Database: TpFIBDatabase;
  const ItemName: string): Integer;
var data: TDMItemVersion;
    form: TWMaster;
begin
  data := TDMItemVersion.Create(nil);
  try
    data.Database := Database;
    data.SelectWhere := '(item_name=''' + ItemName + ''')';
    data.Connect;
    try
      form := TWMaster.Create(nil);
      try
        form.DataSet := data.DataSet;
        form.DataSource := data.DataSource;
        if form.ShowModal = mrOk then
          Result := data.DataSet.FieldByName('version_order').AsInteger
        else Result := 0;
      finally
        form.Free;
      end;
    finally
      data.Disconnect;
    end;
  finally
    data.Free;
  end;
end;

end.
