unit U_FormMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, ActnList, ZipMstr, u_bgndloaderthread,
  U_FilesDownloader, U_DataInserter, U_DataGenerator;

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
    procedure FormCreate(Sender: TObject);
    procedure actDLDzienneExecute(Sender: TObject);
    procedure actDLCiagleExecute(Sender: TObject);
    procedure actDLBreakExecute(Sender: TObject);
    procedure actGenIntraWeekExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure actGenMPExecute(Sender: TObject);
    procedure actGenBreakExecute(Sender: TObject);
  private
    Zip: TZipMaster;
    FBreakLoad : boolean;
    BgndLoaderThr : TBgndLoaderThread;
    FFilesDownloader : TFilesDownloader;
    FDataInserter : TDataInserter;
    FDataGenerator : TDataGenerator;
    FUnzipDir : string; 

    procedure LoadSpolki;

    //procedury genrujace MP
    procedure GenMPDzienne( idspolki, typ : integer );

    //automatyczne wciagnie danych na podst DataPumpAuto.ini
    procedure AutomaticProcess;

    procedure UpdateStanCaption(AMsg : string);
    //datainserter events
    procedure OnInsertProgress(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALinesPerSec : double; ALongEvent : boolean; var VDoBreak : boolean);
    procedure OnInsertFinished(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALinesPerSec : double; ALongEvent : boolean; var VDoBreak : boolean);
    //datagenerator events
    procedure OnGenerateProgress(ACurrTS : string; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean);
    procedure OnGenerateFinished(ACurrTS : string; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean);
    //async download events
    procedure OnCheckDownloadBreak(var VBreakLoad : boolean);
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

  Zip:=TZipMaster.Create(nil);
  caption:=application.Title;
  pgcMain.ActivePageIndex:=0;
  LoadSpolki;

  if ParamStr(1)='datapumpauto' then
    PostMessage( Handle, MSG_AUTOMATICPROCESS, 0,0);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  Zip.Free;
  FDataGenerator.Free;
  FDataInserter.Free;
  FFilesDownloader.Free;
end;

procedure TFormMain.actDLDzienneExecute(Sender: TObject);
const
  Q_SPOLKI012 = 'select * from at_spolki where typ in (0,1,2) order by typ, id';
//  Q_SPOLKI012 = 'select * from at_spolki where typ in (0,1,2) and id=288 order by typ, id';
  Q_SPOLKI4 = 'select * from at_spolki where typ=4 order by typ, id';
  Q_SPOLKI5 = 'select * from at_spolki where typ=5 order by typ, id';
  Q_SPOLKI6 = 'select * from at_spolki where typ=6 order by typ, id';
var
  typ : integer;

  procedure GetDzienneData( param, zipfn : string; query : string );
  var
    datafn : string;
  begin
    UpdateStanCaption('Pobieranie...');
    FFilesDownloader.DownloadAndUnzip(dm.Settings[param], zipfn, FUnzipDir);

    UpdateStanCaption('Przetwarzanie...');
    dm.OpenQuery(dm.qrySpolki, query);
    dm.qrySpolki.First;
    while (not dm.qrySpolki.Eof) and (not FBreakLoad) do
    begin
      Application.ProcessMessages;
      if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
      begin
        datafn:=FUnzipDir + dm.qrySpolki.fieldbyname('nazwaakcji2').AsString + '.mst';
        lblLPSpolka.Caption:=format('(%d/%d) %s [%d]', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaspolki').AsString, dm.qrySpolki.fieldbyname('id').AsInteger]);
        FDataInserter.InsertData(modataDaily, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger), dm.qrySpolki.fieldbyname('id').AsInteger, datafn);
      end;
      dm.qrySpolki.Next;
    end;
    dm.qrySpolki.Close;
    ClearDir(FUnzipDir, false); //czyscimy katalog downloadu
    UpdateStanCaption('');
  end;
begin
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  lblLPSpolka.Caption:=''; lblLPStan.Caption:='';
  mmUpdateLog.Clear;
  mmUpdateLog.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;
  Application.ProcessMessages;

  ForceDirectories(FUnzipDir);
  typ:=cbDaneDzienne.ItemIndex;
    //dane dzienne typ 0,1,2
  if (typ in [0,1]) and (not FBreakLoad) then
  begin
    mmUpdateLog.Lines.Add('+++ typ 0,1,2');
    GetDzienneData('PathDzienne0', 'mstall.zip', Q_SPOLKI012);
  end;
    //dane dzienne typ 4 (fio)
  if (typ in [0,2]) and (not FBreakLoad) then
  begin
    mmUpdateLog.Lines.Add('+++ typ 4');
    GetDzienneData('PathDzienne4', 'mstfun.zip', Q_SPOLKI4);
  end;
    //dane dzienne typ 5 (waluty nbp)
  if (typ in [0,3]) and (not FBreakLoad) then
  begin
    mmUpdateLog.Lines.Add('+++ typ 5');
    GetDzienneData('PathDzienne5', 'mstnbp.zip', Q_SPOLKI5);
  end;
    //dane dzienne typ 6 (fx)
  if (typ in [0,4]) and (not FBreakLoad) then
  begin
    mmUpdateLog.Lines.Add('+++ typ 6');
    GetDzienneData('PathDzienne6', 'mstfx.zip', Q_SPOLKI6);
  end;

  FDataInserter.UpdateAllStartTS;
  mmUpdateLog.Lines.Add('+++ Stop: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  MessageDlg('Pobieranie danych dziennych zakoñczone', mtInformation, [mbOK], 0);
end;

procedure TFormMain.UpdateStanCaption(AMsg: string);
begin
  lblLPStan.Caption:=AMsg;
  Application.ProcessMessages;
end;

procedure TFormMain.actDLCiagleExecute(Sender: TObject);
const
  Q_SPOLKI = 'select * from at_spolki order by typ, id';
//  Q_SPOLKI = 'select * from at_spolki where id=288 order by typ, id'; //WIG
//  Q_SPOLKI = 'select * from at_spolki where id=1039 order by typ, id'; //FW20WS20
var
  fn, datafn : string;
  sinfo : TSeriesInfo;
  i : integer;
begin
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  lblLPSpolka.Caption:=''; lblLPStan.Caption:='';
  mmUpdateLog.Clear;
  mmUpdateLog.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;

  sinfo:=TSeriesInfo.Create;
  try
    dm.OpenQuery(dm.qrySpolki, Q_SPOLKI);
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
    dm.qrySpolki.Close;

    if not FBreakLoad then FFilesDownloader.StopAsyncDownload;  //break zatrzymuje download na nacisnieciu przycisku, wiec tu bedzie pozniej
    ClearDir(FUnzipDir, false); //czyscimy katalog downloadu
  finally
    sinfo.Free;
  end;
  
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
//const
//  Q_STOCKINFO = 'select * from at_spolki where nazwaspolki=''%s''';
//  Q_MAXTSFUT = 'select max(ts) from at_ciagle2 where fk_id_spolki=%d';
//  Q_FIRSTBIEZACA = 'select min(biezaca) from at_serie where fk_id_spolki=%d';
//var
//  ini : TIniFile;
//  sl, sl2, slintra, slfutfiles : TStringList;
//  i,j : integer;
//  stockid, stocktype : integer;
//  fn, fn2 : string;
//  fd : TFutData;
//  maxts, currts : double;
begin
//  currts:=now;
//    //pobranie plikow danych dziennych
//  fn:=FUnzipDir+'mstall.zip';
//  GetInetFile(dm.Settings['PathDzienne0'] + 'mstall.zip', fn);
//  PrepareZIPFile(fn);
//  fn:=FUnzipDir+'mstfun.zip';
//  GetInetFile(dm.Settings['PathDzienne4'] + 'mstfun.zip', fn);
//  PrepareZIPFile(fn);
//
//
//  sl:=TStringList.Create; sl2:=TStringList.Create; slintra:=TStringList.Create; slfutfiles:=TStringList.Create;
//  ini:=TIniFile.Create(extractfilepath(paramstr(0)) + 'DataPumpAuto.ini');
//  ini.ReadSections(sl);
//  for i:=0 to sl.Count-1 do
//  begin
//    ini.ReadSectionValues(sl[i], sl2);
//    lblLPSpolka.Caption:=sl2.Values['stock'];
//
//    dm.OpenQuery(dm.qrySpolki, format(Q_STOCKINFO,[sl2.Values['stock']]));
//    stockid:=dm.qrySpolki.fieldbyname('id').AsInteger;
//    stocktype:=dm.qrySpolki.fieldbyname('typ').AsInteger;
//
//      //import danych dziennych
//    dm.qrySpolki.First;
//    UpdateData(1);
//      //import danych ciaglych
//    dm.qrySpolki.First;
//    if stocktype in [0,1] then  //spolki,indeksy
//    begin
//      fn:=dm.Settings[format('PathCiagle%d',[stocktype])] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
//      fn2:=FUnzipDir+dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
//      GetInetFile(fn, fn2);
//      PrepareZIPFile( fn2 );
//      UpdateData(0);
//    end;
//    if stocktype=2 then  //kontrakty
//    begin
//      dm.OpenQuery(dm.qryTemp, format(Q_MAXTSFUT,[stockid]));
//      maxts:=dm.qryTemp.Fields[0].AsDateTime;
//      dm.qryTemp.Close;
////      if maxts=0 then maxts:=StrToDate('2000-01-01');
//      if maxts=0 then
//      begin
////          maxts:=StrToDate('2000-01-01');
//        dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
//        maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
//      end;
//        //lista plikow serii
//      slfutfiles.Clear;
//      fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
//      if fd.series<>'' then
//      begin
//        slfutfiles.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series);
//        maxts:=fd.expiration + 1;
//        while fd.expiration<currts do
//        begin
//          fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
//          if fd.series='' then break;
//          slfutfiles.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series);
//        end;
//      end;
//      for j:=0 to slfutfiles.Count-1 do
//        GetInetFile( dm.Settings['PathCiagle2']+slfutfiles[j]+'.zip', FUnzipDir+slfutfiles[j]+'.zip' );
//        //wciagniecie danych fut
//      dm.OpenQuery(dm.qryTemp, format(Q_MAXTSFUT,[stockid]));
//      maxts:=dm.qryTemp.Fields[0].AsDateTime;
//      dm.qryTemp.Close;
////      if maxts=0 then maxts:=StrToDate('2000-01-01');
//      if maxts=0 then
//      begin
////          maxts:=StrToDate('2000-01-01');
//        dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
//        maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
//      end;
//      fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
//      if fd.series<>'' then
//      begin
//        fn:=FUnzipDir+ dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
//        UpdateDataFut0(fn, maxts, fd.expiration+1);
//        maxts:=fd.expiration + 1;
//        while fd.expiration<currts do
//        begin
//          fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
//          if fd.series='' then break;
//          fn:=FUnzipDir+ dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
//          UpdateDataFut0(fn, maxts, fd.expiration+1);
//          maxts:=fd.expiration + 1;
//        end;
//      end;
//    end;
//
//    slintra.CommaText:=sl2.Values['ops'];
//      //generowanie danych intra
//    if slintra.IndexOf('intra1m')>-1 then GenIntraMin2(stockid, stocktype, 1);
//    if slintra.IndexOf('intra2m')>-1 then GenIntraMin2(stockid, stocktype, 2);
//    if slintra.IndexOf('intra3m')>-1 then GenIntraMin2(stockid, stocktype, 3);
//    if slintra.IndexOf('intra4m')>-1 then GenIntraMin2(stockid, stocktype, 4);
//    if slintra.IndexOf('intra5m')>-1 then GenIntraMin2(stockid, stocktype, 5);
//    if slintra.IndexOf('intra10m')>-1 then GenIntraMin2(stockid, stocktype, 10);
//    if slintra.IndexOf('intra15m')>-1 then GenIntraMin2(stockid, stocktype, 15);
//    if slintra.IndexOf('intra20m')>-1 then GenIntraMin2(stockid, stocktype, 20);
//    if slintra.IndexOf('intra30m')>-1 then GenIntraMin2(stockid, stocktype, 30);
//    if slintra.IndexOf('intra60m')>-1 then GenIntraMin2(stockid, stocktype, 60);
//
//      //generowanie danych MarketProfile
//    if slintra.IndexOf('mp30')>-1 then GenMPDzienne(stockid, 30);
//
//  end;
//  ini.Free;
//  slfutfiles.Free;
//  slintra.Free;
//  sl2.Free;
//  sl.Free;
//    //posprzatanie w katalogu
//  ClearDir(FUnzipDir, false);
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

end.
