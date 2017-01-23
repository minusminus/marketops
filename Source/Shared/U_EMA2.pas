unit U_EMA2;

interface

uses
  U_CBLIFOSingle;

type
  {
    exponential moving average
    with circular buffer for counted elements
  }
  TEMA2 = class
  private
    FTbl : TCBLIFOSingle;
    FDepth: integer;
    FTotalCnt: integer;
    FValue: single;
    FLastValue: single;
    FCurrSum : single;
    FDenominator : single;
    FAlpha : single;
    F1mAlpha : single;
    F1mAlphan : single;

    procedure CalcValue;
  public
    property Depth : integer read FDepth;
    property TotalCnt : integer read FTotalCnt;
    property Value : single read FValue;
    property LastValue : single read FLastValue;

    constructor Create( MADepth : integer );
    destructor Destroy; override;

    procedure Add( el : single );
  end;

implementation

uses
  Math;

{ TEMA2 }

constructor TEMA2.Create(MADepth: integer);
var
  i : integer;
begin
  FDepth:=MADepth;
  FTbl:=TCBLIFOSingle.Create(FDepth);
  FTotalCnt:=0;
  FLastValue:=0;
  FValue:=0;

  FAlpha:=2.0/(MADepth+1.0);
  F1mAlpha:=1.0-FAlpha;
  F1mAlphan:=Power(F1mAlpha, MADepth);
  FCurrSum:=0;
  FDenominator:=1.0;
  for i:=1 to FDepth-1 do FDenominator:=FDenominator*F1mAlpha + 1.0;
  FDenominator:=1.0 / FDenominator;
end;

destructor TEMA2.Destroy;
begin
  FTbl.Free;
  inherited;
end;

procedure TEMA2.Add(el: single);
begin
  if FTotalCnt=0 then
    FCurrSum:=el
  else if FTotalCnt<FDepth then
    FCurrSum:=F1mAlpha*FCurrSum + el
  else
    FCurrSum:=(FCurrSum*F1mAlpha) - (FTbl.Last*F1mAlphan) + el;
  inc(FTotalCnt);
  FTbl.Add(el);
  if FTbl.Full then
    CalcValue;
end;

procedure TEMA2.CalcValue;
begin
  FLastValue:=FValue;
  FValue:=FCurrSum*FDenominator;
end;

end.

