unit VCSynaptic.Database;

interface

uses
  VCSynaptic.Classes,
  pFIBDatabase, pFIBQuery,
  SysUtils, Classes, Variants;

type
  TVCSynapticDatabase = class
  private
    class function GetDatabaseName: string; static;
    class function GetUserName: string; static;
    class function GetPassword: string; static;
    class function GetUserRole: string; static;
  public
    //class procedure CreateDatabase(const DBName: string);
    //class procedure InitDatabase(AInstance: LongWord; const DBName: string);
    //class procedure PatchDatabase(Database: TpFIBDataBase;
    //  Transaction: TpFIBTransaction; const DBName: string);
    //class procedure DeleteRelations(ADatabase: TpFIBDataBase;
    //  ATransaction: TpFIBTransaction);
    //class procedure InitGenerator(ADatabase: TpFIBDataBase;
    //  ATransaction: TpFIBTransaction; const AGeneratorName: string);
    //class procedure InitGenerators(ADatabase: TpFIBDataBase;
    //  ATransaction: TpFIBTransaction);
    class property DatabaseName: string read GetDatabaseName;
    class property UserName: string read GetUserName;
    class property Password: string read GetPassword;
    class property UserRole: string read GetUserRole;
  end;

  TDatabaseRelation = class
  public
    class function ReadItemVersion(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; Items: TItemList; const ItemName: string;
      VersionOrder: Integer): TItem;
    class procedure ReadItemChildren(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; Items: TItemList; Item: TItem);
  end;

  TItemRelation = class
  public
    class procedure Get(Query: TpFIBQuery; Item: TItem);
    class function CreateItem(Query: TpFIBQuery; AOwner: TComponent): TItem;
    class function ReadItem(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; Owner: TComponent;
      const ItemName: string): TItem;
    class procedure SelectAllType(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; Items: TItemList; ItemType: TItemType);
  end;

  TItemVersionRelation = class
  private
    class var FSQLInsert: string;
  protected
    class function GetSQLInsert(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction): string;
  public
    class procedure Get(Query: TpFIBQuery; ItemVersion: TItemVersion);
    class function GetNextOrder(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; const ItemName: string): Integer;
    class function ReadItemVersion(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; ItemVersion: TItemVersion;
      const ItemName: string; VersionOrder: Integer): Boolean;
    class function InsertItemVersion(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; const ItemName: string; VersionOrder,
      VersionNumber, VersionDate, VersionHash: Variant): Integer;
  end;

  TItemLinkRelation = class
  public
    class procedure DuplicateVersion(Database: TpFIBDatabase;
      Transaction: TpFIBTransaction; const ItemName: string; OldVersionOrder,
      NewVersionOrder: Integer);
  end;

implementation

uses
  FIBUtils.Interf;

{ TVCSynapticDatabase }

class function TVCSynapticDatabase.GetDatabaseName: string;
begin
  Result := 'VCSYNAPTIC.FDB';
end;

class function TVCSynapticDatabase.GetPassword: string;
begin
  Result := 'masterkey';
end;

class function TVCSynapticDatabase.GetUserName: string;
begin
  Result := 'SYSDBA';
end;

class function TVCSynapticDatabase.GetUserRole: string;
begin
  Result := '';
end;

{ TDatabaseRelation }

class procedure TDatabaseRelation.ReadItemChildren(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; Items: TItemList; Item: TItem);
var query       : TpFIBQuery;
    fCommit     : Boolean;
    child       : TItem;
    itemName    : string;
    versionOrder: Integer;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text :=
        'select * from item_link where ' +
        ' (owner_item_name=:owner_item_name) and ' +
        ' (owner_version_order=:owner_version_order)';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('owner_item_name').AsString := Item.Name;
      query.ParamByName('owner_version_order').AsInteger := Item.Version.Order;
      query.ExecQuery;
      while not query.Eof do
      begin
        itemName := query.FieldByName('child_item_name').AsString;
        versionOrder := query.FieldByName('child_version_order').AsInteger;
        child := Items.FindItemVersion(itemName, versionOrder);
        if child = nil then
          child := TDatabaseRelation.ReadItemVersion(Database, Transaction,
              Items, itemName, versionOrder);
        Item.InsertChild(child);
        child.InsertReference(Item);
        ReadItemChildren(Database, Transaction, Items, child);
        query.Next;
      end;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

class function TDatabaseRelation.ReadItemVersion(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; Items: TItemList; const ItemName: string;
  VersionOrder: Integer): TItem;
var query   : TpFIBQuery;
    fCommit : Boolean;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text :=
        'select * ' +
        'from item_version itv ' +
        'join item it on it.name=itv.item_name ' +
        'where ' +
        ' (itv.item_name=:item_name) and (itv.version_order=:version_order)';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('item_name').AsString := ItemName;
      query.ParamByName('version_order').AsInteger := VersionOrder;
      query.ExecQuery;
      if not query.Eof then
      begin
        Result := TItemRelation.CreateItem(query, nil);
        if Result <> nil then
        begin
          TItemRelation.Get(query, Result);
          TItemVersionRelation.Get(query, Result.Version);
        end;
      end
      else Result := nil;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

{ TItemRelation }

class function TItemRelation.CreateItem(Query: TpFIBQuery;
  AOwner: TComponent): TItem;
var itemType: TItemType;
begin
  itemType := StrToItemType(Query.FieldByName('item_type').AsString);
  Result := TItemFactory.CreateItem(AOwner, itemType);
end;

class procedure TItemRelation.Get(Query: TpFIBQuery; Item: TItem);
begin
  with Query do
  begin
    Item.Name := FieldByName('name').AsString;
    Item.Alias := FieldByName('alias').AsString;
    Item.RelativePath := FieldByName('path').AsString;
  end;
end;

class function TItemRelation.ReadItem(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; Owner: TComponent;
  const ItemName: string): TItem;
var query   : TpFIBQuery;
    fCommit : Boolean;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text := 'select * from item where (name=:name)';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('name').AsString := ItemName;
      query.ExecQuery;
      if not query.Eof then
      begin
        Result := CreateItem(query, Owner);
        if Result <> nil then
          Get(query, Result);
      end
      else Result := nil;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

class procedure TItemRelation.SelectAllType(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; Items: TItemList; ItemType: TItemType);
var query   : TpFIBQuery;
    fCommit : Boolean;
    item    : TItem;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text :=
        'select * from item where upper(item_type) = upper(:item_type)';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('item_type').AsString := ItemTypeToStr(ItemType);
      query.ExecQuery;
      while not query.Eof do
      begin
        item := CreateItem(query, nil);
        Items.Add(item);
        Get(query, item);
        query.Next;
      end;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

{ TItemVersionRelation }

class procedure TItemVersionRelation.Get(Query: TpFIBQuery;
  ItemVersion: TItemVersion);
begin
  with ItemVersion, Query do
  begin
    Order := FieldByName('version_order').AsInteger;
    Number := FieldByName('version_number').AsString;
    Date := FieldByName('version_date').AsDate;
    Hash := FieldByName('version_hash').AsString;
  end;
end;

class function TItemVersionRelation.GetNextOrder(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; const ItemName: string): Integer;
var query   : TpFIBQuery;
    fCommit : Boolean;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text :=
        'select max(version_order) version_order ' +
        'from item_version ' +
        'where item_name=:item_name';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('item_name').AsString := ItemName;
      query.ExecQuery;
      if not query.Eof then
        Result := query.FieldByName('version_order').AsInteger + 1
      else Result := 1;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

class function TItemVersionRelation.GetSQLInsert(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction): string;
begin
  if Length(FSQLInsert) = 0 then
    FSQLInsert := GetSQLInsertFromRelation(Database, Transaction,
        'ITEM_VERSION', 'VERSION_ORDER');
  Result := FSQLInsert;
end;

class function TItemVersionRelation.InsertItemVersion(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; const ItemName: string; VersionOrder,
  VersionNumber, VersionDate, VersionHash: Variant): Integer;
var query   : TpFIBQuery;
    fCommit : Boolean;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.SQL.Text := GetSQLInsert(Database, Transaction);
      query.ParamByName('item_name').AsString := ItemName;
      if not VarIsNull(VersionOrder) then
        query.ParamByName('version_order').AsInteger := VersionOrder;
      if not VarIsNull(VersionNumber) then
        query.ParamByName('version_number').AsString := VersionNumber;
      if not VarIsNull(VersionDate) then
        query.ParamByName('version_date').AsDate := VersionDate
      else query.ParamByName('version_date').AsDate := Date;
      if not VarIsNull(VersionHash) then
        query.ParamByName('version_hash').AsString := VersionHash;
      query.ExecQuery;
      Result := query.FieldByName('version_order').AsInteger;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

class function TItemVersionRelation.ReadItemVersion(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; ItemVersion: TItemVersion;
  const ItemName: string; VersionOrder: Integer): Boolean;
var query   : TpFIBQuery;
    fCommit : Boolean;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text :=
        'select * from item_version ' +
        'where (item_name=:item_name= and (version_order=:version_order)';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('item_name').AsString := ItemName;
      query.ParamByName('version_order').AsInteger := VersionOrder;
      query.ExecQuery;
      if not query.Eof then
      begin
        Get(query, ItemVersion);
        Result := True;
      end
      else Result := False;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

{ TItemLinkRelation }

class procedure TItemLinkRelation.DuplicateVersion(Database: TpFIBDatabase;
  Transaction: TpFIBTransaction; const ItemName: string; OldVersionOrder,
  NewVersionOrder: Integer);
var query   : TpFIBQuery;
    fCommit : Boolean;
begin
  query := TpFIBQuery.Create(nil);
  try
    query.Database := Database;
    query.Transaction := Transaction;
    query.SQL.Text :=
        'insert into item_link (owner_item_name, owner_version_order, ' +
        ' child_item_name, child_version_order) ' +
        'select owner_item_name, :new_owner_version_order, ' +
        ' child_item_name, child_version_order ' +
        'from item_link ' +
        'where ' +
        '	(owner_item_name like :owner_item_name) and ' +
        '	(owner_version_order=:old_owner_version_order)';

    fCommit := not Transaction.InTransaction;
    try
      if fCommit then Transaction.StartTransaction;
      query.ParamByName('owner_item_name').AsString := ItemName;
      query.ParamByName('new_owner_version_order').AsInteger := NewVersionOrder;
      query.ParamByName('old_owner_version_order').AsInteger := OldVersionOrder;
      query.ExecQuery;
      query.Close;
      if fCommit then Transaction.Commit;
    except
      if fCommit and Transaction.InTransaction then
        Transaction.Rollback;
    end;
  finally
    query.Free;
  end;
end;

end.
