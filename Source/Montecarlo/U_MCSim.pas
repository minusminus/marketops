{*
  montecarlo simulation
*}
unit U_MCSim;

interface

uses
  Graphics, Classes;

type
  TArrSingle = array of single;
  TArrArrSingle = array of TArrSingle;

  TMCSim = class
  private
    FSeries: TArrArrSingle;
    FAvgSerie: TArrSingle;
    FSimCount: integer;
    FSimLen: integer;
    FStats: TStringList;

    procedure Clear;
    procedure CreateSeries(ASimLen, ASimCnt : integer);
    procedure GenerateSeries(WRatio: Single; WLRatio: Single);
    procedure CalculateAvgSerie;
  public
    property SimCount : integer read FSimCount;
    property SimLen : integer read FSimLen;
    //all series
    property Series : TArrArrSingle read FSeries;
    //avg seriee from all series
    property AvgSerie : TArrSingle read FAvgSerie;
    //calculated stats
    property Stats : TStringList read FStats;

    constructor Create;
    destructor Destroy; override;

    //simulation - create series, and generate data
    //WRatio - prawdopodobienstwo wygranej (win ratio, win probability)
    //WLRAtio - stosunek wygranych do przegranch (win/loss ratio)
    procedure Simulate( WRatio, WLRatio : single; ASimLen, ASimCnt : integer );

    //draw simulated series on bitmap
    procedure DrawSeries( bmp : TBitmap );

    //stats for simulated series
    procedure CalculateStats;
  end;

implementation

uses cRandom, Forms, Types, SysUtils;

{ TMCSim }

constructor TMCSim.Create;
begin
  FSimCount:=0;
  FSimLen:=0;
  FStats:=TStringList.Create;
end;

destructor TMCSim.Destroy;
begin
  Clear;
  FStats.Free;
  inherited;
end;

procedure TMCSim.CalculateStats;
var
  i,j : integer;
  losses, belowzero : integer;
  maxbelowzerovalue : single;
  resmax, resmin : single;
  d : single;
begin
  losses:=0; belowzero:=0; maxbelowzerovalue:=0;
  //final losses
  resmax:=-1000000000;
  resmin:=1000000000;
  for i := 0 to FSimCount - 1 do
  begin
    if FSeries[i][FSimLen-1]<=0 then inc(losses);
    if FSeries[i][FSimLen-1]<resmin then resmin:=FSeries[i][FSimLen-1];
    if FSeries[i][FSimLen-1]>resmax then resmax:=FSeries[i][FSimLen-1];
  end;
  d:=losses / FSimCount;
  FStats.Values['Wins']:=format('%.2f', [1-d]);
  FStats.Values['Losses']:=format('%.2f', [d]);    
  //was below zero
  for i := 0 to FSimCount - 1 do
    for j := 0 to FSimLen - 1 do
      if FSeries[i][j]<0 then
      begin
        inc(belowzero);
        break;
      end;
  d:=belowzero / FSimCount;
  FStats.Values['WasBelowZero']:=format('%.2f (%d/%d)', [d, belowzero, FSimCount]);
  //max below zero
  for i := 0 to FSimCount - 1 do
    for j := 0 to FSimLen - 1 do
      if FSeries[i][j]<maxbelowzerovalue then
        maxbelowzerovalue:=FSeries[i][j];
  FStats.Values['MaxBelowZero']:=format('%.0f', [maxbelowzerovalue]);
  //avg serie data
  FStats.Values['AvgSerieResult']:=format('%.2f', [FAvgSerie[FSimLen-1]]);
  FStats.Values['MinResult']:=format('%.2f', [resmin]);
  FStats.Values['MaxResult']:=format('%.2f', [resmax]);
end;

procedure TMCSim.GenerateSeries(WRatio: Single; WLRatio: Single);
var
  d: Single;
  i, j: Integer;
begin
  for i := 0 to FSimCount - 1 do
    for j := 0 to FSimLen - 1 do
    begin
      d := RandomFloat;
      if d <= WRatio then
      //win
      begin
        if j = 0 then
          FSeries[i][j] := WLRatio
        else
          FSeries[i][j] := FSeries[i][j - 1] + WLRatio;
      end
      else
      //loss
      begin
        if j = 0 then
          FSeries[i][j] := -1
        else
          FSeries[i][j] := FSeries[i][j - 1] - 1;
      end;
      if (j and 15) <> 0 then
        application.processmessages;
    end;
end;

procedure TMCSim.CalculateAvgSerie;
var
  d : single;
  i,j : integer;
begin
  for i := 0 to FSimLen - 1 do
  begin
    d:=0;
    for j := 0 to FSimCount - 1 do
      d:=d + FSeries[j][i];
    FAvgSerie[i]:=d / FSimCount;
  end;
end;

procedure TMCSim.Clear;
var
  i : integer;
begin
  for i:=0 to FSimCount-1 do
    SetLength( FSeries[i], 0 );
  SetLength( FSeries, 0 );
  SetLength(FAvgSerie, 0);
  FSimCount:=0;
  FSimLen:=0;
  FStats.Clear;
end;

procedure TMCSim.CreateSeries(ASimLen, ASimCnt : integer);
var
  i : integer;
begin
  FSimCount:=ASimCnt;
  FSimLen:=ASimLen;
  SetLength( FSeries, FSimCount );
  for i:=0 to FSimCount-1 do
    SetLength( FSeries[i], FSimLen );
  SetLength(FAvgSerie, FSimLen);
end;

procedure TMCSim.Simulate(WRatio, WLRatio: single; ASimLen,
  ASimCnt: integer);
begin
  Clear;
  CreateSeries(ASimLen, ASimCnt);
  GenerateSeries(WRatio, WLRatio);
  CalculateAvgSerie;
end;

procedure TMCSim.DrawSeries(bmp: TBitmap);
var
  w,h : integer;
  i,j : integer;
  vmax, vmin : double;
  rect : TRect;
  xdelta, ydelta : double;
  x,y : integer;

  procedure DrawSingleSerie(ASerie : TArrSingle);
  var
    i : integer;
  begin
    x:=0;
    y:=round((ASerie[0] - vmin) * ydelta);
    y:=h - y;
    bmp.Canvas.MoveTo(x,y);
    for i:=1 to FSimLen-1 do
    begin
      x:=round(i * xdelta);
      y:=Round((ASerie[i] - vmin) * ydelta);
      y:=h - y;
      bmp.Canvas.LineTo(x,y);
    end;
  end;
begin
  w:=bmp.Width;
  h:=bmp.Height;

  vmax:=-1000000000;
  vmin:=1000000000;
  for i:=0 to FSimCount-1 do
    for j:=0 to FSimLen-1 do
    begin
      if FSeries[i][j]>vmax then vmax:=FSeries[i][j];
      if FSeries[i][j]<vmin then vmin:=FSeries[i][j];
    end;
  if vmax<0 then vmax:=0;
  if vmin>0 then vmin:=0;

  xdelta:=w / FSimLen;
  ydelta:=h / (vmax - vmin);

  rect.Left:=0; rect.Top:=0; rect.Right:=w; rect.Bottom:=h;
  bmp.Canvas.Brush.Color:=clWhite;
  bmp.Canvas.FillRect(rect);

  //series
  bmp.Canvas.Pen.Color:=clWebLightgrey;
  for i:=0 to FSimCount-1 do
    DrawSingleSerie(FSeries[i]);
  bmp.Canvas.Pen.Color:=clWebSteelBlue;
  DrawSingleSerie(FAvgSerie);

  //horizontal zero line
  bmp.Canvas.Pen.Color:=clWebBlack;
  y:=h - round(abs(vmin) * ydelta);
  bmp.Canvas.MoveTo(0,y);
  bmp.Canvas.LineTo(w,y);
end;

end.
