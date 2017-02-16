program DataPump;

uses
  Forms,
  U_FormMain in 'U_FormMain.pas' {FormMain},
  U_DM in 'U_DM.pas' {DM: TDataModule},
  U_InetFile in 'U_InetFile.pas',
  U_BgndLoaderThread in 'U_BgndLoaderThread.pas',
  U_DataProviderMP in 'U_DataProviderMP.pas',
  U_Consts in '..\Shared\U_Consts.pas',
  U_FilesDownloader in 'U_FilesDownloader.pas',
  U_DataInserter in 'U_DataInserter.pas',
  U_SeriesInfo in 'U_SeriesInfo.pas',
  U_DataInserterProgressCalc in 'U_DataInserterProgressCalc.pas',
  U_Utils in '..\Shared\U_Utils.pas',
  U_DataGenerator in 'U_DataGenerator.pas',
  U_DataGeneratorProgressCalc in 'U_DataGeneratorProgressCalc.pas',
  U_MultiQueryExecutor in '..\Shared\U_MultiQueryExecutor.pas',
  U_NoReturnQueryExecutor in '..\Shared\U_NoReturnQueryExecutor.pas',
  U_UnionQueryExecutor in '..\Shared\U_UnionQueryExecutor.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'MarketOps DataPump';
  Application.CreateForm(TDM, DM);
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
