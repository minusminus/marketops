unit U_DM;

interface

uses
  SysUtils, Classes, DB, ADODB;

type
  TDM = class(TDataModule)
    DB: TADOConnection;
    qryTemp: TADOQuery;
    qryTemp2: TADOQuery;
    qrySpolki: TADOQuery;
    qryTemp3: TADOQuery;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FSettings : TStringList;

    procedure LoadSettings;
    function GetSettings(AName: string): string;
  public
    function ExecSql( const ASql : string ) : integer; overload;
    function ExecSql( const ASql : string; const Args : array of const ) : integer; overload;
    procedure OpenQuery( const AQry : TADOQuery; const ASql : string ); overload;
    procedure OpenQuery( const AQry : TADOQuery; const ASql : string; const Args : array of const); overload;
    procedure RefreshQuery( const AQry : TADOQuery );
    function GetNewQuery : TADOQuery;

    property Settings[AName : string] : string read GetSettings;
  end;

var
  DM: TDM;

implementation

{$R *.dfm}

uses
  inifiles, Dialogs, Forms;

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  FSettings:=TStringList.Create;
  LoadSettings;

  DB.ConnectionString:=FSettings.Values['DBConn'];
  try
    DB.Open;
  except
    on e : Exception do MessageDlg('Blad polaczenia z baza:'+#13#10+e.Message, mtError, [mbOK], 0);
  end;

  if not DB.Connected then Application.Terminate;
end;

procedure TDM.DataModuleDestroy(Sender: TObject);
var
  i : integer;
begin
  FSettings.Free;
  for i:=0 to db.DataSetCount-1 do db.DataSets[i].Close;
  DB.Close;
end;

procedure TDM.LoadSettings;
var
  ini : TIniFile;
begin
  ini:=TIniFile.Create(ExtractFilePath(ParamStr(0))+'AT.ini');
  try
    ini.ReadSectionValues('Config', FSettings);
  finally
    ini.Free;
  end;
end;

function TDM.ExecSql(const ASql: string): integer;
begin
  result:=0;
  DB.Execute(ASql, result);
end;

function TDM.ExecSql(const ASql: string; const Args: array of const): integer;
begin
  result:=ExecSql(format(ASql, Args));
end;

procedure TDM.OpenQuery(const AQry: TADOQuery; const ASql: string);
begin
  AQry.Close;
  AQry.SQL.Text:=ASql;
  AQry.Open;
end;

procedure TDM.OpenQuery(const AQry: TADOQuery; const ASql: string;
  const Args: array of const);
begin
  OpenQuery(AQry, format(ASql, Args));
end;

procedure TDM.RefreshQuery(const AQry: TADOQuery);
begin
  AQry.Close;
  AQry.Open;
end;

function TDM.GetNewQuery: TADOQuery;
begin
  result:=TADOQuery.Create(nil);
  result.Connection:=DB;
  result.LockType:=ltReadOnly;
end;

function TDM.GetSettings(AName: string): string;
begin
  result:=FSettings.Values[AName];
end;

end.
