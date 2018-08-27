unit U_DailyDataProcessor;

interface

uses
  U_DataInserter, Classes, U_FilesDownloader, StdCtrls, U_Consts, U_DataPumpConfig;

type
  TDailyDataProcessorCheckBreakLoad = function : boolean of object;

  TDailyDataProcessor = class
  private
    FUnzipDir : string;
    FDataInserter : TDataInserter;
    FFilesDownloader : TFilesDownloader;
    FDPConfig : TDataPumpConfig;
    FUpdateLog : TStrings;
    FLblStan, FLblSpolka : TLabel;
    FOnCheckBreakLoad: TDailyDataProcessorCheckBreakLoad;

    procedure UpdateStanCaption(AMsg : string);
    procedure DownloadAndProcessFileDzienneData( AStockType : TMarketOpsStockType; AQryIndex : integer; const AHdr : string );
    procedure FromFileAndProcessFileDzienneData( AQryIndex : integer; const AHdr : string );
    procedure ProcessFileDzienneData(AQryIndex : integer);
    function BreakLoad : boolean;
  public
    property OnCheckBreakLoad : TDailyDataProcessorCheckBreakLoad read FOnCheckBreakLoad write FOnCheckBreakLoad;

    constructor Create(AUnzipDir : string; ADataInserter : TDataInserter; AFilesDownloader : TFilesDownloader; ADPConfig : TDataPumpConfig;
      AUpdateLog : TStrings; ALblStan, ALblSpolka : TLabel);
    destructor Destroy; override;

    procedure Download(ATypItemIndex : integer);
    procedure FromFile(ATypItemIndex : integer; const AZipFN : string);
  end;

implementation

uses U_DM, Forms, SysUtils, rxFileUtil;

const
  Q_SPOLKI012 = 'select * from at_spolki where typ in (0,1,2) order by typ, id';
//  Q_SPOLKI012 = 'select * from at_spolki where typ in (0,1,2) and id=288 order by typ, id';
  Q_SPOLKI4 = 'select * from at_spolki where typ=4 order by typ, id';
  Q_SPOLKI5 = 'select * from at_spolki where typ=5 order by typ, id';
  Q_SPOLKI6 = 'select * from at_spolki where typ=6 order by typ, id';

  Q_SPOLKI_ARR : array[1..4] of string = (Q_SPOLKI012, Q_SPOLKI4, Q_SPOLKI5, Q_SPOLKI6);

{ TDailyDataProcessor }

constructor TDailyDataProcessor.Create(AUnzipDir : string; ADataInserter : TDataInserter; AFilesDownloader : TFilesDownloader; ADPConfig : TDataPumpConfig;
  AUpdateLog : TStrings; ALblStan, ALblSpolka : TLabel);
begin
  FUnzipDir:=AUnzipDir;
  FDataInserter:=ADataInserter;
  FFilesDownloader:=AFilesDownloader;
  FDPConfig:=ADPConfig;
  FUpdateLog:=AUpdateLog;
  FLblStan:=ALblStan;
  FLblSpolka:=ALblSpolka;
end;

destructor TDailyDataProcessor.Destroy;
begin

  inherited;
end;

function TDailyDataProcessor.BreakLoad: boolean;
begin
  result:=false;
  if assigned(FOnCheckBreakLoad) then
    result:=FOnCheckBreakLoad;
end;

procedure TDailyDataProcessor.ProcessFileDzienneData(AQryIndex: integer);
var
  datafn : string;
begin
  UpdateStanCaption('Przetwarzanie...');
  dm.OpenQuery(dm.qrySpolki, Q_SPOLKI_ARR[AQryIndex]);
  dm.qrySpolki.First;
  while (not dm.qrySpolki.Eof) and (not BreakLoad) do
  begin
    Application.ProcessMessages;
    if dm.qrySpolki.fieldbyname('aktywna').asinteger=1 then
    begin
      datafn:=FUnzipDir + dm.qrySpolki.fieldbyname('nazwaakcji2').AsString + '.mst';
      FLblSpolka.Caption:=format('(%d/%d) %s [%d]', [dm.qrySpolki.RecNo, dm.qrySpolki.RecordCount, dm.qrySpolki.fieldbyname('nazwaspolki').AsString, dm.qrySpolki.fieldbyname('id').AsInteger]);
      FDataInserter.InsertData(modataDaily, TMarketOpsStockType(dm.qrySpolki.fieldbyname('typ').AsInteger), dm.qrySpolki.fieldbyname('id').AsInteger, datafn);
    end;
    dm.qrySpolki.Next;
  end;
  dm.qrySpolki.Close;
  ClearDir(FUnzipDir, false); //czyscimy katalog downloadu
  UpdateStanCaption('');
end;

procedure TDailyDataProcessor.UpdateStanCaption(AMsg: string);
begin
  FLblStan.Caption:=AMsg;
  Application.ProcessMessages;
end;

procedure TDailyDataProcessor.Download(ATypItemIndex : integer);
begin
  FLblStan.Caption:=''; FLblSpolka.Caption:='';
  FUpdateLog.Clear;
  FUpdateLog.Add('+++ Start: ' + formatdatetime('yyyy-mm-dd hh:nn:ss', now));
  Application.ProcessMessages;

  if (ATypItemIndex in [0,1]) and (not BreakLoad) then
    DownloadAndProcessFileDzienneData(motGPWStock, 1, '+++ typ 0,1,2');
  if (ATypItemIndex in [0,2]) and (not BreakLoad) then //fio
    DownloadAndProcessFileDzienneData(motPLInvestmentFund, 2, '+++ typ 4');
  if (ATypItemIndex in [0,3]) and (not BreakLoad) then //waluty nbp
    DownloadAndProcessFileDzienneData(motNBPCurrency, 3, '+++ typ 5');
  if (ATypItemIndex in [0,4]) and (not BreakLoad) then //fx
    DownloadAndProcessFileDzienneData(motBossaFX, 4, '+++ typ 6');

  FDataInserter.UpdateAllStartTS;
  FUpdateLog.Add('+++ Stop: ' + formatdatetime('yyyy-mm-dd hh:nn:ss', now));
end;

procedure TDailyDataProcessor.DownloadAndProcessFileDzienneData(
  AStockType: TMarketOpsStockType; AQryIndex: integer; const AHdr: string);
begin
  FUpdateLog.Add(AHdr);
  UpdateStanCaption('Pobieranie...');
  FFilesDownloader.DownloadAndUnzip(FDPConfig.GetDLDziennePath(AStockType), FDPConfig.GetDLDzienneFileName(AStockType), FUnzipDir);
  ProcessFileDzienneData(AQryIndex);
end;

procedure TDailyDataProcessor.FromFile(ATypItemIndex: integer;
  const AZipFN: string);
begin
  UpdateStanCaption('Rozpakowanie...');
  FFilesDownloader.PrepareZIPFile(AZipFN, FUnzipDir);

  if (ATypItemIndex in [0,1]) and (not BreakLoad) then
    FromFileAndProcessFileDzienneData(1, '+++ typ 0,1,2');
  if (ATypItemIndex in [0,2]) and (not BreakLoad) then
    FromFileAndProcessFileDzienneData(2, '+++ typ 4');
  if (ATypItemIndex in [0,3]) and (not BreakLoad) then
    FromFileAndProcessFileDzienneData(3, '+++ typ 5');
  if (ATypItemIndex in [0,4]) and (not BreakLoad) then
    FromFileAndProcessFileDzienneData(4, '+++ typ 6');

  FDataInserter.UpdateAllStartTS;
  FUpdateLog.Add('+++ Stop: ' + formatdatetime('yyyy-mm-dd hh:nn:ss', now));
end;

procedure TDailyDataProcessor.FromFileAndProcessFileDzienneData(
  AQryIndex: integer; const AHdr: string);
begin
  FUpdateLog.Add(AHdr);
  ProcessFileDzienneData(AQryIndex);
end;

end.
