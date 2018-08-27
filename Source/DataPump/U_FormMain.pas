unit U_FormMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, ActnList, 
  U_FilesDownloader, U_DataInserter, U_DataGenerator, U_DataPumpConfig,
  U_DailyDataProcessor;

const
  MSG_AUTOMATICPROCESS = WM_APP + 1000;

type
  TFormMain = class(TForm)
    Panel1: TPanel;
    mmUpdateLog: TMemo;
    Label1: TLabel;
    lblLPPostep: TLabel;
    Label3: TLabel;
    lblLPCzasDoKoncaPakietu: TLabel;
    Panel2: TPanel;
    pgcMain: TPageControl;
    tabDL: TTabSheet;
    tabPodzial: TTabSheet;
    alMain: TActionList;
    actDLCiagle: TAction;
    actDLDzienne: TAction;
    Button1: TButton;
    Button2: TButton;
    lblLPSpolka: TLabel;
    lblLPStan: TLabel;
    actDLBreak: TAction;
    Button3: TButton;
    actGenIntraWeek: TAction;
    Label2: TLabel;
    cbGenDataType: TComboBox;
    Panel3: TPanel;
    Label4: TLabel;
    cbSpolka: TComboBox;
    Button4: TButton;
    Panel4: TPanel;
    mmLogGen: TMemo;
    Label5: TLabel;
    lblGenProg: TLabel;
    tabMP: TTabSheet;
    Panel5: TPanel;
    Label6: TLabel;
    Label7: TLabel;
    cbMPDataType: TComboBox;
    cbMPSpolka: TComboBox;
    Button6: TButton;
    mmLogMP: TMemo;
    actGenMP: TAction;
    cbGenType: TComboBox;
    cbDaneDzienne: TComboBox;
    Label8: TLabel;
    lblGenCzasDoKoncaPakietu: TLabel;
    Button5: TButton;
    actGenBreak: TAction;
    gbIntra: TGroupBox;
    gbDaily: TGroupBox;
    actFromFileDzienne: TAction;
    Button7: TButton;
    odDzienneFromFile: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure actDLDzienneExecute(Sender: TObject);
    procedure actDLCiagleExecute(Sender: TObject);
    procedure actDLBreakExecute(Sender: TObject);
    procedure actGenIntraWeekExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure actGenMPExecute(Sender: TObject);
    procedure actGenBreakExecute(Sender: TObject);
    procedure actFromFileDzienneExecute(Sender: TObject);
  private
    FBreakLoad : boolean;
    FFilesDownloader : TFilesDownloader;
    FDataInserter : TDataInserter;
    FDataGenerator : TDataGenerator;
    FUnzipDir : string;
    FDPConfig : TDataPumpConfig;
    FDailyDataProc : TDailyDataProcessor;

    procedure LoadSpolki;

    //procedury genrujace MP
    procedure GenMPDzienne( idspolki, typ : integer );

    //automatyczne wciagnie danych na podst DataPumpAuto.ini
    procedure AutomaticProcess;

    //downloads ticks data for current qrySpolki opened query
    procedure InternalDLCiagleCurrentSpolki;

    //datainserter events
    procedure OnInsertProgress(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALinesPerSec : double; ALongEvent : boolean; var VDoBreak : boolean);
    procedure OnInsertFinished(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALinesPerSec : double; ALongEvent : boolean; var VDoBreak : boolean);
    //datagenerator events
    procedure OnGenerateProgress(ACurrTS : string; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean);
    procedure OnGenerateFinished(ACurrTS : string; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean);
    //async download events
    procedure OnCheckDownloadBreak(var VBreakLoad : boolean);

    function OnCheckBreakLoad : boolean;
  protected
    procedure MsgAutomaticProcess( var Msg : TMessage ); message MSG_AUTOMATICPROCESS;
  public
  end;

var
  FormMain: TFormMain;

implementation

uses U_DM, rxfileutil, rxdateutil, rxstrutils,U_InetFile, DateUtils, math,
  DB, U_DataProviderMP, inifiles, U_Consts, U_SeriesInfo, U_Utils;

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FFilesDownloader:=TFilesDownloader.Create;
  FFilesDownloader.OnCheckDownloadBreak:=OnCheckDownloadBreak;
  FDataInserter:=TDataInserter.Create;
  FDataInserter.OnInsertProgress:=OnInsertProgress;
  FDataInserter.OnInsertFinished:=OnInsertFinished;
  FDataGenerator:=TDataGenerator.Create;
  FDataGenerator.OnGenerateProgress:=OnGenerateProgress;
  FDataGenerator.OnGenerateFinished:=OnGenerateFinished;
  FUnzipDir:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\';
  ForceDirectories(FUnzipDir);
  FDPConfig:=TDataPumpConfig.Create;
  FDailyDataProc:=TDailyDataProcessor.Create(FUnzipDir, FDataInserter, FFilesDownloader, FDPConfig, mmUpdateLog.Lines, lblLPStan, lblLPSpolka);
  FDailyDataProc.OnCheckBreakLoad:=OnCheckBreakLoad;

  caption:=application.Title;
  pgcMain.ActivePageIndex:=0;
  LoadSpolki;

  if ParamStr(1)='datapumpauto' then
    PostMessage( Handle, MSG_AUTOMATICPROCESS, 0,0);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FDailyDataProc.Free;
  FDPConfig.Free;
  FDataGenerator.Free;
  FDataInserter.Free;
  FFilesDownloader.Free;
end;

procedure TFormMain.actDLDzienneExecute(Sender: TObject);
begin
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  FDailyDataProc.Download(cbDaneDzienne.ItemIndex);
  MessageDlg('Pobieranie danych dziennych zakoñczone', mtInformation, [mbOK], 0);
end;

procedure TFormMain.actFromFileDzienneExecute(Sender: TObject);
begin
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  if not odDzienneFromFile.Execute(Handle) then exit;
  FDailyDataProc.FromFile(cbDaneDzienne.ItemIndex, odDzienneFromFile.FileName);
  MessageDlg('Pobieranie danych dziennych zakoñczone', mtInformation, [mbOK], 0);
end;

procedure TFormMain.actDLCiagleExecute(Sender: TObject);
const
  Q_SPOLKI = 'select * from at_spolki order by typ, id';
//  Q_SPOLKI = 'select * from at_spolki where id=288 order by typ, id'; //WIG
//  Q_SPOLKI = 'select * from at_spolki where id=1039 order by typ, id'; //FW20WS20
begin
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  lblLPSpolka.Caption:=''; lblLPStan.Caption:='';
  mmUpdateLog.Clear;
  mmUpdateLog.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;

  dm.OpenQuery(dm.qrySpolki, Q_SPOLKI);
  InternalDLCiagleCurrentSpolki;
  dm.qrySpolki.Close;
  ClearDir(FUnzipDir, false); //czyscimy katalog downloadu

  mmUpdateLog.Lines.Add('+++ Stop: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  MessageDlg('Pobieranie danych ci¹g³ych zakoñczone', mtInformation, [mbOK], 0);
end;

procedure TFormMain.actDLBreakExecute(Sender: TObject);
begin
  FBreakLoad:=true;
  FFilesDownloader.StopAsyncDownload;
end;

procedure TFormMain.actGenBreakExecute(Sender: TObject);
begin
  FBreakLoad:=true;
end;

procedure TFormMain.actGenIntraWeekExecute(Sender: TObject);
const
  Q_STOCKSID = 'select id, nazwaspolki, nazwaakcji, typ from at_spolki where id=%d and aktywna=TRUE';
  Q_STOCKSTYP = 'select id, nazwaspolki, nazwaakcji, typ from at_spolki where typ=%d and aktywna=TRUE order by id';
  Q_STOCKSALL = 'select id, nazwaspolki, nazwaakcji, typ from at_spolki where aktywna=TRUE order by typ, id';
  Q_STOCKTEST = 'select id, nazwaspolki, nazwaakcji, typ  from at_spolki where id=1039'; //FW20WS20
var
  genrange : integer;
  gentype : TMarketOpsDataGenType;
  id : integer;
  typ : TMarketOpsStockType;
begin
  lblGenProg.Caption:=''; lblGenCzasDoKoncaPakietu.Caption:='';
  mmLogGen.Clear;
  mmLogGen.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;
  Application.ProcessMessages;

  //generation range and type
  case cbGenDataType.ItemIndex of
    0 : begin gentype:=mogenWeek; genrange:=1; end;
    1 : begin gentype:=mogenMonth; genrange:=1; end;
    2 : begin gentype:=mogenMinute; genrange:=1; end;//  1 min
    3 : begin gentype:=mogenMinute; genrange:=2; end;//  2 min
    4 : begin gentype:=mogenMinute; genrange:=3; end;//  3 min
    5 : begin gentype:=mogenMinute; genrange:=4; end;//  4 min
    6 : begin gentype:=mogenMinute; genrange:=5; end;//  5 min
    7 : begin gentype:=mogenMinute; genrange:=10; end;//  10 min
    8 : begin gentype:=mogenMinute; genrange:=15; end;//  15 min
    9 : begin gentype:=mogenMinute; genrange:=20; end;//  20 min
    10: begin gentype:=mogenMinute; genrange:=30; end;//  30 min
    11: begin gentype:=mogenHour; genrange:=1; end;//  60 min
  end;

  //select stocks
  if (cbGenType.ItemIndex=0) and (cbSpolka.Items.Objects[cbSpolka.ItemIndex]<>nil) then
  begin  //selected stock
    id:=Integer(cbSpolka.Items.Objects[cbSpolka.ItemIndex]);
    dm.OpenQuery(dm.qrySpolki, Q_STOCKSID, [id]);
  end
  else if cbGenType.ItemIndex=1 then
  begin  //all stocks
    dm.OpenQuery(dm.qrySpolki, Q_STOCKSALL);
  end
  else if cbGenType.ItemIndex in [2,3,4,5,6,7] then
  begin  //selected type
    case cbGenType.ItemIndex of
      2 : typ:=motGPWStock;
      3 : typ:=motGPWIndex;
      4 : typ:=motGPWIndexFuture;
      5 : typ:=motPLInvestmentFund;
      6 : typ:=motNBPCurrency;
      7 : typ:=motBossaFX;
    end;
    dm.OpenQuery(dm.qrySpolki, Q_STOCKSTYP, [ord(typ)]);
  end;
//  dm.OpenQuery(dm.qrySpolki, Q_STOCKTEST);  //test query
  //generate data for selected stocks
  FDataGenerator.StartSession;
  dm.qrySpolki.First;
  while not dm.qrySpolki.Eof do
  begin
    Application.ProcessMessages;
    if FBreakLoad then break;
    if not FDataGenerator.GenerateData(gentype, genrange, TMarketOpsStockType(dm.qrySpolki.FieldByName('typ').asinteger), dm.qrySpolki.FieldByName('id').asinteger) then
      mmLogGen.Lines.Add('B³¹d: ' + FDataInserter.ErrMsg);
    dm.qrySpolki.Next;
  end;
  dm.qrySpolki.Close;
  FDataGenerator.StopSession;

  mmLogGen.Lines.Add('+++ Stop: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
end;

procedure TFormMain.actGenMPExecute(Sender: TObject);
var
  typ : integer;
begin
  mmLogMP.Clear;
    //wybrana spolka
  if (cbMPSpolka.Items.Objects[cbMPSpolka.ItemIndex]<>nil) and (cbMPDataType.ItemIndex>-1) then
  begin
    case cbMPDataType.ItemIndex of
      0 : typ:=30;
    end;
    GenMPDzienne( Integer(cbMPSpolka.Items.Objects[cbMPSpolka.ItemIndex]), typ );
  end;
end;

procedure TFormMain.AutomaticProcess;
const
//  Q_STOCKINFO = 'select id, typ, nazwaakcji2, nazwaakcji from at_spolki where nazwaspolki=''%s''';
  Q_STOCKINFO = 'select * from at_spolki where nazwaspolki=''%s''';
var
  ini : TIniFile;
  stocks, sl, sl2 : TStringList;
  i, j : integer;
  stockid : integer;
  stocktype : TMarketOpsStockType;
  dlfiles : TStringList;
  datafn : string;
  s : string;
  genrange : integer;
  gentype : TMarketOpsDataGenType;
begin
  mmUpdateLog.Lines.Add('=== +++ === Automatyczne pobieranie rozpoczête ' + formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;
  stocks:=TStringList.Create;
  sl:=TStringList.Create;
  sl2:=TStringList.Create;
  dlfiles:=TStringList.Create;
  ini:=TIniFile.Create(extractfilepath(paramstr(0)) + 'DataPumpAuto.ini');
  try
    ini.ReadSections(stocks);
    for i := 0 to stocks.Count - 1 do
    begin
      ini.ReadSectionValues(stocks[i], sl);
      lblLPSpolka.Caption:=sl.Values['stock'];
      dm.OpenQuery(dm.qrySpolki, Q_STOCKINFO, [sl.Values['stock']]);
      stockid:=dm.qrySpolki.FieldByName('id').AsInteger;
      stocktype:=TMarketOpsStockType(dm.qrySpolki.FieldByName('typ').AsInteger);

      pgcMain.ActivePage:=tabDL;
      Application.ProcessMessages;
        //dl dzienne
      if dlfiles.Values[ inttostr(ord(stocktype)) ]='' then
      begin
        FFilesDownloader.DownloadAndUnzip(FDPConfig.GetDLDziennePath(stocktype), FDPConfig.GetDLDzienneFileName(stocktype), FUnzipDir);
        dlfiles.Values[ inttostr(ord(stocktype)) ]:='x';
      end;
      datafn:=FUnzipDir + dm.qrySpolki.fieldbyname('nazwaakcji2').AsString + '.mst';
      FDataInserter.InsertData(modataDaily, stocktype, stockid, datafn);
        //dl ciagle
      InternalDLCiagleCurrentSpolki;

        //data generating
      sl2.CommaText:=sl.Values['ops'];
      for j := 0 to sl2.Count - 1 do
      begin
        s:=sl2[i];
        if s='mp30' then  //market proflie 30
        begin
          pgcMain.ActivePage:=tabMP;
          Application.ProcessMessages;
          GenMPDzienne(stockid, 30);
        end
        else if pos('intra', s)=1 then  //intraday data
        begin
          pgcMain.ActivePage:=tabPodzial;
          Application.ProcessMessages;
          s:=ReplaceStr(s, 'intra', '');
          s:=ReplaceStr(s, 'm', '');
          case strtoint(s) of
            1 : begin gentype:=mogenMinute; genrange:=1; end;//  1 min
            2 : begin gentype:=mogenMinute; genrange:=2; end;//  2 min
            3 : begin gentype:=mogenMinute; genrange:=3; end;//  3 min
            4 : begin gentype:=mogenMinute; genrange:=4; end;//  4 min
            5 : begin gentype:=mogenMinute; genrange:=5; end;//  5 min
            10 : begin gentype:=mogenMinute; genrange:=10; end;//  10 min
            15 : begin gentype:=mogenMinute; genrange:=15; end;//  15 min
            20 : begin gentype:=mogenMinute; genrange:=20; end;//  20 min
            30: begin gentype:=mogenMinute; genrange:=30; end;//  30 min
            60: begin gentype:=mogenHour; genrange:=1; end;//  60 min
          end;
          if not FDataGenerator.GenerateData(gentype, genrange, stocktype, stockid) then
            mmLogGen.Lines.Add('B³¹d: ' + FDataInserter.ErrMsg);
        end;
      end;
    end;
  finally
    ini.Free;
    dlfiles.Free;
    sl2.Free;
    sl.Free;
    stocks.Free;
  end;
  ClearDir(FUnzipDir, false);

  pgcMain.ActivePage:=tabDL;
  Application.ProcessMessages;
  mmUpdateLog.Lines.Add('=== +++ === Automatyczne pobieranie zakoñczone ' + formatdatetime('yyyy-mm-dd hh:nn:ss', now));
end;

procedure TFormMain.LoadSpolki;
const
  Q_SPOLKI = 'select * from at_spolki where aktywna=TRUE order by typ, nazwaspolki';
var
  lasttyp : integer;
begin
  lasttyp:=-1;
  cbSpolka.Clear;
  dm.OpenQuery(dm.qrySpolki, Q_SPOLKI);
  dm.qrySpolki.First;
  while not dm.qrySpolki.Eof do
  begin
    if lasttyp<>dm.qrySpolki.FieldByName('typ').asinteger then
    case dm.qrySpolki.FieldByName('typ').asinteger of
      0: cbSpolka.AddItem('--- Spó³ki', nil);
      1: cbSpolka.AddItem('--- Indeksy', nil);
      2: cbSpolka.AddItem('--- Kontrakty', nil);
      3: cbSpolka.AddItem('--- Opcje', nil);
      4: cbSpolka.AddItem('--- Fundusze', nil);
    end;
    cbSpolka.AddItem( dm.qrySpolki.FieldByName('nazwaspolki').AsString, Pointer(dm.qrySpolki.FieldByName('id').asinteger) );
    lasttyp:=dm.qrySpolki.FieldByName('typ').asinteger;
    dm.qrySpolki.Next;
  end;
  dm.qrySpolki.Close;
  cbMPSpolka.Items.AddStrings(cbSpolka.Items);
end;

procedure TFormMain.MsgAutomaticProcess(var Msg: TMessage);
begin
  Application.ProcessMessages;
  AutomaticProcess;
end;

function TFormMain.OnCheckBreakLoad: boolean;
begin
  result:=FBreakLoad;
end;

procedure TFormMain.OnCheckDownloadBreak(var VBreakLoad: boolean);
begin
  Application.ProcessMessages;
  VBreakLoad:=FBreakLoad;
end;

procedure TFormMain.OnGenerateFinished(ACurrTS: string;
  ATimeExpectedToFinish: TDateTime; ALongEvent: boolean; var VDoBreak: boolean);
begin
  mmLogGen.Lines.Add(format('%s [%d]', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, dm.qrySpolki.fieldbyname('id').AsInteger]));
  Application.ProcessMessages;
end;

procedure TFormMain.OnGenerateProgress(ACurrTS: string;
  ATimeExpectedToFinish: TDateTime; ALongEvent: boolean; var VDoBreak: boolean);
begin
  if not ALongEvent then
  begin
    lblGenProg.Caption:=ACurrTS;
    Application.ProcessMessages;
  end
  else
    lblGenCzasDoKoncaPakietu.Caption:=format('%s', [FormatDateTime('hh:nn:ss', ATimeExpectedToFinish)]);
  VDoBreak:=FBreakLoad;
end;

procedure TFormMain.OnInsertFinished(ALinesRead: integer;
  ATimeExpectedToFinish: TDateTime; ALinesPerSec : double; ALongEvent: boolean; var VDoBreak: boolean);
begin
  mmUpdateLog.Lines.Add(format('%s [%d]: %d', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, dm.qrySpolki.fieldbyname('id').AsInteger, ALinesRead]));
end;

procedure TFormMain.OnInsertProgress(ALinesRead: integer;
  ATimeExpectedToFinish: TDateTime; ALinesPerSec : double; ALongEvent: boolean; var VDoBreak: boolean);
begin
  if not ALongEvent then
  begin
    lblLPPostep.Caption:=format('%d', [ALinesRead]);
    Application.ProcessMessages;
  end
  else
    lblLPCzasDoKoncaPakietu.Caption:=format('%s (%.2f lines/s)', [FormatDateTime('hh:nn:ss', ATimeExpectedToFinish), ALinesPerSec]);
  VDoBreak:=FBreakLoad;
end;

procedure TFormMain.GenMPDzienne(idspolki, typ: integer);
const
  Q_STOCKINFO = 'select * from at_spolki where id=%d';
  Q_MAXMP = 'select max(ts) from mp_dzienne%dm%d where fk_id_spolki=%d';
  Q_LASTID = 'select id from mp_dzienne%dm%d where fk_id_spolki=%d and ts=''%s''';
  Q_INSMP = 'insert into mp_dzienne%dm%d(fk_id_spolki, ts, cp, val ,vah, avg) values(%d, ''%s'', %s, %s, %s, %s)';
  Q_INSMPTPO = 'insert into mp_dzienne%dm%dtpo(fk_id_spolki, fk_id_mp, val, tpocnt, tpo) values(%d, %d, %s, %d, ''%s'')';
var
  dp : TDataProviderMP;
  maxts, d : double;
  stocktype : integer;
  i,j,k, id : integer;
  s : string;
begin
  dm.OpenQuery( dm.qryTemp, format(Q_STOCKINFO, [idspolki]) );
  stocktype:=dm.qryTemp.fieldbyname('typ').AsInteger;
  dm.OpenQuery( dm.qryTemp, format(Q_MAXMP,[typ, stocktype, idspolki]) );
  maxts:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
  if maxts>0 then
    maxts:=floor(maxts) + 1
  else
    maxts:=StrToDate('2000-01-01');
  d:=floor(now)+1;

  i:=0;
  while maxts<=d do
  begin
    if i and $f <> 0 then application.ProcessMessages;

    dp:=TDataOfflineProviderMP.Create(idspolki, maxts);
    dp.GetData;
    mmLogMP.Lines.Add( format('%s : %d', [formatdatetime('yyyy-mm-dd',maxts), dp.DataCount]) );
    if dp.DataCount>0 then
    begin
      dm.ExecSql(format(Q_INSMP,[
        typ, stocktype,
        idspolki, formatdatetime('yyyy-mm-dd', maxts),
        PrepareFloatVal(dp.MPData.ControlPoint),
        PrepareFloatVal(dp.MPData.ValueArea[0]),
        PrepareFloatVal(dp.MPData.ValueArea[1]),
        PrepareFloatVal(dp.MPData.Avg)
      ]));
      dm.OpenQuery(dm.qryTemp, format(Q_LASTID, [ typ, stocktype, idspolki, formatdatetime('yyyy-mm-dd', maxts)]));
      id:=dm.qryTemp.fieldbyname('id').AsInteger;
      dm.qryTemp.Close;
      for j:=0 to dp.DataCount-1 do
      begin
        s:='';
        for k:=0 to dp.MPBlocks-1 do
          if dp.TPO[j][k]>0 then s:=s + IntToStr(k) + ',';
        dm.ExecSql(format(Q_INSMPTPO, [
          typ, stocktype,
          idspolki, id,
          PrepareFloatVal(dp.MinVal + j),
          dp.TPOCnt[j],
          s
        ]));
      end;
//      break;
    end;
    dp.Free;

    maxts:=maxts+1;
    inc(i);
  end;
end;

procedure TFormMain.InternalDLCiagleCurrentSpolki;
var
  fn, datafn : string;
  sinfo : TSeriesInfo;
  i : integer;
begin
  sinfo:=TSeriesInfo.Create;
  try
    dm.qrySpolki.First;
    while not dm.qrySpolki.Eof do
    begin
      if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
      begin
        if dm.qrySpolki.fieldbyname('typ').AsInteger in [Ord(motGPWStock), Ord(motGPWIndex)] then  //spolki,indeksy
        begin
          FFilesDownloader.DownloadAsync(dm.Settings[format('PathCiagle%d',[dm.qrySpolki.fieldbyname('typ').AsInteger])], dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip', FUnzipDir);
        end
        else if dm.qrySpolki.fieldbyname('typ').AsInteger=Ord(motGPWIndexFuture) then //kontrakty
        begin
          if sinfo.GetSeriesForCurrentDownload(dm.qrySpolki.fieldbyname('id').AsInteger, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger)) then
          begin
            for i := 0 to sinfo.Count - 1 do
              FFilesDownloader.DownloadAsync(dm.Settings['PathCiagle2'], dm.qrySpolki.fieldbyname('nazwaakcji').AsString + sinfo[i].series + '.zip', FUnzipDir);
          end;
        end;
      end;
      dm.qrySpolki.Next;
    end;
    FFilesDownloader.StartAsyncDownload; //odpalenie watku sciagajacego pliki

    dm.RefreshQuery(dm.qrySpolki);
    dm.qrySpolki.First;
    while (not dm.qrySpolki.Eof) and (not FBreakLoad) do
    begin
      application.ProcessMessages;
      if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
      begin
        if dm.qrySpolki.fieldbyname('typ').asinteger in [Ord(motGPWStock), Ord(motGPWIndex)] then
        begin
          lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaspolki').AsString]);
          fn:=dm.qrySpolki.fieldbyname('nazwaakcji').AsString + '.zip';
          datafn:=dm.qrySpolki.fieldbyname('nazwaakcji').AsString + '.prn';
          if FFilesDownloader.WaitAndUnzipAsyncFile(fn) then
          begin
            if FDataInserter.InsertData(modataTicks, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger), dm.qrySpolki.fieldbyname('id').AsInteger, FUnzipDir + datafn) then
              DeleteFile( FUnzipDir + fn ) //usuwamy plik zip
            else
              mmUpdateLog.Lines.Add(format('[id=%d] %s', [dm.qrySpolki.fieldbyname('id').AsInteger, FDataInserter.ErrMsg]));
          end
          else
            mmUpdateLog.Lines.Add(format('! brak pliku: %s', [fn]));
        end
        else if dm.qrySpolki.fieldbyname('typ').asinteger=Ord(motGPWIndexFuture) then
        begin
          lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString]);
          if sinfo.GetSeriesForCurrentDownload(dm.qrySpolki.fieldbyname('id').AsInteger, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger)) then
          begin
            for i := 0 to sinfo.Count - 1 do
            begin
              if FBreakLoad then break;
              fn:=dm.qrySpolki.fieldbyname('nazwaakcji').AsString + sinfo[i].series + '.zip';
              datafn:=dm.qrySpolki.fieldbyname('nazwaakcji').AsString + sinfo[i].series + '.prn';
              if FFilesDownloader.WaitAndUnzipAsyncFile(fn) then
              begin
                if FDataInserter.InsertData(modataTicks, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger), dm.qrySpolki.fieldbyname('id').AsInteger, FUnzipDir + datafn, sinfo[i].expiration + 1) then
                  DeleteFile( FUnzipDir + fn ) //usuwamy plik zip
                else
                  mmUpdateLog.Lines.Add(format('[id=%d, %s] %s', [dm.qrySpolki.fieldbyname('id').AsInteger, sinfo[i].series, FDataInserter.ErrMsg]));
              end
              else
                mmUpdateLog.Lines.Add(format('! brak pliku: %s', [fn]));
            end;
          end
          else
            mmUpdateLog.Lines.Add(sinfo.ErrMsg);
        end;
      end;
      dm.qrySpolki.Next;
    end;
  finally
    sinfo.Free;
  end;
  if not FBreakLoad then FFilesDownloader.StopAsyncDownload;  //break zatrzymuje download na nacisnieciu przycisku, wiec tu bedzie pozniej
end;

end.
