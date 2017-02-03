unit U_DataInserterProgressCalc;

interface

type
  {
    time remaining calculations for data inserting
  }
  TDataInserterProgressCalc = class
  private
    FLinesPerSec: double;
    FTimeRemaining: TDateTime;

    FFileSize, FStartBytesRead, FStartLinesRead : integer;
    FStartTS : TDateTime;
  public
    property TimeRemaining : TDateTime read FTimeRemaining;
    property LinesPerSec : double read FLinesPerSec;
//    property StartBytesRead : integer read FStartBytesRead;
//    property StartLinesRead : integer read FStartLinesRead;

    procedure Init(const ACurrBytesRead, ACurrLinesRead, ATotalFileSize : integer);
    function Calculate(const ACurrBytesRead, ACurrLinesRead : integer) : boolean;
  end;

implementation

uses
  SysUtils;

{ TDataInserterProgressCalc }

procedure TDataInserterProgressCalc.Init(const ACurrBytesRead,
  ACurrLinesRead, ATotalFileSize: integer);
begin
  FLinesPerSec:=0;
  FTimeRemaining:=0;

  FFileSize:=ATotalFileSize;
  FStartBytesRead:=ACurrBytesRead;
  FStartLinesRead:=ACurrLinesRead;
  FStartTS:=now;
end;

function TDataInserterProgressCalc.Calculate(const ACurrBytesRead,
  ACurrLinesRead: integer) : boolean;
var
  currts : TDateTime;
begin
  result:=false;
  if ACurrBytesRead<=FStartBytesRead then exit;

  currts:=now;
  FTimeRemaining:=(FFileSize-ACurrBytesRead)*(currts-FStartTS)/(ACurrBytesRead-FStartBytesRead);
  FLinesPerSec:=(ACurrLinesRead-FStartLinesRead)/((currts-FStartTS)/(1.0/24.0/60.0/60.0));
  result:=true;
end;

end.
