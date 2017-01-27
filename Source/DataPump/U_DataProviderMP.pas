unit U_DataProviderMP;

interface

uses
  ADODB;

type
  TDebugInfo = record
    i,j : integer;
    id : integer;
    ts : TDateTime;
    val : double;
  end;

  TTSRec = record
    ts1, ts2 : TDateTime;
    cnt : integer;
    ttype : integer;
  end;

  TMPData = record
    Avg : double;
    ControlPoint : double;
    MultiControlPoint : boolean;
    ValueArea : array[0..1] of double;
  end;

  {*  Klasa danych dla Market Profile
  *}
  TDataProviderMP = class
  protected
    qryData : TADOQuery;
    DataMul : double;

    //procedura przygotowujaca informacje o danych (typ, tabele, ...) na podst ID
    procedure PrepareData;
    //procedura czyszczaca tabele
    procedure ClearData;
    //procedura dodajaca wartosc do MP
    procedure AddMPValue( valfieldname : string = 'open' );

    //procedura obliczajaca ControlPoint, ValueArea, ...
    procedure CalcMPData;
    procedure ClearMPData;
  public
    ID : integer;               //id
    StockType : integer;
    StockName : string;
    StartTS : TDateTime;        //ts startu notowan w ciagu dnia
    MPInterval : double;        //szerokosc przedzialu w minutach
    MPBlocks : integer;         //ilosc blokow TPO
    TS : TDateTime;             //ts dnia dla ktorego generowany MP

    TPO : array of array of integer;  //TimePriceOportunity
    TPOCnt : array of integer;        //TPO ilosci
    MinVal, MaxVal : double;
    MPData : TMPData;
    OpenPrice, ClosePrice : double;

    DataCount : integer;        //ilosc danych
    MinTS, MaxTS : TDateTime;   //poczatkowy i koncowy TS danych
    LastDataTS : TDateTime;     //ostatni TS danych

    DbgInfo : TDebugInfo;

    {*
      AID - id spolki/indeksu/...
      ADataType - typ danych: dzienne, intraXXm, ciagle
    *}
    constructor Create( AID : integer; ATS : TDateTime; AMPInterval : double = 30.0 ); virtual;
    destructor Destroy; override;

    //procedura pobierajaca dane od TS1 do TS2
    procedure GetData( ); virtual; abstract;

  end;

  //provider dla danych offline
  //dane sa za kazdym razem pobierane z tabel at_dzienne/intra/ciagle
  TDataOfflineProviderMP = class(TDataProviderMP)
  private
  public
    procedure GetData( ); override;
  end;

  //provider dla danych online
  //dane sa pobierane z at_dzienne/intra/ciagle oraz z tabel tikowych online (automatycznei dzielonych na odpowiednie okresy)
  TDataOnlineProviderMP = class(TDataProviderMP)
  private
    MinTSTick, MaxTSTick, MinTSB, MaxTSB : TDateTime;

    { procedura ustawiajaca odpowiednia wielkosc tabel }
    procedure SetTablesLength( NewMinVal, NewMaxVal : double );
    procedure UpdateTablesLength( NewMinVal, NewMaxVal : double );

    procedure NewData( );
    procedure UpdateData( );
  public
    constructor Create( AID : integer; ATS : TDateTime; AMPInterval : double = 30.0 ); override;
    procedure GetData( ); override;
  end;

implementation

uses U_DM, SysUtils, DB, dateutils, math, classes;

const
  C_MAXTBLLEN = 1000;

{ TDataProviderMP }

constructor TDataProviderMP.Create(AID: integer; ATS : TDateTime; AMPInterval : double);
begin
  StockName:='';
  MinTS:=0; MaxTS:=0;
  LastDataTS:=0;
  DataCount:=0;
  StartTS:=0;
  MinVal:=0; MaxVal:=0;
  OpenPrice:=0; ClosePrice:=0;

  qryData:=nil;
  qryData:=dm.GetNewQuery;

  ID:=AID;
  MPInterval:=AMPInterval;
  TS:=floor(ATS);
  PrepareData;
end;

destructor TDataProviderMP.Destroy;
begin
  if qryData<>nil then
  begin
    qryData.Close;
    qryData.Free;
  end;
  ClearData;
  inherited;
end;

procedure TDataProviderMP.ClearData;
var
  i : integer;
begin
  DataCount:=0;
  for i:=0 to Length(TPO)-1 do SetLength(TPO[i], 0);
  SetLength(TPO, 0);
  SetLength(TPOCnt, 0);
end;

procedure TDataProviderMP.PrepareData;
const
  Q_STOCKINFO = 'select * from at_spolki where ID=%d';
begin
  StockName:='';
  dm.OpenQuery(qryData, format(Q_STOCKINFO, [ID]));
  if not qryData.Eof then
  begin
    StockType:=qryData.FieldByName('typ').AsInteger;
    StockName:=qryData.FieldByName('nazwaakcji').AsString;

    if StockType in [2] then
    begin //kontrakty 9:00-16:30
      StartTS:=(60.0*9.0)/(60.0*24.0);
      MPBlocks:=round((60.0*9.0+30.0)/MPInterval);
      DataMul:=1.0;
    end
    else
    begin //pozostale 9:30-16:30
      StartTS:=(60.0*9.0 + 30.0)/(60.0*24.0);
      MPBlocks:=round((60.0*9.0)/MPInterval);
      DataMul:=100.0;
    end;

  end;
  qryData.Close;
end;

procedure TDataProviderMP.CalcMPData;
var
  i,j : integer;
  maxtpo, currtpo, cnttpo : integer;
  list : TList;
  d, mind, currva, d1,d2 : double;
  vacp, va1, va2, iva1,iva2 : integer;
begin
  ClearMPData;
//  if DataCount=0 then exit;
  list:=TList.Create;

    //srednia cena
  MPData.Avg:=(MaxVal-MinVal)/2 + MinVal;

    //controlpoint
  cnttpo:=0;
  maxtpo:=0;
  for i:=0 to DataCount-1 do
  begin
    currtpo:=TPOCnt[i];
    cnttpo:=cnttpo + currtpo;
    if currtpo=maxtpo then
    begin
      list.Add(pointer(i));
    end;
    if currtpo>maxtpo then
    begin
      list.Clear;
      list.Add(pointer(i));
      maxtpo:=currtpo;
    end;
  end;
  if maxtpo>0 then
  begin
    mind:=DataCount+1;
    for i:=0 to list.Count-1 do
    begin
      j:=integer(list.Items[i]);
      d:=abs(MPData.Avg - (minval+j));
      if d=mind then MPData.MultiControlPoint:=true;
      if d<mind then
      begin
        MPData.ControlPoint:=j + MinVal;
        MPData.MultiControlPoint:=false;
        mind:=d;
      end;
    end;
  end;

    //value area - ok 70% TPO z okolic ControlPoint
  if maxtpo>0 then
  begin
    d:=cnttpo * 0.7;
    currva:=maxtpo;
    vacp:=round(MPData.ControlPoint-MinVal);
    va1:=vacp;
    va2:=vacp;
    while currva<d do
    begin
      d1:=0; d2:=0;
      iva1:=va1; iva2:=va2;
      i:=va1-1; if i>=0 then begin d1:=d1 + TPOCnt[i]; iva1:=i; end;
      i:=va1-2; if i>=0 then begin d1:=d1 + TPOCnt[i]; iva1:=i; end;
      i:=va2+1; if i<DataCount then begin d2:=d2 + TPOCnt[i]; iva2:=i; end;
      i:=va2+2; if i<DataCount then begin d2:=d2 + TPOCnt[i]; iva2:=i; end;
      if d1=d2 then       //d1=d2 -> wybieramy to blizsze ControlPoint, jesli odleglsci sa rowne to dodajemy oba
      begin
        if (vacp-va1)<(va2-vacp) then d2:=0;
        if (vacp-va1)>(va2-vacp) then d1:=0;
      end;
      if d1>=d2 then
      begin
        currva:=currva + d1;
        va1:=iva1;
      end;
      if d2>=d1 then
      begin
        currva:=currva + d2;
        va2:=iva2;
      end;
      if (va1=0) and (va2=DataCount-1) then break;  //jak by valuearea objelo caly przedzial
    end;
    MPData.ValueArea[0]:=va1 + MinVal;
    MPData.ValueArea[1]:=va2 + MinVal;
  end;

  list.Free;
end;

procedure TDataProviderMP.ClearMPData;
begin
  MPData.Avg:=0;
  MPData.ControlPoint:=0;
  MPData.MultiControlPoint:=false;
  MPData.ValueArea[0]:=0; MPData.ValueArea[1]:=0;
end;

procedure TDataProviderMP.AddMPValue( valfieldname : string = 'open' );
var
  i,j : integer;
  d : double;
begin
  DbgInfo.i:=-1; DbgInfo.j:=-1; DbgInfo.id:=0; DbgInfo.ts:=0; DbgInfo.val:=0;
  DbgInfo.id:=qryData.fieldbyname('id').AsInteger;
  DbgInfo.ts:=qryData.fieldbyname('ts').AsDateTime;
  DbgInfo.val:=qryData.fieldbyname(valfieldname).AsFloat;

  i:=round(floor(qryData.fieldbyname(valfieldname).AsFloat*DataMul) - MinVal);
  d:=qryData.fieldbyname('ts').AsDateTime;
  d:=(d-floor(d) - StartTS)*24.0*60.0;  //minuta w sesji
  j:=round(floor(d/MPInterval));        //nr bloku danych

  DbgInfo.i:=i;
  DbgInfo.j:=j;

  if TPO[i,j]=0 then inc(TPOCnt[i]);
  inc(TPO[i,j]);  //zaznaczenie ze bylo takie TPO

  LastDataTS:=qryData.fieldbyname('ts').AsDateTime;
  ClosePrice:=qryData.fieldbyname(valfieldname).AsFloat*DataMul;
end;

{ TDataOfflineProviderMP }

procedure TDataOfflineProviderMP.GetData();
const
  Q_CNT = 'select count(*), min(low), max(high) from at_ciagle%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s''';
  Q_DATA = 'select * from at_ciagle%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts';
var
  i : integer;
  cnt : integer;
begin
  ClearData;

    //ilosc rekordow
  dm.OpenQuery(qryData, format(Q_CNT,[StockType, ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]));
  if qryData.Eof then
  begin
    qryData.Close;
    exit;
  end;
  if qryData.Fields[0].AsInteger=0 then
  begin
    qryData.Close;
    exit;
  end;
  MinVal:=qryData.Fields[1].AsFloat;
  MaxVal:=qryData.Fields[2].AsFloat;
  qryData.Close;

  MinVal:=floor(MinVal*DataMul);
  MaxVal:=floor(MaxVal*DataMul);

    //rekordy
  DataCount:=round(MaxVal-MinVal)+1;
  SetLength(TPO, DataCount);
  for i:=0 to Length(TPO)-1 do SetLength(TPO[i], MPBlocks);
  SetLength(TPOCnt, DataCount);

  cnt:=0;  
  dm.OpenQuery(qryData, format(Q_DATA,[StockType, ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]));
  while not qryData.Eof do
  begin
    if cnt=0 then OpenPrice:=qryData.fieldbyname('open').AsFloat*DataMul;
    AddMPValue;
    qryData.Next;
    inc(cnt);
  end;
  qryData.Close;

  if DataCount>0 then
  begin
    MinTS:=TS + StartTS;
    MaxTS:=LastDataTS;
    CalcMPData;
  end;

end;

{ TDataOnlineProviderMP }


constructor TDataOnlineProviderMP.Create( AID : integer; ATS : TDateTime; AMPInterval : double = 30.0 );
begin
  inherited;
  MinTSTick:=0;
  MaxTSTick:=0;
  MinTSB:=0;
  MaxTSB:=0;
end;

procedure TDataOnlineProviderMP.GetData();
begin
  if DataCount=0 then
  begin
    NewData();
  end
  else
  begin
    UpdateData();
  end;
  qryData.Close;

  if DataCount>0 then
  begin
    MinTS:=TS + StartTS;
    MaxTS:=LastDataTS;
    CalcMPData;
  end;
end;


procedure TDataOnlineProviderMP.NewData();
const
  Q_CNT0 = 'select count(*), min(ts), max(ts), min(low), max(high) from at_ticks where fk_id_spolki=%d and ts>=''%s'' and ts<''%s''';
  Q_CNT1 = 'select count(*), min(ts), max(ts), min(val), max(val) from at_biezace where fk_id_spolki=%d and ts>''%s'' and ts<''%s''';
  Q_CNT1a = 'select count(*), min(ts), max(ts), min(val), max(val) from at_biezace where fk_id_spolki=%d and ts>=''%s'' and ts<''%s''';
  Q_DATA0 = 'select * from at_ticks where fk_id_spolki=%d and ts>=''%s'' and ts<=''%s'' order by ts';
  Q_DATA1 = 'select * from at_biezace where fk_id_spolki=%d and ts>=''%s'' and ts<=''%s'' order by ts';
var
  tstbl : array[0..1] of TTSRec;
  cnt : integer;
  v1, v2 : double;
begin
  v1:=1000000000; v2:=0;
  dm.OpenQuery(qryData, format(Q_CNT0, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]));
  tstbl[0].cnt:=qryData.Fields[0].AsInteger;
  tstbl[0].ts1:=qryData.Fields[1].AsDateTime;
  tstbl[0].ts2:=qryData.Fields[2].AsDateTime;
  if tstbl[0].cnt>0 then
  begin
    if v1>qryData.Fields[3].AsFloat then v1:=qryData.Fields[3].AsFloat;
    if v2<qryData.Fields[4].AsFloat then v2:=qryData.Fields[4].AsFloat;
  end;
  if tstbl[0].cnt>0 then
    dm.OpenQuery(qryData, format(Q_CNT1, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[0].ts2), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]))
  else
    dm.OpenQuery(qryData, format(Q_CNT1a, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]));
  tstbl[1].cnt:=qryData.Fields[0].AsInteger;
  tstbl[1].ts1:=qryData.Fields[1].AsDateTime;
  tstbl[1].ts2:=qryData.Fields[2].AsDateTime;
  if tstbl[1].cnt>0 then
  begin
    if v1>qryData.Fields[3].AsFloat then v1:=qryData.Fields[3].AsFloat;
    if v2<qryData.Fields[4].AsFloat then v2:=qryData.Fields[4].AsFloat;
  end;

  if tstbl[0].cnt+tstbl[1].cnt=0 then exit;

    //inicjalizacja tabel
  v1:=floor(v1*DataMul);
  v2:=floor(v2*DataMul);
  SetTablesLength(v1, v2);
  MinVal:=v1;
  MaxVal:=v2;

  dm.OpenQuery(qryData, format(Q_DATA0, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[0].ts1), formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[0].ts2)]));
  while not qryData.Eof do
  begin
//    if cnt=0 then OpenPrice:=qryData.fieldbyname('open').AsFloat*DataMul;
    if OpenPrice=0 then OpenPrice:=qryData.fieldbyname('open').AsFloat*DataMul;
    AddMPValue;
    qryData.Next;
  end;

  dm.OpenQuery(qryData, format(Q_DATA1, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[1].ts1), formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[1].ts2)]));
  while not qryData.Eof do
  begin
//    if cnt=0 then OpenPrice:=qryData.fieldbyname('val').AsFloat*DataMul;
    if OpenPrice=0 then OpenPrice:=qryData.fieldbyname('val').AsFloat*DataMul;
    AddMPValue('val');
    qryData.Next;
  end;

  MinTSTick:=tstbl[0].ts1; MaxTSTick:=tstbl[0].ts2;
  MinTSB:=tstbl[1].ts1; MaxTSB:=tstbl[1].ts2;
end;

procedure TDataOnlineProviderMP.UpdateData();
const
  Q_CNT0 = 'select count(*), min(ts), max(ts), min(low), max(high) from at_ticks where fk_id_spolki=%d and ts>''%s'' and ts<''%s''';
  Q_CNT1 = 'select count(*), min(ts), max(ts), min(val), max(val) from at_biezace where fk_id_spolki=%d and ts>''%s'' and ts<=''%s''';
  Q_DATA0 = 'select * from at_ticks where fk_id_spolki=%d and ts>''%s'' and ts<=''%s'' order by ts';
  Q_DATA1 = 'select * from at_biezace where fk_id_spolki=%d and ts>''%s'' and ts<=''%s'' order by ts';
var
  tstbl : array[0..1] of TTSRec;
  v1, v2 : double;
begin
  v1:=MinVal;
  v2:=MaxVal;
  //aktualizacja danych tikowych
  if MaxTSTick>0 then
    dm.OpenQuery(qryData, format(Q_CNT0, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', MaxTSTick), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]))
  else
    dm.OpenQuery(qryData, format(Q_CNT0, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]));
  tstbl[0].cnt:=qryData.Fields[0].AsInteger;
  tstbl[0].ts1:=qryData.Fields[1].AsDateTime;
  tstbl[0].ts2:=qryData.Fields[2].AsDateTime;
  if tstbl[0].cnt>0 then
  begin
    if v1>qryData.Fields[3].AsFloat then v1:=qryData.Fields[3].AsFloat;
    if v2<qryData.Fields[4].AsFloat then v2:=qryData.Fields[4].AsFloat;
  end;
  if MaxTSB>0 then
    dm.OpenQuery(qryData, format(Q_CNT1, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', MaxTSB), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]))
  else
    dm.OpenQuery(qryData, format(Q_CNT1, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', TS+1)]));
  tstbl[1].cnt:=qryData.Fields[0].AsInteger;
  tstbl[1].ts1:=qryData.Fields[1].AsDateTime;
  tstbl[1].ts2:=qryData.Fields[2].AsDateTime;
  if tstbl[1].cnt>0 then
  begin
    if v1>qryData.Fields[3].AsFloat then v1:=qryData.Fields[3].AsFloat;
    if v2<qryData.Fields[4].AsFloat then v2:=qryData.Fields[4].AsFloat;
  end;

  v1:=floor(v1*DataMul);
  v2:=floor(v2*DataMul);
  UpdateTablesLength(v1, v2);
  MinVal:=v1;
  MaxVal:=v2;


  if MaxTSTick>0 then
    dm.OpenQuery(qryData, format(Q_DATA0, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', MaxTSTick), formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[0].ts2)]))
  else
    dm.OpenQuery(qryData, format(Q_DATA0, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[0].ts2)]));
  while not qryData.Eof do
  begin
    if OpenPrice=0 then OpenPrice:=qryData.fieldbyname('open').AsFloat*DataMul;
    AddMPValue;
    qryData.Next;
  end;

  if MaxTSB>0 then
    dm.OpenQuery(qryData, format(Q_DATA1, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', MaxTSB), formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[1].ts2)]))
  else
    dm.OpenQuery(qryData, format(Q_DATA1, [ID, formatdatetime('yyyy-mm-dd hh:nn:ss', TS), formatdatetime('yyyy-mm-dd hh:nn:ss', tstbl[1].ts2)]));
  while not qryData.Eof do
  begin
    if OpenPrice=0 then OpenPrice:=qryData.fieldbyname('val').AsFloat*DataMul;
    AddMPValue('val');
    qryData.Next;
  end;

  if MaxTSTick<tstbl[0].ts2 then MaxTSTick:=tstbl[0].ts2;
  if MaxTSB<tstbl[1].ts2 then MaxTSB:=tstbl[1].ts2;
end;

procedure TDataOnlineProviderMP.SetTablesLength(NewMinVal, NewMaxVal : double);
var
  i : integer;
begin
  DataCount:=round(NewMaxVal-NewMinVal)+1;
  SetLength(TPO, C_MAXTBLLEN);
  for i:=0 to Length(TPO)-1 do SetLength(TPO[i], MPBlocks);
  SetLength(TPOCnt, C_MAXTBLLEN);
end;

procedure TDataOnlineProviderMP.UpdateTablesLength(NewMinVal, NewMaxVal : double);
var
  i,j, cnt : integer;
begin
  cnt:=round(NewMaxVal-NewMinVal)+1;
//  SetLength(TPO, cnt);
//  for i:=DataCount to Length(TPO)-1 do SetLength(TPO[i], MPBlocks);
//  SetLength(TPOCnt, cnt);
  DataCount:=cnt;

  cnt:=round(MinVal - NewMinVal);
  if cnt>0 then
    for i:=DataCount-1-cnt downto 0 do  //przesuniecie danych w odpowiednie miejsce
    begin
      for j:=0 to MPBlocks-1 do
      begin
        TPO[i+cnt][j]:=TPO[i][j];
        TPO[i][j]:=0;
      end;
      TPOCnt[i+cnt]:=TPOCnt[i];
      TPOCnt[i]:=0;
    end;
end;

end.
