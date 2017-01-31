program DataPump;

uses
  Forms,
  U_FormMain in 'U_FormMain.pas' {FormMain},
  U_DM in 'U_DM.pas' {DM: TDataModule},
  U_InetFile in 'U_InetFile.pas',
  U_BgndLoaderThread in 'U_BgndLoaderThread.pas',
  U_DataProviderMP in 'U_DataProviderMP.pas',
  U_Consts in '..\Shared\U_Consts.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'MarketOps DataPump';
  Application.CreateForm(TDM, DM);
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
