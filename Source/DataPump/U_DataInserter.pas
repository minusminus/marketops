unit U_DataInserter;

interface

uses
  U_Consts;

type
  //data inserting progress
  TOnInsertProgress = procedure(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALinesPerSec : double; ALongEvent : boolean; var VDoBreak : boolean) of object;

  {
    imports data from files to database
  }
  TDataInserter = class
  private
    FErrMsg: string;
    f : TextFile; //shared data file
    FOnInsertProgress: TOnInsertProgress;
    FOnInsertFinished: TOnInsertProgress;

    function PrepareIntVal( val : string ) : string;
    function PrepareFloatVal( val : double ) : string;

    procedure ClearErr;
    //gets maxts for current stock from database (last inserted data)
    function GetMaxTS(ADataType : TMarketOpsDataType; AStockType : TMarketOpsStockType; AStockID : integer) : double;
    //finds specified ts in current file, if found returns specified line and sets file to next line
    function FindTSInFile(ADataType : TMarketOpsDataType; AMaxTS : double; var VLineToUpdate : boolean; var VLastLine, VRefCourse : string; var VBRead, VLinesRead : integer) : boolean;
    //inserts data do database
    procedure ProcessLine(ADataType : TMarketOpsDataType; AStockType : TMarketOpsStockType; AStockID : integer; ALine : string; var VRefCourse : string; ADoUpdate : boolean);
  public
    property ErrMsg : string read FErrMsg;

    property OnInsertProgress : TOnInsertProgress read FOnInsertProgress write FOnInsertProgress;
    property OnInsertFinished : TOnInsertProgress read FOnInsertFinished write FOnInsertFinished;

    //inserts data from spcified file for specified stock
    function InsertData(ADataType : TMarketOpsDataType; AStockType : TMarketOpsStockType; AStockID : integer; ASrcFN : string) : boolean;

    //updates startts for all stocks
    procedure UpdateAllStartTS;
  end;

implementation

uses U_DM, SysUtils, rxfileutil, Classes, rxstrutils;

{ TDataInserter }

procedure TDataInserter.ClearErr;
begin
  FErrMsg:='';
end;

function TDataInserter.FindTSInFile(ADataType: TMarketOpsDataType;
  AMaxTS: double; var VLineToUpdate : boolean; var VLastLine, VRefCourse: string; var VBRead, VLinesRead : integer): boolean;
var
  dts : string;
  sl : TStringList;
  firstlineread : boolean;
begin
  result:=false;
  if AMaxTS<=0 then exit;
  case ADataType of
    modataTicks : dts:=FormatDateTime('yyyymmdd,hhnnss', AMaxTS);
    modataDaily : dts:=FormatDateTime('yyyymmdd', AMaxTS);
  end;
  sl:=TStringList.Create;
  try
    firstlineread:=false;
    while not Eof(f) do
    begin
      readln(f, VLastLine);
      VBRead:=VBRead + length(VLastLine);
      if VLastLine[1]='<' then  //mst maja naglowek <>,<>,<> prn nie maja
      begin
        inc(VLinesRead);
        Continue;
      end;
      firstlineread:=true;
      sl.CommaText:=VLastLine;
      if (ADataType=modataDaily) then //inicjalizacja kursu odniesienia
      begin
        if firstlineread then VRefCourse:=sl[2]  //otwarcie pierwszego dnia notowan
        else VRefCourse:=sl[5]; //zamkniecie biezacego
      end;
      inc(VLinesRead);
      if pos(dts, VLastLine)>0 then //identyczna data znaleziona
      begin
//        VLineToUpdate:=(ADataType=modataDaily);
        VLineToUpdate:=false;
        result:=true;
        break;
      end;
//      if( (ADataType=modataDaily) and (sl[1]=dts) ) then  //jezeli data identyczna - aktualizujemy biezacy rekord i przetwarzamy kolejne linie
//      begin
//        VLineToUpdate:=true;
//        result:=true;
//        break;
//      end;
      if ( (ADataType=modataTicks) and ((sl[2]+','+sl[3]) > dts) ) or
         ( (ADataType=modataDaily) and (sl[1] > dts) ) then  //data znaleziona jest wieksza od maxts -> dodajemy nowa linie i reszte pliku
      begin
        VLineToUpdate:=false;
        result:=true;
        break;
      end;
    end;
  finally
    sl.Free;
  end;
end;

function TDataInserter.GetMaxTS(ADataType: TMarketOpsDataType;
  AStockType: TMarketOpsStockType; AStockID: integer): double;
const
  Q_MAXTS = 'select max(ts) from at_%s%d where fk_id_spolki=%d';
begin
  case ADataType of
    modataTicks : dm.OpenQuery(dm.qryTemp, Q_MAXTS,['ciagle', Ord(AStockType), AStockID ]);
    modataDaily : dm.OpenQuery(dm.qryTemp, Q_MAXTS,['dzienne', Ord(AStockType), AStockID ]);
  end;
  result:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
end;

function TDataInserter.InsertData(ADataType: TMarketOpsDataType;
  AStockType: TMarketOpsStockType; AStockID: integer; ASrcFN: string): boolean;
var
  fsize : integer;
  maxts : double;
  linetoupdate : boolean;
  lastline, refcourse : string;
  bytesread, linesread : integer;
  tlast, tcurr : double;
  ilast, ilastline : integer;
  timexepectedtofinish, linespersec : double;
  dobreak : boolean;
begin
  ClearErr;
  result:=false;
  if not FileExists(ASrcFN) then
  begin
    FErrMsg:=format('Brak pliku [%s]', [ASrcFN]);
    exit;
  end;
  fsize:=GetFileSize(ASrcFN);

  maxts:=GetMaxTS(ADataType, AStockType, AStockID);
  AssignFile(f, ASrcFN);
  try
    try
      Reset(f);

      if not FindTSInFile(ADataType, maxts, linetoupdate, lastline, refcourse, bytesread, linesread) then exit;
      if linetoupdate then
        ProcessLine(ADataType, AStockType, AStockID, lastline, refcourse, true);

      tlast:=now; ilast:=bytesread; ilastline:=linesread;
      while not EOF(f) do
      begin
        //progress events
        if linesread and $F = $F then
          if assigned(FOnInsertProgress) then FOnInsertProgress(linesread, 0, 0, false, dobreak);
        if linesread and 127 = 127 then
        begin
          tcurr:=now;
          if bytesread>ilast then
          begin
            timexepectedtofinish:=(fsize-bytesread)*(tcurr-tlast)/(bytesread-ilast);
            linespersec:=(linesread-ilastline)/((tcurr-tlast)/(1.0/24.0/60.0/60.0));
            if assigned(FOnInsertProgress) then FOnInsertProgress(linesread, timexepectedtofinish, linespersec, true, dobreak);
          end;
        end;
        if dobreak then break;
        //reading data
        Readln(f, lastline);
        bytesread:=bytesread + length(lastline);
        inc(linesread);
        ProcessLine(ADataType, AStockType, AStockID, lastline, refcourse, false);
      end;
      if assigned(FOnInsertFinished) then FOnInsertFinished(linesread, 0, 0, false, dobreak);
      result:=true;
    except
      on e : Exception do
        FErrMsg:=format('B³¹d przetwarzania pliku [%s] linia %d'#13#10'%s', [extractfilename(ASrcFN), linesread, e.Message]);
    end;
  finally
    CloseFile(f);
  end;
end;

function TDataInserter.PrepareFloatVal(val: double): string;
begin
  result:=replacestr(format('%.2f',[val]), ',', '.');
end;

function TDataInserter.PrepareIntVal(val: string): string;
begin
  result:=val;
  if trim(val)='' then result:='0';
end;

procedure TDataInserter.ProcessLine(ADataType: TMarketOpsDataType;
  AStockType: TMarketOpsStockType; AStockID: integer; ALine : string; var VRefCourse: string;
  ADoUpdate: boolean);
const
  Q_ADDCIAGLE = 'insert into at_ciagle%d(fk_id_spolki, ts, x, open, high, low, close, volume, oi) values(%d, ''%s'', %s, %s,%s,%s,%s, %s, %s);';
  Q_ADDDZIENNE = 'insert into at_dzienne%d(fk_id_spolki, ts, open, high, low, close, volume, refcourse) values(%d, ''%s'', %s,%s,%s,%s, %s, %s );';
  Q_UPDATEDZIENNE = 'update at_dzienne%d set open=%s, high=%s, low=%s, close=%s, volume=%s where fk_id_spolki=%d and ts=''%s''';
var
  sl : TStringList;
  s, dts : string;
  qry : string;
begin
  if VRefCourse='' then VRefCourse:='0';
  sl:=TStringList.Create;
  try
    sl.CommaText:=ALine;
    case ADataType of
      modataTicks: s:=sl[2];
      modataDaily: s:=sl[1];
    end;
    dts:=s[1]+s[2]+s[3]+s[4]+'-'+s[5]+s[6]+'-'+s[7]+s[8];
    if ADataType=modataTicks then //godzina tylko dla ciaglych
    begin
      s:=sl[3];
      dts:=dts+' '+s[1]+s[2]+':'+s[3]+s[4]+':'+s[5]+s[6];
    end;

    case ADataType of
      modataTicks:
        qry:=format(Q_ADDCIAGLE,[
          Ord(AStockType),
          AStockID,
          dts, sl[1],
          sl[4], sl[5], sl[6], sl[7],
          sl[8], sl[9]
        ]);
      modataDaily:
        if ADoUpdate then
          qry:=format(Q_UPDATEDZIENNE,[
            Ord(AStockType),
            sl[2], sl[3], sl[4], sl[5],
            PrepareIntVal(sl[6]),
            dm.qrySpolki.fieldbyname('id').AsInteger,
            dts
          ])
        else
          qry:=format(Q_ADDDZIENNE,[
            Ord(AStockType),
            AStockID,
            dts,
            sl[2], sl[3], sl[4], sl[5],
            PrepareIntVal(sl[6]), VRefCourse
          ]);
    end;
    dm.ExecSql(qry);
    if (ADataType=modataDaily) then
      VRefCourse:=sl[5];
  finally
    sl.Free;
  end;  
end;

procedure TDataInserter.UpdateAllStartTS;
const
  Q_QRY ='update at_spolki '+
          'set startts=t.ts '+
          'from '+
          '( '+
          'select fk_id_spolki, min(ts) as "ts" '+
          'from at_dzienne%d '+
          'where fk_id_spolki in (select id from at_spolki where startts is null) '+
          'group by fk_id_spolki '+
          ') t '+
          'where id=t.fk_id_spolki';
var
  i : integer;
begin
//  for i := Ord(low(TMarketOpsStockType)) to Ord(high(TMarketOpsStockType)) do
//    dm.ExecSql(Q_QRY, [i]);

  dm.ExecSql(Q_QRY, [0]);
  dm.ExecSql(Q_QRY, [1]);
  dm.ExecSql(Q_QRY, [2]);
  dm.ExecSql(Q_QRY, [4]);
  dm.ExecSql(Q_QRY, [5]);
  dm.ExecSql(Q_QRY, [6]);
end;

end.
