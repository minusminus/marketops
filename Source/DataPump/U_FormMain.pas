unit U_FormMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, ActnList, ZipMstr, u_bgndloaderthread,
  U_FilesDownloader, U_DataInserter;

const
  MSG_AUTOMATICPROCESS = WM_APP + 1000;

type
  TFutData = record
    series : string;
    expiration : tdatetime;
  end;
  
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
    Button5: TButton;
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
    Button7: TButton;
    cbGenType: TComboBox;
    cbDaneDzienne: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure actDLDzienneExecute(Sender: TObject);
    procedure actDLCiagleExecute(Sender: TObject);
    procedure actDLBreakExecute(Sender: TObject);
    procedure actGenIntraWeekExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure actGenMPExecute(Sender: TObject);
    procedure Button7Click(Sender: TObject);
  private
    Zip: TZipMaster;
    FBreakLoad : boolean;
    BgndLoaderThr : TBgndLoaderThread;
    FFilesDownloader : TFilesDownloader;
    FDataInserter : TDataInserter; 

    procedure LoadSpolki;

    {** informacje o aktulanej serii kontraktow dla podanej daty *}
//    function GetCurrFutData( TS : TDateTime ) : TFutData;
    function GetCurrFutData2( FutID : integer; TS : TDateTime ) : TFutData;

    //procedury wciagania danych z bossa.pl
    {*
      update danych
      informacje o spolce ustawione w aktualnym wierszu dm.qrySpolki
      @param typ - 0-ciagle, 1-dzienne
    **}
    procedure UpdateData( typ : integer );
    procedure UpdateDataFut0( datafn : string; startts, expdate : tdatetime );
    {** procedura ustawiajaca pole at_spolki.startts *}
    procedure UpdateStartTS;
    {** procedura przygotowujaca plik do przetwarzania - czeka na pobranie i rozpakowuje *}
    procedure PrepareZIPFile( fn : string );
    procedure WaitForFile( fn : string );
    function PrepareIntVal( val : string ) : string;
    function PrepareFloatVal( val : double ) : string;

    //procedury generujaca dane intra i week+
    procedure GenTyg( idspolki, typ : integer );
    procedure GenMies( idspolki, typ : integer );
    procedure GenIntraMin( idspolki, typ, range : integer );
    procedure GenIntraMin2( idspolki, typ, range : integer );

    //procedury genrujace MP
    procedure GenMPDzienne( idspolki, typ : integer );

    //automatyczne wciagnie danych na podst DataPumpAuto.ini
    procedure AutomaticProcess;

    //datainserter events
    procedure OnInsertProgress(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean);
    procedure OnInsertFinished(ALinesRead : integer; ATimeExpectedToFinish : TDateTime; ALongEvent : boolean; var VDoBreak : boolean);
  protected
    procedure MsgAutomaticProcess( var Msg : TMessage ); message MSG_AUTOMATICPROCESS;
  public
  end;

var
  FormMain: TFormMain;

implementation

uses U_DM, rxfileutil, rxdateutil, rxstrutils,U_InetFile, DateUtils, math,
  DB, U_DataProviderMP, inifiles, U_Consts;

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FFilesDownloader:=TFilesDownloader.Create;
  FDataInserter:=TDataInserter.Create;
  FDataInserter.OnInsertProgress:=OnInsertProgress;
  FDataInserter.OnInsertFinished:=OnInsertFinished;

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
  FDataInserter.Free;
  FFilesDownloader.Free;
end;

procedure TFormMain.actDLDzienneExecute(Sender: TObject);
const
  Q_SPOLKI012 = 'select * from at_spolki where typ in (0,1,2) order by typ, id';
  Q_SPOLKI4 = 'select * from at_spolki where typ=4 order by typ, id';
  Q_SPOLKI5 = 'select * from at_spolki where typ=5 order by typ, id';
  Q_SPOLKI6 = 'select * from at_spolki where typ=6 order by typ, id';
var
  typ : integer;

  procedure GetDzienneData( param, zipfn : string; query : string );
  var
    atunzip : string;
    datafn : string;
  begin
    atunzip:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\';
    FFilesDownloader.DownloadAndUnzip(dm.Settings[param] + zipfn, atunzip);

    dm.OpenQuery(dm.qrySpolki, query);
    dm.qrySpolki.First;
    while (not dm.qrySpolki.Eof) and (not FBreakLoad) do
    begin
      Application.ProcessMessages;
      if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
      begin
        datafn:=atunzip + dm.qrySpolki.fieldbyname('nazwaakcji2').AsString + '.mst';
        lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaspolki').AsString]);
//        UpdateData(1);
        FDataInserter.InsertData(modataDaily, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger), dm.qrySpolki.fieldbyname('id').AsInteger, datafn);
      end;
      dm.qrySpolki.Next;
    end;
    dm.qrySpolki.Close;
    ClearDir(atunzip, false); //czyscimy katalog downloadu
  end;
begin
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  lblLPSpolka.Caption:=''; lblLPStan.Caption:='';
  mmUpdateLog.Clear;
  mmUpdateLog.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;

  ForceDirectories(NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\');

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

procedure TFormMain.UpdateStartTS;
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
begin
  dm.ExecSql(format(Q_QRY, [0]));
  dm.ExecSql(format(Q_QRY, [1]));
  dm.ExecSql(format(Q_QRY, [2]));
  dm.ExecSql(format(Q_QRY, [4]));
  dm.ExecSql(format(Q_QRY, [5]));
  dm.ExecSql(format(Q_QRY, [6]));
end;

procedure TFormMain.WaitForFile(fn: string);
begin
  lblLPStan.Caption:='Pobieranie'; Application.ProcessMessages;
  while not FileExists(fn) do  //czekamy na plik
  begin
    Application.ProcessMessages;
    if FBreakLoad then exit;
    sleep(1000);
  end;
end;

procedure TFormMain.PrepareZIPFile(fn: string);
begin
  lblLPStan.Caption:='Pobieranie'; Application.ProcessMessages;
  while not FileExists(fn) do  //czekamy na plik
  begin
    Application.ProcessMessages;
    sleep(1000);
  end;
  if FBreakLoad then exit;
  if GetFileSize(fn)<300 then exit;
  lblLPStan.Caption:='Rozpakowanie'; Application.ProcessMessages;
  Zip.ZipFileName:=fn;
  Zip.ExtrBaseDir:=NormalDir(extractfilepath(fn));
  Zip.Extract;
  Application.ProcessMessages;
end;

procedure TFormMain.UpdateData(typ: integer);
const
  Q_ADDCIAGLE = 'insert into at_ciagle%d(fk_id_spolki, ts, x, open, high, low, close, volume, oi) values(%d, ''%s'', %s, %s,%s,%s,%s, %s, %s);';
//  Q_UPDATECIAGLEPOS = 'update at_spolki set ciaglepos=%d where id=%d';
  Q_ADDDZIENNE = 'insert into at_dzienne%d(fk_id_spolki, ts, open, high, low, close, volume, refcourse) values(%d, ''%s'', %s,%s,%s,%s, %s, %s );';
  Q_UPDATEDZIENNE = 'update at_dzienne%d set open=%s, high=%s, low=%s, close=%s, volume=%s where fk_id_spolki=%d and ts=''%s''';
//  Q_UPDATEDZIENNEPOS = 'update at_spolki set dziennepos=%d where id=%d';
  Q_MAXTS = 'select max(ts) from at_%s%d where fk_id_spolki=%d';
var
  f : TextFile;
  linescnt, fsize, bread : integer;
  datafn : string;
  sl,sl1 : TStringList;
  cp, i, ilast : integer;
  tlast, t2, d : double;
  s, s1, dt, qry : string;
  refcourse : string;
  maxts : double;
  exc : boolean;

  procedure AddLine( line : string; doupdate : boolean = false );
  begin
    if refcourse='' then refcourse:='0';    

//    sl1.CommaText:=s1;
    sl1.CommaText:=line;
      //budowa stringu daty operacji
    case typ of
      0 : s:=sl1[2];  //ciagle
      1 : s:=sl1[1];  //dzienne
    end;
    dt:=s[1]+s[2]+s[3]+s[4]+'-'+s[5]+s[6]+'-'+s[7]+s[8]+' ';
    if typ=0 then //godzina tylko dla ciaglych
    begin
      s:=sl1[3];
      dt:=dt+s[1]+s[2]+':'+s[3]+s[4]+':'+s[5]+s[6];
    end;

      //budowa zapytania
    case typ of
      0 : //ciagle
        qry:=format(Q_ADDCIAGLE,[
          dm.qrySpolki.fieldbyname('typ').AsInteger,  //odpowiednia tabela w zaleznosci od typu spolki (spolka, indeks, ...)
          dm.qrySpolki.fieldbyname('id').AsInteger,
          dt, sl1[1],
          sl1[4], sl1[5], sl1[6], sl1[7],
          sl1[8], sl1[9]
        ]);
      1 : //dzienne
        if doupdate then
          qry:=format(Q_UPDATEDZIENNE,[
            dm.qrySpolki.fieldbyname('typ').AsInteger,  //odpowiednia tabela w zaleznosci od typu spolki (spolka, indeks, ...)
            sl1[2], sl1[3], sl1[4], sl1[5],
            PrepareIntVal(sl1[6]),
            dm.qrySpolki.fieldbyname('id').AsInteger,
            dt
          ])
        else
          qry:=format(Q_ADDDZIENNE,[
            dm.qrySpolki.fieldbyname('typ').AsInteger,  //odpowiednia tabela w zaleznosci od typu spolki (spolka, indeks, ...)
            dm.qrySpolki.fieldbyname('id').AsInteger,
            dt,
            sl1[2], sl1[3], sl1[4], sl1[5],
            PrepareIntVal(sl1[6]), refcourse
          ]);
    end;
    dm.ExecSql(qry);  //dodanie wiersza do bazy [problem jest zeby zrobic to pakietami np po 100]
    if typ=1 then refcourse:=sl1[5];  //kurs odniesienia dla nastepnego wiersza = kurs zamkniecia dla biezacego
  end;
begin
  exc:=false;
  bread:=0;
  refcourse:='';
  lblLPStan.Caption:='Przetwarzanie';
  case typ of
    0 : datafn:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\'+dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.prn';
    1 : datafn:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\'+dm.qrySpolki.fieldbyname('nazwaakcji2').AsString+'.mst';
  end;
  if not fileexists(datafn) then exit;  //jesli nie ma okreslonego pliku to pomijamy
  fsize:=GetFileSize(datafn);

  sl:=TStringList.Create; sl1:=TStringList.Create;
  fsize:=GetFileSize(datafn);
  AssignFile(f, datafn);
  Reset(f);
  if typ=1 then readln(f, s); //dla danych dziennych usuwamy pierwsza linie

  case typ of
    0 : dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,['ciagle', dm.qrySpolki.fieldbyname('typ').AsInteger, dm.qrySpolki.fieldbyname('id').AsInteger ]));
    1 : dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,['dzienne', dm.qrySpolki.fieldbyname('typ').AsInteger, dm.qrySpolki.fieldbyname('id').AsInteger ]));
  end;
  maxts:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;

  try
      //szukamy podanego maxts
    cp:=0;
    if maxts>0 then
    begin
      case typ of
        0 : dt:=FormatDateTime('yyyymmdd,hhnnss', maxts);
        1 : dt:=FormatDateTime('yyyymmdd', maxts);
      end;
      while not Eof(f) do
      begin
        readln(f, s1);
        bread:=bread + length(s1);
        sl1.CommaText:=s1;
        if (typ=1) then //inicjalizacja kursu odniesienia
        begin
          if cp=0 then refcourse:=sl1[2]  //otwarcie pierwszego dnia notowan
          else refcourse:=sl1[5]; //zamkniecie biezacego
        end;
        inc(cp);
        if pos(dt, s1)>0 then
        begin
          break;
        end;
        if( (typ=1) and (sl1[1]=dt) ) then  //jezeli data identyczna - aktualizujemy biezacy rekord i przetwarzamy kolejne linie
        begin
          AddLine(s1, true);
          break;
        end;
        if ( (typ=0) and ((sl1[2]+','+sl1[3]) > dt) ) or
           ( (typ=1) and (sl1[1] > dt) ) then  //data znaleziona jest wieksza od maxts -> dodajemy nowa linie i reszte pliku
        begin
          AddLine(s1);
          break;
        end;
      end;
    end;

      //przetwarzamy reszte pliku
    ilast:=bread; tlast:=now;
    linescnt:=cp;
    while not Eof(f) do
    begin
      lblLPPostep.Caption:=format('%d',[linescnt]);
      if linescnt and 7 = 7 then Application.ProcessMessages;
      if linescnt and 127 = 127 then  //szacowanie czasu do konca pakietu
      begin
        t2:=now;
        i:=bread;
        if i>ilast then
        begin
          d:=(fsize-i)*(t2-tlast)/(i-ilast);
          lblLPCzasDoKoncaPakietu.Caption:=FormatDateTime('hh:nn:ss',d);
        end;
        ilast:=i; tlast:=t2;
      end;
      if FBreakLoad then break;

      readln(f, s1);
      bread:=bread + length(s1);
      inc(linescnt);
      AddLine(s1);
    end;

    if typ=0 then
  //    mmUpdateLog.Lines.Add(format('%s: %d', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, sl.Count-cp]));
      mmUpdateLog.Lines.Add(format('%s: %d', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, linescnt-cp]));
  except
    on e : Exception do
    begin
      exc:=true;
      mmUpdateLog.Lines.Add(format('%s: blad przetwarzania linia [linescnt=%d, cp=%d]:'+#13#10+'%s', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, linescnt, cp, e.Message]));
    end;
  end;

  sl1.Free; sl.Free;
  CloseFile(f);
  if not exc then DeleteFile(datafn); //usuniecie rozpakowanego pliku
end;

procedure TFormMain.UpdateDataFut0(datafn: string; startts, expdate: tdatetime);
const
  Q_ADDCIAGLE = 'insert into at_ciagle%d(fk_id_spolki, ts, x, open, high, low, close, volume, oi) values(%d, ''%s'', %s, %s,%s,%s,%s, %s, %s);';
//  Q_UPDATECIAGLEPOS = 'update at_spolki set ciaglepos=%d where id=%d';
//  Q_SELECTCIAGLEPOS = 'select ciaglepos from at_spolki where id=%d';
var
  f : TextFile;
  fsize, linescnt, bread : integer;
  sl,sl1 : TStringList;
  cp, i, ilast : integer;
  tlast, t2, d : double;
  s, s1, dt, dtexp, qry : string;
  refcourse : string;
  prnfn : string;
  exc : boolean;

  procedure AddLine( line : string );
  begin
//    sl1.CommaText:=s1;
    sl1.CommaText:=line;
      //budowa stringu daty operacji
    s:=sl1[2];  //ciagle
    dt:=s[1]+s[2]+s[3]+s[4]+'-'+s[5]+s[6]+'-'+s[7]+s[8]+' ';
    s:=sl1[3];
    dt:=dt+s[1]+s[2]+':'+s[3]+s[4]+':'+s[5]+s[6];

      //budowa zapytania
    qry:=format(Q_ADDCIAGLE,[
//      dm.qrySpolki.fieldbyname('typ').AsInteger,  //odpowiednia tabela w zaleznosci od typu spolki (spolka, indeks, ...)
      2,
      dm.qrySpolki.fieldbyname('id').AsInteger,
      dt, sl1[1],
      sl1[4], sl1[5], sl1[6], sl1[7],
      sl1[8], sl1[9]
    ]);
    dm.ExecSql(qry);  //dodanie wiersza do bazy [problem jest zeby zrobic to pakietami np po 100]
  end;
begin
  exc:=false;
  bread:=0;
  refcourse:='';
  if not fileexists(datafn) then exit;  //jesli nie ma okreslonego pliku to pomijamy
  PrepareZIPFile( datafn );
  lblLPStan.Caption:='Przetwarzanie';
  prnfn:=replacestr(datafn, extractfileext(datafn), '.prn');
  if not fileexists(prnfn) then exit;   //jesli plik sie nie rozpakowal to pomijamy go

  sl:=TStringList.Create; sl1:=TStringList.Create;
  fsize:=GetFileSize(prnfn);
  AssignFile(f, prnfn);
  reset(f);

  try
      //szukanie startts
    //mamy nowy plik - szukamy od poczatku pliku pozycji z podana data
    cp:=0;
  //  dt:=format('%.4d%.2d%.2d', [ExtractYear(startts), ExtractMonth(startts), ExtractDay(startts)]);
    dt:=FormatDateTime('yyyymmdd,hhnnss', startts);
    dtexp:=FormatDateTime('yyyymmdd,hhnnss', expdate);
    while not Eof(f) do
    begin
      readln(f, s1);
      bread:=bread + length(s1);
      inc(cp);
      if pos(dt, s1)>0 then
      begin
        break;
      end;
      sl1.CommaText:=s1;
      if (sl1[2]+','+sl1[3]) > dt then  //data znaleziona jest wieksza od startts -> dodajemy nowa linie i reszte pliku
      begin
        if (sl1[2]+','+sl1[3]) < dtexp then
          AddLine(s1);
        break;
      end;
    end;

      //przetwarzanie od nastepnej pozycji
    linescnt:=cp;
    i:=0;
    ilast:=cp; tlast:=now; ilast:=bread;
    while not Eof(f) do
    begin
      lblLPPostep.Caption:=format('%d',[linescnt]);
      if linescnt and 7 = 7 then Application.ProcessMessages;
      if linescnt and 127 = 127 then  //szacowanie czasu do konca pakietu
      begin
        t2:=now;
        i:=bread;
        if i>ilast then
        begin
          d:=(fsize-i)*(t2-tlast)/(i-ilast);
          lblLPCzasDoKoncaPakietu.Caption:=FormatDateTime('hh:nn:ss',d);
        end;
        ilast:=i; tlast:=t2;
      end;
      if FBreakLoad then break;

      readln(f, s1);
      bread:=bread + length(s1);
      inc(linescnt);
      if (sl1[2]+','+sl1[3]) < dtexp then //dodajemy jesli nie przekroczyla daty expiration
        AddLine(s1)
      else
        break;
  //    if i>10 then break;
    end;

    mmUpdateLog.Lines.Add(format('%s: %d', [extractfilename(prnfn), linescnt-cp]));
  except
    on e : Exception do
    begin
      exc:=true;
      mmUpdateLog.Lines.Add(format('%s: blad przetwarzania linia [linescnt=%d, cp=%d]:'+#13#10+'%s', [extractfilename(prnfn), linescnt, cp, e.Message]));
    end;
  end;

  sl1.Free; sl.Free;
  CloseFile(f);
  if not exc then
  begin
    DeleteFile(prnfn); //usuniecie rozpakowanego pliku
    DeleteFile(datafn); //usuniecie rozpakowanego pliku
  end;
end;

function TFormMain.PrepareIntVal(val: string): string;
begin
  result:=val;
  if trim(val)='' then result:='0';
end;

function TFormMain.PrepareFloatVal(val: double): string;
begin
  result:=replacestr(format('%.2f',[val]), ',', '.');
end;

procedure TFormMain.actDLCiagleExecute(Sender: TObject);
const
  Q_SPOLKI = 'select * from at_spolki order by typ, id';
  Q_MAXTS = 'select max(ts) from at_ciagle%d where fk_id_spolki=%d';
  Q_FIRSTBIEZACA = 'select min(biezaca) from at_serie where fk_id_spolki=%d';
  Q_TEST = 'select * from at_spolki where id=344 order by typ, id';
var
  fn : string;
  currts, maxts : tdatetime;
  fd : TFutData;
begin
  currts:=now;
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  mmUpdateLog.Clear;
  mmUpdateLog.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;
  lblLPSpolka.Caption:=''; lblLPStan.Caption:='';

  BgndLoaderThr:=TBgndLoaderThread.Create;
  BgndLoaderThr.DestPath:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\';
  ForceDirectories(BgndLoaderThr.DestPath);

  dm.OpenQuery(dm.qrySpolki, Q_SPOLKI);
//  dm.OpenQuery(dm.qrySpolki, Q_TEST);
  dm.qrySpolki.First;
  while not dm.qrySpolki.Eof do
  begin
    if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
    begin
      if dm.qrySpolki.fieldbyname('typ').AsInteger in [0,1] then  //spolki,indeksy
      begin
        fn:=dm.Settings[format('PathCiagle%d',[dm.qrySpolki.fieldbyname('typ').AsInteger])] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
        BgndLoaderThr.Files.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip='+fn);
      end;
      if dm.qrySpolki.fieldbyname('typ').AsInteger=2 then //kontrakty
      begin
        dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[2, dm.qrySpolki.fieldbyname('id').AsInteger]));
        maxts:=dm.qryTemp.Fields[0].AsDateTime; //ostatni ts z bazy
//        if maxts=0 then maxts:=StrToDate('2000-01-01');
        if maxts=0 then
        begin
//          maxts:=StrToDate('2000-01-01');
          dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
          maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
        end;

          //okreslamy ktore serie musimy pobrac zeby wygenerowac wygasajaca serie
        fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
        if fd.series<>'' then
        begin
          fn:=dm.Settings['PathCiagle2'] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
          BgndLoaderThr.Files.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip=' + fn);
          while fd.expiration<currts do
          begin
            fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
            if fd.series='' then break;
            fn:=dm.Settings['PathCiagle2'] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
            BgndLoaderThr.Files.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip=' + fn);
          end;
        end;
      end;
    end;
    dm.qrySpolki.Next;
  end;
  BgndLoaderThr.Resume; //odpalenie watku sciagajacego pliki

  dm.RefreshQuery(dm.qrySpolki);
  dm.qrySpolki.First;
  while (not dm.qrySpolki.Eof) and (not FBreakLoad) do
  begin
    if FBreakLoad then break;
    application.ProcessMessages;
    if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
    begin
      if dm.qrySpolki.fieldbyname('typ').asinteger in [0,1] then
      begin
//        lblLPSpolka.Caption:=format('%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaspolki').AsString, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
        lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaspolki').AsString]);
        fn:=BgndLoaderThr.DestPath+dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
        PrepareZIPFile( fn );
        UpdateData(0);
        DeleteFile( fn ); //usuwamy plik zip
      end;
      if dm.qrySpolki.fieldbyname('typ').asinteger=2 then
      begin
//        lblLPSpolka.Caption:=format('%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
        lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString]);
        dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[2, dm.qrySpolki.fieldbyname('id').AsInteger]));
        maxts:=dm.qryTemp.Fields[0].AsDateTime; //ostatni ts z bazy
//        if maxts=0 then maxts:=StrToDate('2000-01-01');
        if maxts=0 then
        begin
//          maxts:=StrToDate('2000-01-01');
          dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
          maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
        end;
          //okreslamy ktore serie musimy pobrac zeby wygenerowac wygasajaca serie
        fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
        if fd.series<>'' then
        begin
  //        lblLPSpolka.Caption:=format('%s%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
          lblLPSpolka.Caption:=format('(%d/%d) %s%s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series]);
          fn:=BgndLoaderThr.DestPath + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
          WaitForFile(fn);  //czekamy na plik z danymi
          UpdateDataFut0(fn, maxts, fd.expiration+1);
          maxts:=fd.expiration + 1;
          while fd.expiration<currts do
          begin
            if FBreakLoad then break;
            fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
            if fd.series='' then break;            
  //          lblLPSpolka.Caption:=format('%s%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
            lblLPSpolka.Caption:=format('(%d/%d) %s%s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series]);
            fn:=BgndLoaderThr.DestPath + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
            WaitForFile(fn);  //czekamy na plik z danymi
            UpdateDataFut0(fn, maxts, fd.expiration+1);
            maxts:=fd.expiration + 1;
          end;
        end;
      end;
    end;
    dm.qrySpolki.Next;
  end;
  dm.qrySpolki.Close;

  if not BgndLoaderThr.Suspended then
  begin
    BgndLoaderThr.Terminate;
    BgndLoaderThr.WaitFor;
  end;
  ClearDir(BgndLoaderThr.DestPath, false); //czyscimy katalog downloadu
  BgndLoaderThr.Free;
  BgndLoaderThr:=nil;

  UpdateStartTS;  //pole at_spolki.startts
  mmUpdateLog.Lines.Add('+++ Stop: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  MessageDlg('Pobieranie danych ci¹g³ych zakoñczone', mtInformation, [mbOK], 0);
end;

procedure TFormMain.actDLBreakExecute(Sender: TObject);
begin
  FBreakLoad:=true;
end;

procedure TFormMain.actGenIntraWeekExecute(Sender: TObject);
const
  Q_GETTYP = 'select typ from at_spolki where id=%d';
  Q_GETSTOCKS = 'select id, nazwaspolki from at_spolki where typ=%d and aktywna=TRUE';
var
  id, typ : integer;

  procedure CallGen;
  begin
    if typ>0 then
      case cbGenDataType.ItemIndex of
        0 : GenTyg(id, typ);
        1 : GenMies(id, typ);
        2 : GenIntraMin2(id, typ, 1);//  1 min
        3 : GenIntraMin2(id, typ, 2);//  2 min
        4 : GenIntraMin2(id, typ, 3);//  3 min
        5 : GenIntraMin2(id, typ, 4);//  4 min
        6 : GenIntraMin2(id, typ, 5);//  5 min
        7 : GenIntraMin2(id, typ, 10);//  10 min
        8 : GenIntraMin2(id, typ, 15);//  15 min
        9 : GenIntraMin2(id, typ, 20);//  20 min
        10: GenIntraMin2(id, typ, 30);//  30 min
        11: GenIntraMin2(id, typ, 60);//  60 min
      end;
  end;
begin
  lblGenProg.Caption:='';
  mmLogGen.Lines.Add('Start');
  application.ProcessMessages;
    //wybrana spolka
  if (cbGenType.ItemIndex=0) and (cbSpolka.Items.Objects[cbSpolka.ItemIndex]<>nil) then
  begin
    id:=Integer(cbSpolka.Items.Objects[cbSpolka.ItemIndex]);
    dm.OpenQuery(dm.qryTemp, format(Q_GETTYP, [id]));
    typ:=dm.qryTemp.Fields[0].AsInteger;
    dm.qryTemp.Close;
    CallGen;
  end;
    //wszystkie spolki
  if cbGenType.ItemIndex=1 then
  begin
  end;

    //poszczegolne typy
  if cbGenType.ItemIndex in [2,3,4,5,6,7] then
  begin
    case cbGenType.ItemIndex of
      2 : typ:=0;
      3 : typ:=1;
      4 : typ:=2;
      5 : typ:=4;
      6 : typ:=5;
      7 : typ:=6;
    end;
    dm.OpenQuery(dm.qryTemp3, format(Q_GETSTOCKS, [typ]));
    dm.qryTemp3.First;
    while not dm.qryTemp3.Eof do
    begin
      mmLogGen.Lines.Add(dm.qryTemp3.Fields[1].AsString);
      Application.ProcessMessages;
      
      id:=dm.qryTemp3.Fields[0].AsInteger;
      CallGen;
      dm.qryTemp3.Next;
    end;
    dm.qryTemp3.Close;
  end;  

  mmLogGen.Lines.Add('Stop');
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
  Q_STOCKINFO = 'select * from at_spolki where nazwaspolki=''%s''';
  Q_MAXTSFUT = 'select max(ts) from at_ciagle2 where fk_id_spolki=%d';
  Q_FIRSTBIEZACA = 'select min(biezaca) from at_serie where fk_id_spolki=%d';
var
  ini : TIniFile;
  sl, sl2, slintra, slfutfiles : TStringList;
  i,j : integer;
  stockid, stocktype : integer;
  fn, fn2 : string;
  fd : TFutData;
  maxts, currts : double;
begin
  currts:=now;
    //pobranie plikow danych dziennych
  fn:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\'+'mstall.zip';
  GetInetFile(dm.Settings['PathDzienne0'] + 'mstall.zip', fn);
  PrepareZIPFile(fn);
  fn:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\'+'mstfun.zip';
  GetInetFile(dm.Settings['PathDzienne4'] + 'mstfun.zip', fn);
  PrepareZIPFile(fn);


  sl:=TStringList.Create; sl2:=TStringList.Create; slintra:=TStringList.Create; slfutfiles:=TStringList.Create;
  ini:=TIniFile.Create(extractfilepath(paramstr(0)) + 'DataPumpAuto.ini');
  ini.ReadSections(sl);
  for i:=0 to sl.Count-1 do
  begin
    ini.ReadSectionValues(sl[i], sl2);
    lblLPSpolka.Caption:=sl2.Values['stock'];

    dm.OpenQuery(dm.qrySpolki, format(Q_STOCKINFO,[sl2.Values['stock']]));
    stockid:=dm.qrySpolki.fieldbyname('id').AsInteger;
    stocktype:=dm.qrySpolki.fieldbyname('typ').AsInteger;

      //import danych dziennych
    dm.qrySpolki.First;
    UpdateData(1);
      //import danych ciaglych
    dm.qrySpolki.First;
    if stocktype in [0,1] then  //spolki,indeksy
    begin
      fn:=dm.Settings[format('PathCiagle%d',[stocktype])] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
      fn2:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\'+dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
      GetInetFile(fn, fn2);
      PrepareZIPFile( fn2 );
      UpdateData(0);
    end;
    if stocktype=2 then  //kontrakty
    begin
      dm.OpenQuery(dm.qryTemp, format(Q_MAXTSFUT,[stockid]));
      maxts:=dm.qryTemp.Fields[0].AsDateTime;
      dm.qryTemp.Close;
//      if maxts=0 then maxts:=StrToDate('2000-01-01');
      if maxts=0 then
      begin
//          maxts:=StrToDate('2000-01-01');
        dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
        maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
      end;
        //lista plikow serii
      slfutfiles.Clear;
      fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
      if fd.series<>'' then
      begin
        slfutfiles.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series);
        maxts:=fd.expiration + 1;
        while fd.expiration<currts do
        begin
          fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
          if fd.series='' then break;
          slfutfiles.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series);
        end;
      end;
      for j:=0 to slfutfiles.Count-1 do
        GetInetFile( dm.Settings['PathCiagle2']+slfutfiles[j]+'.zip', ExtractFilePath(ParamStr(0))+'ATunzip\'+slfutfiles[j]+'.zip' );
        //wciagniecie danych fut
      dm.OpenQuery(dm.qryTemp, format(Q_MAXTSFUT,[stockid]));
      maxts:=dm.qryTemp.Fields[0].AsDateTime;
      dm.qryTemp.Close;
//      if maxts=0 then maxts:=StrToDate('2000-01-01');
      if maxts=0 then
      begin
//          maxts:=StrToDate('2000-01-01');
        dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
        maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
      end;
      fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
      if fd.series<>'' then
      begin
        fn:=ExtractFilePath(ParamStr(0))+'ATunzip\'+ dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
        UpdateDataFut0(fn, maxts, fd.expiration+1);
        maxts:=fd.expiration + 1;
        while fd.expiration<currts do
        begin
          fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
          if fd.series='' then break;
          fn:=ExtractFilePath(ParamStr(0))+'ATunzip\'+ dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
          UpdateDataFut0(fn, maxts, fd.expiration+1);
          maxts:=fd.expiration + 1;
        end;
      end;
    end;

    slintra.CommaText:=sl2.Values['ops'];
      //generowanie danych intra
    if slintra.IndexOf('intra1m')>-1 then GenIntraMin2(stockid, stocktype, 1);
    if slintra.IndexOf('intra2m')>-1 then GenIntraMin2(stockid, stocktype, 2);
    if slintra.IndexOf('intra3m')>-1 then GenIntraMin2(stockid, stocktype, 3);
    if slintra.IndexOf('intra4m')>-1 then GenIntraMin2(stockid, stocktype, 4);
    if slintra.IndexOf('intra5m')>-1 then GenIntraMin2(stockid, stocktype, 5);
    if slintra.IndexOf('intra10m')>-1 then GenIntraMin2(stockid, stocktype, 10);
    if slintra.IndexOf('intra15m')>-1 then GenIntraMin2(stockid, stocktype, 15);
    if slintra.IndexOf('intra20m')>-1 then GenIntraMin2(stockid, stocktype, 20);
    if slintra.IndexOf('intra30m')>-1 then GenIntraMin2(stockid, stocktype, 30);
    if slintra.IndexOf('intra60m')>-1 then GenIntraMin2(stockid, stocktype, 60);

      //generowanie danych MarketProfile
    if slintra.IndexOf('mp30')>-1 then GenMPDzienne(stockid, 30);

  end;
  ini.Free;
  slfutfiles.Free;
  slintra.Free;
  sl2.Free;
  sl.Free;
    //posprzatanie w katalogu
  ClearDir(ExtractFilePath(ParamStr(0))+'ATunzip\', false);
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

procedure TFormMain.OnInsertFinished(ALinesRead: integer;
  ATimeExpectedToFinish: TDateTime; ALongEvent: boolean; var VDoBreak: boolean);
begin
  mmUpdateLog.Lines.Add(format('%s: %d', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, ALinesRead]));
end;

procedure TFormMain.OnInsertProgress(ALinesRead: integer;
  ATimeExpectedToFinish: TDateTime; ALongEvent: boolean; var VDoBreak: boolean);
begin
  if not ALongEvent then
  begin
    lblLPPostep.Caption:=format('%d', [ALinesRead]);
    Application.ProcessMessages;
  end
  else
    lblLPCzasDoKoncaPakietu.Caption:=FormatDateTime('hh:nn:ss', ATimeExpectedToFinish);
  VDoBreak:=FBreakLoad;
end;

function TFormMain.GetCurrFutData2(FutID: integer; TS: TDateTime): TFutData;
const
  Q_QRY = 'select * from at_serie where fk_id_spolki=%d and biezaca<''%s'' and stop>=''%s''';
begin
  ts:=floor(ts);
  result.series:='';
  result.expiration:=0;

  dm.OpenQuery(dm.qryTemp2, format(Q_QRY, [FutID, formatdatetime('yyyy-mm-dd',ts), formatdatetime('yyyy-mm-dd',ts)]));
  if not dm.qryTemp2.Eof then
  begin
    result.expiration:=dm.qryTemp2.fieldbyname('stop').AsDateTime;
//    result.series:=format('%s%.1d',[dm.qryTemp2.fieldbyname('nazwa').AsString, ExtractYear(result.expiration) mod 10]);
    result.series:=dm.qryTemp2.fieldbyname('nazwa').AsString;
  end
  else
  begin
    result.series:='';
//    raise Exception.CreateFmt('Brak informacji o serii dla ID=%d TS=%s', [FutID, formatdatetime('yyyy-mm-dd', TS)]);
    MessageDlg(format('Brak informacji o serii dla ID=%d TS=%s', [FutID, formatdatetime('yyyy-mm-dd', TS)]), mtError, [mbOK], 0);
  end;
  dm.qryTemp2.Close;
end;

procedure TFormMain.GenTyg(idspolki, typ: integer);
const
  Q_QRY1 = 'select * from at_dzienne%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts';
  Q_MAXTS = 'select max(ts) from at_tyg%d where fk_id_spolki=%d';
  Q_MINTS = 'select min(ts) from at_dzienne%d where fk_id_spolki=%d';
  Q_QRYDEL = 'delete from at_tyg%d where fk_id_spolki=%d and ts>=''%s''';
  Q_INS = 'insert into at_tyg%d(fk_id_spolki, ts, open, high, low, close, volume) values(%d, ''%s'', %s, %s, %s, %s, %d)';
var
  dt, dtend : TDateTime;
  i, cnt : integer;
  o,h,l,c : double;
  vol : integer;
begin
  dtend:=floor(now);
  dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[typ, idspolki]));
  dt:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
  if dt=0 then //generujemy dane od poczatku
  begin
    dm.OpenQuery(dm.qryTemp, format(Q_MINTS,[typ, idspolki]));
    dt:=dm.qryTemp.Fields[0].AsDateTime;
    dm.qryTemp.Close;
    if dt=0 then
    begin
      MessageDlg('Nie ma danych dziennych dla spolki '+inttostr(idspolki), mtWarning, [mbOK], 0);
      exit;
    end;
    i:=DayOfTheWeek(dt);
    dt:=dt - (i-1); //poniedzialek pierwszego tygodnia
  end
  else        //generujemy od ostatniego wpisu - usuwajac dane z ostatniego wpisu i generujac je ponownie
  begin
    dm.ExecSql(format(Q_QRYDEL, [typ, idspolki, formatdatetime('yyyy-mm-dd', dt)]));
  end;

  while dt<dtend do
  begin
    o:=0; h:=0; l:=1000000; c:=0; vol:=0;
    dm.OpenQuery(dm.qryTemp, format(Q_QRY1, [typ, idspolki, formatdatetime('yyyy-mm-dd',dt), formatdatetime('yyyy-mm-dd',dt+5)]));
    if not dm.qryTemp.Eof then
    begin
      cnt:=1;
      while not dm.qryTemp.Eof do
      begin
        if cnt=1 then o:=dm.qryTemp.fieldbyname('open').AsFloat;
        c:=dm.qryTemp.fieldbyname('close').AsFloat;

        if h<dm.qryTemp.fieldbyname('high').AsFloat then h:=dm.qryTemp.fieldbyname('high').AsFloat;
        if l>dm.qryTemp.fieldbyname('low').AsFloat then l:=dm.qryTemp.fieldbyname('low').AsFloat;
        vol:=vol + dm.qryTemp.fieldbyname('volume').AsInteger;

        dm.qryTemp.Next;
        inc(cnt);
      end;

      dm.ExecSql(format(Q_INS,[typ, idspolki, formatdatetime('yyyy-mm-dd',dt),
        PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
    end;
    dt:=dt+7; //nast tydzien
  end;
  dm.qryTemp.Close;
end;


procedure TFormMain.GenMies(idspolki, typ: integer);
const
  Q_QRY1 = 'select * from at_dzienne%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts';
  Q_MAXTS = 'select max(ts) from at_mies%d where fk_id_spolki=%d';
  Q_MINTS = 'select min(ts) from at_dzienne%d where fk_id_spolki=%d';
  Q_QRYDEL = 'delete from at_mies%d where fk_id_spolki=%d and ts>=''%s''';
  Q_INS = 'insert into at_mies%d(fk_id_spolki, ts, open, high, low, close, volume) values(%d, ''%s'', %s, %s, %s, %s, %d)';
var
  dt, dtend : TDateTime;
  i, cnt : integer;
  o,h,l,c : double;
  vol : integer;
begin
  dtend:=floor(now);
  dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[typ, idspolki]));
  dt:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
  if dt=0 then //generujemy dane od poczatku
  begin
    dm.OpenQuery(dm.qryTemp, format(Q_MINTS,[typ, idspolki]));
    dt:=dm.qryTemp.Fields[0].AsDateTime;
    dm.qryTemp.Close;
    if dt=0 then
    begin
      MessageDlg('Nie ma danych dziennych dla spolki '+inttostr(idspolki), mtWarning, [mbOK], 0);
      exit;
    end;
    dt:=dt - DayOfTheMonth(dt) + 1; //pierwszy dzien miesiaca
  end
  else        //generujemy od ostatniego wpisu - usuwajac dane z ostatniego wpisu i generujac je ponownie
  begin
    dm.ExecSql(format(Q_QRYDEL, [typ, idspolki, formatdatetime('yyyy-mm-dd', dt)]));
  end;

  while dt<dtend do
  begin
    o:=0; h:=0; l:=1000000; c:=0; vol:=0;
    dm.OpenQuery(dm.qryTemp, format(Q_QRY1, [typ, idspolki, formatdatetime('yyyy-mm-dd',dt), formatdatetime('yyyy-mm-dd',IncMonth(dt,1))]));
    if not dm.qryTemp.Eof then
    begin
      cnt:=1;
      while not dm.qryTemp.Eof do
      begin
        if cnt=1 then o:=dm.qryTemp.fieldbyname('open').AsFloat;
        c:=dm.qryTemp.fieldbyname('close').AsFloat;

        if h<dm.qryTemp.fieldbyname('high').AsFloat then h:=dm.qryTemp.fieldbyname('high').AsFloat;
        if l>dm.qryTemp.fieldbyname('low').AsFloat then l:=dm.qryTemp.fieldbyname('low').AsFloat;
        vol:=vol + dm.qryTemp.fieldbyname('volume').AsInteger;

        dm.qryTemp.Next;
        inc(cnt);
      end;

      dm.ExecSql(format(Q_INS,[typ, idspolki, formatdatetime('yyyy-mm-dd',dt),
        PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
    end;
    dt:=IncMonth(dt,1); //nast miesiac
  end;
  dm.qryTemp.Close;
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

procedure TFormMain.GenIntraMin(idspolki, typ, range: integer);
const
  Q_QRY1 = 'select * from at_ciagle%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts';
  Q_MAXTS = 'select max(ts) from at_%s%d where fk_id_spolki=%d';
  Q_MINTS = 'select min(ts) from at_ciagle%d where fk_id_spolki=%d';
  Q_QRYDEL = 'delete from at_%s%d where fk_id_spolki=%d and ts>=''%s''';
  Q_INS = 'insert into at_%s%d(fk_id_spolki, ts, open, high, low, close, volume) values(%d, ''%s'', %s, %s, %s, %s, %d)';
var
  tbl : string;
  rangeadd, rangemul : double;
  dt, dtend, dtintra : TDateTime;
  i, cnt : integer;
  o,h,l,c : double;
  vol : integer;
begin
  case range of //nazwa tabeli
    1 : tbl:='intra1m';
    2 : tbl:='intra2m';
    3 : tbl:='intra3m';
    4 : tbl:='intra4m';
    5 : tbl:='intra5m';
    10 : tbl:='intra10m';
    15 : tbl:='intra15m';
    20 : tbl:='intra20m';
    30 : tbl:='intra30m';
    60 : tbl:='intra60m';
  end;
//  rangeadd:=(1.0/24.0/60.0)*range;  //modyfikator daty do nastepnego zakresu
  rangeadd:=range;
  rangemul:=24.0*60;

  dtend:=ceil(now);
  dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[tbl, typ, idspolki]));
  dt:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
  if dt=0 then //generujemy dane od poczatku
  begin
    dm.OpenQuery(dm.qryTemp, format(Q_MINTS,[typ, idspolki]));
    dt:=dm.qryTemp.Fields[0].AsDateTime;
    dm.qryTemp.Close;
    if dt=0 then
    begin
      MessageDlg('Nie ma danych ciaglych dla spolki '+inttostr(idspolki), mtWarning, [mbOK], 0);
      exit;
    end;
  end
  else        //generujemy od ostatniego wpisu - usuwajac dane z ostatniego dnia i generujac je ponownie
  begin
    dm.ExecSql(format(Q_QRYDEL, [tbl, typ, idspolki, formatdatetime('yyyy-mm-dd', dt)]));
  end;
  dt:=floor(dt);  //poczatek pierwszego dnia danych

  while dt<dtend do
  begin
    o:=0; h:=0; l:=1000000; c:=0; vol:=0;
    dm.OpenQuery(dm.qryTemp, format(Q_QRY1, [typ, idspolki, formatdatetime('yyyy-mm-dd',dt), formatdatetime('yyyy-mm-dd',dt+1)]));
    if not dm.qryTemp.Eof then
    begin
//      dtintra:=dt;
      dtintra:=floor(dt * rangemul);
      cnt:=1;
      while not dm.qryTemp.Eof do //przejscie po wszystkich zakresach w ciagu dnia. jesli nie ma danych zakres jest pomijany (o=0)
      begin
//        if dtintra + rangeadd < dm.qryTemp.FieldByName('ts').AsDateTime then  //nast dane juz z nastepnego zakresu
        if (dtintra + rangeadd) < (dm.qryTemp.FieldByName('ts').AsDateTime * rangemul) then  //nast dane juz z nastepnego zakresu
        begin
          if o>0 then //dodajemy dane
          begin
//            dm.ExecSql(format(Q_INS,[tbl, typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dtintra),
//              PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
            dm.ExecSql(format(Q_INS,[tbl, typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dtintra/rangemul),
              PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
          end;
          o:=0; h:=0; l:=1000000; c:=0; vol:=0;
          cnt:=1;
          dtintra:=floor(dtintra + rangeadd);
        end
        else                                                                  //ciagle w tym samym zakresie
        begin
          if cnt=1 then o:=dm.qryTemp.fieldbyname('open').AsFloat;
          c:=dm.qryTemp.fieldbyname('close').AsFloat;

          if h<dm.qryTemp.fieldbyname('high').AsFloat then h:=dm.qryTemp.fieldbyname('high').AsFloat;
          if l>dm.qryTemp.fieldbyname('low').AsFloat then l:=dm.qryTemp.fieldbyname('low').AsFloat;
          vol:=vol + dm.qryTemp.fieldbyname('volume').AsInteger;

          dm.qryTemp.Next;
          inc(cnt);
        end;
      end;
      if o>0 then //dodajemy dane z ostatniej swieczki
      begin
//        dm.ExecSql(format(Q_INS,[tbl, typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dtintra),
//          PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
        dm.ExecSql(format(Q_INS,[tbl, typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dtintra/rangemul),
          PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
      end;
    end;
    dt:=dt + 1; //nast dzien
  end;
  dm.qryTemp.Close;
end;

procedure TFormMain.GenIntraMin2(idspolki, typ, range: integer);
const
  Q_QRY1 = 'select count(*), min(low), max(high), sum(volume) from at_ciagle%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s''';
  Q_QRY2 = 'select * from at_ciagle%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts asc limit 1';
  Q_QRY3 = 'select * from at_ciagle%d where fk_id_spolki=%d and ts>=''%s'' and ts<''%s'' order by ts desc limit 1';

  Q_MAXTS = 'select max(ts) from at_%s%d where fk_id_spolki=%d';
  Q_MINTS = 'select min(ts) from at_ciagle%d where fk_id_spolki=%d';
  Q_QRYDEL = 'delete from at_%s%d where fk_id_spolki=%d and ts>=''%s''';
  Q_INS = 'insert into at_%s%d(fk_id_spolki, ts, open, high, low, close, volume) values(%d, ''%s'', %s, %s, %s, %s, %d)';
var
  tbl : string;
  rangeadd, rangemul : double;
  dt, dt2, dtend : TDateTime;
  i, cnt : integer;
  o,h,l,c : double;
  vol : integer;
begin
  case range of //nazwa tabeli
    1 : tbl:='intra1m';
    2 : tbl:='intra2m';
    3 : tbl:='intra3m';
    4 : tbl:='intra4m';
    5 : tbl:='intra5m';
    10 : tbl:='intra10m';
    15 : tbl:='intra15m';
    20 : tbl:='intra20m';
    30 : tbl:='intra30m';
    60 : tbl:='intra60m';
  end;

  dtend:=ceil(now);
  dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[tbl, typ, idspolki]));
  dt:=dm.qryTemp.Fields[0].AsDateTime;
  dm.qryTemp.Close;
  if dt=0 then //generujemy dane od poczatku
  begin
    dm.OpenQuery(dm.qryTemp, format(Q_MINTS,[typ, idspolki]));
    dt:=dm.qryTemp.Fields[0].AsDateTime;
    dm.qryTemp.Close;
    if dt=0 then
    begin
      MessageDlg('Nie ma danych ciaglych dla spolki '+inttostr(idspolki), mtWarning, [mbOK], 0);
      exit;
    end;
  end
  else        //generujemy od ostatniego wpisu - usuwajac dane z ostatniego dnia i generujac je ponownie
  begin
    dm.ExecSql(format(Q_QRYDEL, [tbl, typ, idspolki, formatdatetime('yyyy-mm-dd', dt)]));
  end;
  dt:=floor(dt);  //poczatek pierwszego dnia danych

  i:=0;
  while dt<dtend do
  begin
    lblGenProg.Caption:=formatdatetime('yyyy-mm-dd hh:nn', dt);
    if (i and 63)>0 then application.ProcessMessages;
    
    dt2:=IncMinute(dt,range);
    dm.OpenQuery(dm.qryTemp, format(Q_QRY1, [typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dt), formatdatetime('yyyy-mm-dd hh:nn', dt2)]));
    cnt:=dm.qryTemp.Fields[0].AsInteger;
    l:=dm.qryTemp.Fields[1].AsFloat;
    h:=dm.qryTemp.Fields[2].AsFloat;
    vol:=dm.qryTemp.Fields[3].AsInteger;
    if cnt>0 then //sa dane w tym zakresie
    begin
      dm.OpenQuery(dm.qryTemp, format(Q_QRY2, [typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dt), formatdatetime('yyyy-mm-dd hh:nn',dt2)]));
      o:=dm.qryTemp.FieldByName('open').AsFloat;
      dm.OpenQuery(dm.qryTemp, format(Q_QRY3, [typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dt), formatdatetime('yyyy-mm-dd hh:nn',dt2)]));
      c:=dm.qryTemp.FieldByName('close').AsFloat;

      dm.ExecSql(format(Q_INS,[tbl, typ, idspolki, formatdatetime('yyyy-mm-dd hh:nn',dt),
        PrepareFloatVal(o), PrepareFloatVal(h), PrepareFloatVal(l), PrepareFloatVal(c), vol]));
    end;
    dt:=dt2;
    inc(i);
  end;
  dm.qryTemp.Close;
end;

procedure TFormMain.Button5Click(Sender: TObject);
begin
//  GenIntraMin(6,2, 60);
//  MessageDlg('zrobione', mtWarning, [mbOK], 0);
end;

procedure TFormMain.Button7Click(Sender: TObject);
const
  Q_SPOLKI = 'select * from at_spolki order by typ, id';
  Q_MAXTS = 'select max(ts) from at_ciagle%d where fk_id_spolki=%d';
  Q_FIRSTBIEZACA = 'select min(biezaca) from at_serie where fk_id_spolki=%d';
  Q_TEST = 'select * from at_spolki where id=344 order by typ, id';
var
  fn : string;
  currts, maxts : tdatetime;
  fd : TFutData;
begin
  currts:=now;
  lblLPPostep.Caption:=''; lblLPCzasDoKoncaPakietu.Caption:='';
  mmUpdateLog.Clear;
  mmUpdateLog.Lines.Add('+++ Start: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  FBreakLoad:=false;
  lblLPSpolka.Caption:=''; lblLPStan.Caption:='';

  BgndLoaderThr:=TBgndLoaderThread.Create;
  BgndLoaderThr.DestPath:=NormalDir(ExtractFilePath(ParamStr(0)))+'ATunzip\';
  ForceDirectories(BgndLoaderThr.DestPath);

//  dm.OpenQuery(dm.qrySpolki, Q_SPOLKI);
  dm.OpenQuery(dm.qrySpolki, Q_TEST);
  dm.qrySpolki.First;
  while not dm.qrySpolki.Eof do
  begin
    if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
    begin
      if dm.qrySpolki.fieldbyname('typ').AsInteger in [0,1] then  //spolki,indeksy
      begin
        fn:=dm.Settings[format('PathCiagle%d',[dm.qrySpolki.fieldbyname('typ').AsInteger])] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
        BgndLoaderThr.Files.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip='+fn);
      end;
      if dm.qrySpolki.fieldbyname('typ').AsInteger=2 then //kontrakty
      begin
        dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[2, dm.qrySpolki.fieldbyname('id').AsInteger]));
        maxts:=dm.qryTemp.Fields[0].AsDateTime; //ostatni ts z bazy
//        if maxts=0 then maxts:=StrToDate('2000-01-01');
        if maxts=0 then
        begin
//          maxts:=StrToDate('2000-01-01');
          dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
          maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
        end;

          //okreslamy ktore serie musimy pobrac zeby wygenerowac wygasajaca serie
//        fd:=GetCurrFutData(maxts);
        fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
        fn:=dm.Settings['PathCiagle2'] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
        BgndLoaderThr.Files.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip=' + fn);
        while fd.expiration<currts do
        begin
//          fd:=GetCurrFutData(fd.expiration+1);
          fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
          fn:=dm.Settings['PathCiagle2'] + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
          BgndLoaderThr.Files.Add(dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip=' + fn);
        end;
      end;
    end;
    dm.qrySpolki.Next;
  end;
  BgndLoaderThr.Resume; //odpalenie watku sciagajacego pliki

  dm.RefreshQuery(dm.qrySpolki);
  dm.qrySpolki.First;
  while (not dm.qrySpolki.Eof) and (not FBreakLoad) do
  begin
    if FBreakLoad then break;
    application.ProcessMessages;
    if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
    begin
      if dm.qrySpolki.fieldbyname('typ').asinteger in [0,1] then
      begin
//        lblLPSpolka.Caption:=format('%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaspolki').AsString, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
        lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaspolki').AsString]);
        fn:=BgndLoaderThr.DestPath+dm.qrySpolki.fieldbyname('nazwaakcji').AsString+'.zip';
        PrepareZIPFile( fn );
        UpdateData(0);
        DeleteFile( fn ); //usuwamy plik zip
      end;
      if dm.qrySpolki.fieldbyname('typ').asinteger=2 then
      begin
//        lblLPSpolka.Caption:=format('%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
        lblLPSpolka.Caption:=format('(%d/%d) %s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString]);
        dm.OpenQuery(dm.qryTemp, format(Q_MAXTS,[2, dm.qrySpolki.fieldbyname('id').AsInteger]));
        maxts:=dm.qryTemp.Fields[0].AsDateTime; //ostatni ts z bazy
//        if maxts=0 then maxts:=StrToDate('2000-01-01');
        if maxts=0 then
        begin
//          maxts:=StrToDate('2000-01-01');
          dm.OpenQuery(dm.qryTemp, format(Q_FIRSTBIEZACA, [dm.qrySpolki.fieldbyname('id').AsInteger]));
          maxts:=dm.qryTemp.Fields[0].AsDateTime +1;
        end;
          //okreslamy ktore serie musimy pobrac zeby wygenerowac wygasajaca serie
//        fd:=GetCurrFutData(maxts);
        fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, maxts);
//        lblLPSpolka.Caption:=format('%s%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
        lblLPSpolka.Caption:=format('(%d/%d) %s%s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series]);
        fn:=BgndLoaderThr.DestPath + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
        WaitForFile(fn);  //czekamy na plik z danymi
        UpdateDataFut0(fn, maxts, fd.expiration+1);
        maxts:=fd.expiration + 1;
        while fd.expiration<currts do
        begin
          if FBreakLoad then break;
//          fd:=GetCurrFutData(fd.expiration+1);
          fd:=GetCurrFutData2(dm.qrySpolki.fieldbyname('id').AsInteger, fd.expiration+1);
//          lblLPSpolka.Caption:=format('%s%s (%d/%d)', [dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series, dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount]);
          lblLPSpolka.Caption:=format('(%d/%d) %s%s', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaakcji').AsString, fd.series]);
          fn:=BgndLoaderThr.DestPath + dm.qrySpolki.fieldbyname('nazwaakcji').AsString + fd.series + '.zip';
          WaitForFile(fn);  //czekamy na plik z danymi
          UpdateDataFut0(fn, maxts, fd.expiration+1);
          maxts:=fd.expiration + 1;
        end;
      end;
    end;
    dm.qrySpolki.Next;
  end;
  dm.qrySpolki.Close;

  if not BgndLoaderThr.Suspended then
  begin
    BgndLoaderThr.Terminate;
    BgndLoaderThr.WaitFor;
  end;
  ClearDir(BgndLoaderThr.DestPath, false); //czyscimy katalog downloadu
  BgndLoaderThr.Free;
  BgndLoaderThr:=nil;

//  UpdateStartTS;  //pole at_spolki.startts
  mmUpdateLog.Lines.Add('+++ Stop: '+formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  MessageDlg('Pobieranie danych ci¹g³ych zakoñczone', mtInformation, [mbOK], 0);
end;

end.
