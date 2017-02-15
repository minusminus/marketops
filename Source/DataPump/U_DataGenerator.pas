unit U_DataGenerator;

interface

uses
  U_Consts, Classes;

type
  //data generating progress
  TOnGenerateProgress = procedure(ACurrTS : string; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean) of object;

  {
    generates data for weeks, months and intraday
  }
  TDataGenerator = class
  private
    FErrMsg: string;
    FOnGenerateFinished: TOnGenerateProgress;
    FOnGenerateProgress: TOnGenerateProgress;

    //buffer fo session table check
    FTblBuffer : TStringList;

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
    //gets next ts in specified range
    function GetNextRangeTS(AGenType : TMarketOpsDataGenType; ARange : integer; ADT : TDateTime) : TDateTime;
    //gets datatime format string for specified range
    function GetDTFormat(AGenType : TMarketOpsDataGenType) : string;

    //generation of data
    function IntGenerateData(AGenType : TMarketOpsDataGenType; ARange : integer; AStockID : integer; ADTStart, ADTEnd : TDateTime; ASrcTbl, AGenTbl : string) : boolean;
    procedure ProcessQueryBuf(AStockID : integer; ASrcTbl, AGenTbl : string; AQryBuf : TStringList);
  public
    property ErrMsg : string read FErrMsg;

    property OnGenerateProgress : TOnGenerateProgress read FOnGenerateProgress write FOnGenerateProgress;
    property OnGenerateFinished : TOnGenerateProgress read FOnGenerateFinished write FOnGenerateFinished;

    constructor Create;
    destructor Destroy; override;

    //generation session start/stop
    procedure StartSession;
    procedure StopSession;
    //generates data of specified type for selected stock
    function GenerateData(AGenType : TMarketOpsDataGenType; ARange : integer; AStockType : TMarketOpsStockType; AStockID : integer) : boolean;
  end;

implementation

uses U_DM, SysUtils, Math, DateUtils, U_Utils, U_DataGeneratorProgressCalc, DB;

{ TDataGenerator }

constructor TDataGenerator.Create;
begin
  FTblBuffer:=TStringList.Create;
  FTblBuffer.Sorted:=true;
end;

destructor TDataGenerator.Destroy;
begin
  FTblBuffer.Free;
  inherited;
end;

function TDataGenerator.CheckTableExists(ATblName: string): boolean;
const
  Q_CHK = 'select * from %s where 1=-1';
begin
  result:=(FTblBuffer.IndexOf(ATblName)>-1);  //check in buffer
  if not result then
  try
    dm.OpenQuery(dm.qryTemp, Q_CHK, [ATblName]);
    dm.qryTemp.Close;
    FTblBuffer.Add(ATblName); //add to buffer if table exists
    result:=true;
  except
    result:=false;
  end;
end;

procedure TDataGenerator.ClearErr;
begin
  FErrMsg:='';
end;

procedure TDataGenerator.StartSession;
begin
  FTblBuffer.Clear;
end;

procedure TDataGenerator.StopSession;
begin

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
  result:=IntGenerateData(AGenType, ARange, AStockID, dtstart, dtend, srctablename, gentablename);
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

function TDataGenerator.GetNextRangeTS(AGenType: TMarketOpsDataGenType;
  ARange: integer; ADT: TDateTime): TDateTime;

  //corrects floating point differences that adds resulting times like 01:59 instead of 02:00 
  function CorrectDayChange(ATS1, ATS2 : TDateTime) : TDateTime;
  var
    t1, t2 : TDateTime;
  begin
    result:=ATS2;
    t1:=floor(ATS1); t2:=floor(ATS2);
    if t2-t1>0 then result:=t2;    
  end;
begin
  case AGenType of
    mogenMinute: result:=CorrectDayChange(ADT, IncMinute(ADT, ARange));
    mogenHour: result:=CorrectDayChange(ADT, IncHour(ADT, ARange));
    mogenWeek: result:=IncWeek(ADT, ARange);
    mogenMonth: result:=IncMonth(ADT, ARange);
  end;
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

function TDataGenerator.IntGenerateData(AGenType: TMarketOpsDataGenType;
  ARange, AStockID: integer; ADTStart, ADTEnd: TDateTime; ASrcTbl,
  AGenTbl: string) : boolean;
const
  C_DATAQUERYBATCHSIZE = 20;
  Q_DATABUF = 'select ''%s'' as sdt1, ''%s'' as sdt2, count(*) as cnt, min(low) as l, max(high) as h, sum(volume) as v from %s where fk_id_spolki=%d and ts>=''%s'' and ts<''%s''';
var
  dt2 : TDateTime;
  i, cnt : integer;
  o,h,l,c : double;
  vol : integer;
  sdt1, sdt2, dtformat : string;
  pcalc : TDataGeneratorProgressCalc;
  dobreak : boolean;
  qrybuf : TStringList;
begin
  result:=false;
  dobreak:=false;
  dtformat:=GetDTFormat(AGenType);
  qrybuf:=TStringList.Create;
  pcalc:=TDataGeneratorProgressCalc.Create;
  try
    try
      pcalc.Init(ADTStart, ADTEnd);
      i:=0;
      while ADTStart<ADTEnd do
      begin
        if i and 63 = 63 then
          if assigned(FOnGenerateProgress) then FOnGenerateProgress(formatdatetime(dtformat, ADTStart), 0, false, dobreak);
        if i and 127 = 127 then
          if pcalc.Calculate(ADTStart) then
            if assigned(FOnGenerateProgress) then FOnGenerateProgress(formatdatetime(dtformat, ADTStart), pcalc.TimeRemaining, true, dobreak);
        if dobreak then break;

        dt2:=GetNextRangeTS(AGenType, ARange, ADTStart);
        sdt1:=FormatDateTime(dtformat, ADTStart);
        sdt2:=FormatDateTime(dtformat, dt2);

        qrybuf.Add( format(Q_DATABUF, [sdt1, sdt2, ASrcTbl, AStockID, sdt1, sdt2]) );
        if qrybuf.Count = C_DATAQUERYBATCHSIZE then
        begin
          ProcessQueryBuf(AStockID, ASrcTbl, AGenTbl, qrybuf);
          qrybuf.Clear;
        end;
        ADTStart:=dt2;
        inc(i);
      end;
      ProcessQueryBuf(AStockID, ASrcTbl, AGenTbl, qrybuf);
      if assigned(FOnGenerateFinished) then FOnGenerateFinished(formatdatetime(dtformat, ADTEnd), 0, false, dobreak);
      result:=true;
    except
      on e : Exception do
        FErrMsg:=format('B³¹d generowania danych [id=%d] %s:'#13#10'%s', [AStockID, formatdatetime(dtformat, ADTStart), e.Message]);
    end;
  finally
    dm.qryTemp.Close;
    pcalc.Free;
    qrybuf.Free;
  end;
end;

procedure TDataGenerator.ProcessQueryBuf(AStockID: integer; ASrcTbl,
  AGenTbl: string; AQryBuf: TStringList);
const
  C_DATAFIRST = '(%s)';
  C_DATANEXT = #13#10'union'#13#10'(%s)';
  C_DATAORDER = #13#10'order by sdt1';
  Q_OPENCLOSE = 'select T1.open, T2.close '+
                'from '+
                '(select open from %s where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts asc limit 1) T1, '+
                '(select close from %s where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts desc limit 1) T2';
  Q_INS = 'insert into %s(fk_id_spolki, ts, open, high, low, close, volume) values(%d, ''%s'', %s, %s, %s, %s, %d)';
var
  i : integer;
  qry : string;
  fsdt1, fsdt2, fcnt, fl, fh, fv : TField;
  cnt : integer;
  o,h,l,c : double;
  vol : integer;
begin
  if AQryBuf.Count=0 then exit;
  //prepare union query
  qry:=format(C_DATAFIRST, [AQryBuf[0]]);
  for i := 1 to AQryBuf.Count - 1 do
    qry:=qry + format(C_DATANEXT, [AQryBuf[i]]);
  qry:=qry + C_DATAORDER;

  dm.OpenQuery(dm.qryTemp, qry);
  dm.qryTemp.First;
  fsdt1:=dm.qryTemp.FieldByName('sdt1');
  fsdt2:=dm.qryTemp.FieldByName('sdt2');
  fcnt:=dm.qryTemp.FieldByName('cnt');
  fl:=dm.qryTemp.FieldByName('l');
  fh:=dm.qryTemp.FieldByName('h');
  fv:=dm.qryTemp.FieldByName('v');
  while not dm.qryTemp.Eof do
  begin
    cnt:=fcnt.AsInteger;
    if cnt>0 then
    begin
      l:=fl.AsFloat;
      h:=fh.AsFloat;
      vol:=fv.AsInteger;
      dm.OpenQuery(dm.qryTemp2, Q_OPENCLOSE, [ASrcTbl, AStockID, fsdt1.AsString, fsdt2.AsString, ASrcTbl, AStockID, fsdt1.AsString, fsdt2.AsString]);
      o:=dm.qryTemp2.Fields[0].AsFloat;
      c:=dm.qryTemp2.Fields[1].AsFloat;

      dm.ExecSql(Q_INS, [AGenTbl, AStockID, fsdt1.AsString,
        PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]);
    end;
    dm.qryTemp.Next;
  end;
  dm.qryTemp.Close;
  dm.qryTemp2.Close;
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

function TDataGenerator.GetDTFormat(AGenType: TMarketOpsDataGenType): string;
begin
  case AGenType of
    mogenMinute, mogenHour: result:='yyyy-mm-dd hh:nn';
    mogenWeek, mogenMonth: result:='yyyy-mm-dd';
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
