unit U_DataGeneratorProgressCalc;

interface

type
  {
    time remaining calculations for data inserting
  }
  TDataGeneratorProgressCalc = class
  private
    FTimeRemaining: TDateTime;

    FCalcStartTS, FCalcEndTS : TDateTime;
    FStartTS : TDateTime;
  public
    property TimeRemaining : TDateTime read FTimeRemaining;

    procedure Init(const ACalcStartTS, ACalcEndTS : TDateTime);
    function Calculate(const ACurrCalculatedTS : TDateTime) : boolean;
  end;

implementation

uses
  SysUtils;

{ TDataGeneratorProgressCalc }

procedure TDataGeneratorProgressCalc.Init(const ACalcStartTS,
  ACalcEndTS: TDateTime);
begin
  FTimeRemaining:=0;

  FCalcStartTS:=ACalcStartTS;
  FCalcEndTS:=ACalcEndTS;
  FStartTS:=now;
end;

function TDataGeneratorProgressCalc.Calculate(
  const ACurrCalculatedTS: TDateTime): boolean;
var
  currts : TDateTime;
begin
  result:=false;

  currts:=now;
  FTimeRemaining:=(FCalcEndTS-ACurrCalculatedTS)*(currts-FStartTS)/(ACurrCalculatedTS-FCalcStartTS);
  result:=true;
end;

end.
