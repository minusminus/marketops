program AutoTests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options 
  to use the console test runner.  Otherwise the GUI test runner will be used by 
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  Forms,
  TestFramework,
  GUITestRunner,
  TextTestRunner,
  U_CircularIndexer in '..\Shared\U_CircularIndexer.pas',
  TU_CircularIndexer in 'TU_CircularIndexer.pas',
  U_CircularBufferLIFO in '..\Shared\U_CircularBufferLIFO.pas',
  U_CBLIFOSingle in '..\Shared\U_CBLIFOSingle.pas',
  TU_CBLIFOSingle in 'TU_CBLIFOSingle.pas',
  U_SMA2 in '..\Shared\U_SMA2.pas',
  TU_SMA2 in 'TU_SMA2.pas',
  U_EMA2 in '..\Shared\U_EMA2.pas',
  TU_EMA2 in 'TU_EMA2.pas';

{$R *.RES}

begin
  Application.Initialize;
  if IsConsole then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
end.

