unit U_SeriesInfo;

interface

uses
  Classes, U_Consts;

type
  TSeriesData = class
  public
    series : string;
    expiration : tdatetime;
  end;

  {
    futures series information
  }
  TSeriesInfo = class
  private
    FSeries : TList;
    FErrMsg: string;
    FCurrentMaxTS: TDateTime;

    procedure Clear;
    function GetSeries(Index: integer): TSeriesData;
    function GetCount: integer;
  public
    property ErrMsg : string read FErrMsg;
    property Count : integer read GetCount;
    property Series[Index : integer] : TSeriesData read GetSeries; default;
    property CurrentMaxTS : TDateTime read FCurrentMaxTS;

    constructor Create;
    destructor Destroy; override;

    //gets series info to update data to current date
    function GetSeriesForCurrentDownload(AStockID : integer; AStockType : TMarketOpsStockType) : boolean;
  end;

implementation

uses U_DM, SysUtils;

{ TSeriesInfo }

constructor TSeriesInfo.Create;
begin
  FSeries:=TList.Create;
end;

destructor TSeriesInfo.Destroy;
begin
  Clear;
  FSeries.Free;
  inherited;
end;

function TSeriesInfo.GetCount: integer;
begin
  result:=FSeries.Count;
end;

function TSeriesInfo.GetSeries(Index: integer): TSeriesData;
begin
  result:=TSeriesData(FSeries[Index]);
end;

procedure TSeriesInfo.Clear;
var
  i : integer;
begin
  for i := 0 to FSeries.Count - 1 do
    TSeriesData(FSeries[i]).Free;
  FSeries.Clear;
end;

function TSeriesInfo.GetSeriesForCurrentDownload(AStockID: integer; AStockType : TMarketOpsStockType) : boolean;
const
  Q_MAXTS = 'select max(ts) from at_ciagle%d where fk_id_spolki=%d';
  Q_FIRSTBIEZACA = 'select min(biezaca) from at_serie where fk_id_spolki=%d';
  Q_GETDATA =
    'select * '+
    'from at_serie '+
    'where fk_id_spolki=%d '+
    'and biezaca<date ''%s'' '+
    'and stop>date ''%s'' '+
    'order by stop';
var
  lastts : TDateTime;
  o : TSeriesData;
begin
  Clear;
  FErrMsg:='';
  result:=false;

  lastts:=now;
  FCurrentMaxTS:=0;
  dm.OpenQuery(dm.qryTemp2, Q_MAXTS, [Ord(AStockType), AStockID]);
  if dm.qryTemp2.Eof then
  begin
    dm.OpenQuery(dm.qryTemp2, Q_FIRSTBIEZACA, [AStockID]);
    if dm.qryTemp2.Eof then
    begin
      FErrMsg:=format('Brak definicji serii [id=%d]', [AStockID]);
      exit;
    end;
  end;
  FCurrentMaxTS:=dm.qryTemp2.Fields[0].AsDateTime;

  dm.OpenQuery(dm.qryTemp2, Q_GETDATA, [AStockID, formatdatetime('yyyy-mm-dd', lastts), formatdatetime('yyyy-mm-dd', FCurrentMaxTS)]);
  if dm.qryTemp2.Eof then
  begin
    FErrMsg:=format('Brak definicji serii (biezaca<%s and stop>%s) [id=%d]', [formatdatetime('yyyy-mm-dd', lastts), formatdatetime('yyyy-mm-dd', FCurrentMaxTS), AStockID]);
    exit;
  end;
  dm.qryTemp2.First;
  while not dm.qryTemp2.Eof do
  begin
    o:=TSeriesData.Create;
    o.series:=dm.qryTemp2.FieldByName('nazwa').AsString;
    o.expiration:=dm.qryTemp2.FieldByName('stop').AsDateTime;
    FSeries.Add(o);
    dm.qryTemp2.Next;
  end;
  dm.qryTemp2.Close;

  if FSeries.Count>0 then
    if GetSeries(FSeries.Count-1).expiration<lastts then
    begin
      FErrMsg:=format('Ostatnia zdefiniowana seria wygasa %s [id=%d]', [formatdatetime('yyyy-mm-dd', GetSeries(FSeries.Count-1).expiration), AStockID]);
      exit;
    end;

  result:=true;
end;

end.
