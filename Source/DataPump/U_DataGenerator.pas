unit U_DataGenerator;

interface

uses
  U_Consts;

type
  {
    generates data for weeks, months and intraday
  }
  TDataGenerator = class
  private
    FErrMsg: string;

    procedure ClearErr;
    //gets maxts for current stock from database (last inserted data)
    function GetMaxTS(AGenTableName : string; AStockID : integer) : double;
    //gets startts form current stock
    function GetStartTS(ASrcTableName : string; AStockID : integer) : double;
    //gets table name for generated data
    function GetGenerateTableName(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType) : string;
    //gets table name of source data
    function GetSourceTableName(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType) : string;
    //checks if table exists
    function CheckTableExists(ATblName : string) : boolean;
  public
    property ErrMsg : string read FErrMsg;

    //generates data of specified type for selected stock
    function GenerateData(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType; AStockID : integer) : boolean;
  end;

implementation

uses U_DM, SysUtils;

{ TDataGenerator }

function TDataGenerator.CheckTableExists(ATblName: string): boolean;
const
  Q_CHK = 'select * from %s where 1=-1';
begin
  try
    dm.OpenQuery(dm.qryTemp, Q_CHK, [ATblName]);
    dm.qryTemp.Close;
    result:=true;
  except
    result:=false;
  end;
end;

procedure TDataGenerator.ClearErr;
begin
  FErrMsg:='';
end;

function TDataGenerator.GenerateData(AGenType: TMarketOpsDataGenType; ARange : integer;
  AStockType: TMarketOpsStockType; AStockID: integer) : boolean;
var
  gentablename, srctablename : string;
  dtstart : TDateTime;
begin
  result:=false;
  ClearErr;
  gentablename:=GetGenerateTableName(AGenType, ARange, AStockType);
  srctablename:=GetSourceTableName(AGenType, ARange, AStockType);
  if not CheckTableExists(gentablename) then
  begin
    FErrMsg:=format('Brak tabeli: %s', [gentablename]);
    exit;
  end;

  //get starting ts to generate data from
  dtstart:=GetMaxTS(gentablename, AStockID);
  if dtstart=0 then
    dtstart:=GetStartTS(srctablename, AStockID);
  if dtstart=0 then
  begin
    FErrMsg:=format('Brak danych [id=%d]', [AStockID]);
    exit;
  end;
  //last data repeated (deleted and regenerated)
  
end;

function TDataGenerator.GetMaxTS(AGenTableName : string; AStockID: integer): double;
const
  Q_MAXTS = 'select max(ts) from %s where fk_id_spolki=%d';
begin
  result:=0;
  dm.OpenQuery(dm.qryTemp, Q_MAXTS, [AGenTableName, AStockID ]);
  if not dm.qryTemp.Eof then
    result:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
end;

function TDataGenerator.GetStartTS(ASrcTableName: string;
  AStockID: integer): double;
const
  Q_MINTS = 'select min(ts) from %s where fk_id_spolki=%d';
begin
  result:=0;
  dm.OpenQuery(dm.qryTemp, Q_MINTS, [ASrcTableName, AStockID ]);
  if not dm.qryTemp.Eof then
    result:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
end;

function TDataGenerator.GetSourceTableName(AGenType: TMarketOpsDataGenType;
  ARange: integer; AStockType: TMarketOpsStockType): string;
begin
  case AGenType of
    mogenMinute, mogenHour: result:=format('at_ciagle%d', [ord(AStockType)]);
    mogenWeek, mogenMonth: result:=format('at_dzienne%d', [ord(AStockType)]);
  else
    raise Exception.CreateFmt('Nieznany typ generowania danych: %d', [ord(AGenType)]);
  end;
end;

function TDataGenerator.GetGenerateTableName(AGenType: TMarketOpsDataGenType;
  ARange: integer; AStockType: TMarketOpsStockType): string;
begin
  case AGenType of
    mogenMinute: result:=format('at_intra%dm%d', [ARange, ord(AStockType)]);
    mogenHour: result:=format('at_intra%dm%d', [ARange*60, ord(AStockType)]);
    mogenWeek: result:=format('at_tyg%d', [ord(AStockType)]);
    mogenMonth: result:=format('at_mies%d', [ord(AStockType)]);
  else
    raise Exception.CreateFmt('Nieznany typ generowania danych: %d', [ord(AGenType)]);
  end;
end;

end.
