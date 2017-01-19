program Montecarlo;

uses
  Forms,
  U_FormMain in 'U_FormMain.pas' {FormMain},
  cRandom in 'cRandom.pas',
  U_MCSim in 'U_MCSim.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Montecarlo simulation';
  Application.CreateForm(TFormMain, FormMain);  
  Application.Run;
end.
