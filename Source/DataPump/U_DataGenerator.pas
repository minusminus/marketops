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
    //checks if table exists
    function CheckTableExists(ATblName : string) : boolean;
    //gets maxts for current stock from database (last inserted data)
    function GetMaxTS(AGenTableName : string; AStockID : integer) : double;
    //gets startts form current stock
    function GetStartTS(ASrcTableName : string; AStockID : integer) : double;
    //gets table name for generated data
    function GetGenerateTableName(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType) : string;
    //gets table name of source data
    function GetSourceTableName(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType) : string;
    //prepares ts to start generation from
    function PrepareGenStartTS(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType; ATS : TDateTime) : TDateTime;
    function PrepareGenEndTS(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType) : TDateTime;
    //deletes data from specified table for stock from ATS
    procedure DeleteDataFromTS(ATblName : string; AStockID : integer; ATS : TDateTime);

    //generation of data
    procedure IntGenerateData(AGenType : TMarketOpsDataGenType; ARange : integer; AStockID : integer; ADTStart, ADTEnd : TDateTime; ASrcTbl, AGenTbl : string);
  public
    property ErrMsg : string read FErrMsg;

    //generates data of specified type for selected stock
    function GenerateData(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType; AStockID : integer) : boolean;
  end;

implementation

uses U_DM, SysUtils, Math, DateUtils;

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

procedure TDataGenerator.DeleteDataFromTS(ATblName: string; AStockID: integer;
  ATS: TDateTime);
const
  Q_DEL = 'delete from %s where fk_id_spolki=%d and ts>=''%s''';
begin
  dm.ExecSql(format(Q_DEL, [ATblName, AStockID, formatdatetime('yyyy-mm-dd', ATS)]));
end;

function TDataGenerator.GenerateData(AGenType: TMarketOpsDataGenType; ARange : integer;
  AStockType: TMarketOpsStockType; AStockID: integer) : boolean;
var
  gentablename, srctablename : string;
  dtstart, dtend : TDateTime;
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
  dtstart:=PrepareGenStartTS(AGenType, ARange, AStockType, dtstart);
  dtend:=PrepareGenEndTS(AGenType, ARange, AStockType);
  //last data repeated (deleted and regenerated)
  DeleteDataFromTS(gentablename, AStockID, dtstart);

  IntGenerateData(AGenType, ARange, AStockID, dtstart, dtend, srctablename, gentablename);
  result:=true;
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

procedure TDataGenerator.IntGenerateData(AGenType: TMarketOpsDataGenType;
  ARange, AStockID: integer; ADTStart, ADTEnd: TDateTime; ASrcTbl,
  AGenTbl: string);
const
  Q_DATA = 'select count(*), min(low), max(high), sum(volume) from %s where fk_id_spolki=%d and ts>=''%s'' and ts<''%s''';
  Q_OPEN = 'select * from %s where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts asc limit 1';
  Q_CLOSE = 'select * from %s where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts desc limit 1';
var
  dt2 : TDateTime;
  i, cnt : integer;
  o,h,l,c : double;
  vol : integer;
  sdt1, sdt2 : string;
begin
  i:=0;
  while ADTStart<ADTEnd do
  begin
//    dt2:=0;


    inc(i);  
  end;
end;

function TDataGenerator.PrepareGenEndTS(AGenType: TMarketOpsDataGenType;
  ARange: integer; AStockType: TMarketOpsStockType): TDateTime;
begin
  case AGenType of
    mogenMinute, mogenHour: result:=ceil(now);
    mogenWeek, mogenMonth: result:=floor(now);
  else
    raise Exception.CreateFmt('Nieznany typ generowania danych: %d', [ord(AGenType)]);
  end;
end;

function TDataGenerator.PrepareGenStartTS(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType; ATS: TDateTime): TDateTime;
begin
  case AGenType of
    mogenMinute, mogenHour: result:=floor(ATS); //beginning of a day
    mogenWeek: result:=ATS - (DayOfTheWeek(ATS) - 1); //monday
    mogenMonth: result:=ATS - DayOfTheMonth(ATS) + 1; //first day of month
  else
    raise Exception.CreateFmt('Nieznany typ generowania danych: %d', [ord(AGenType)]);
  end;
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
