unit U_SMA2;

interface

uses
  U_CBLIFOSingle;

type
  {
    simple moving average
    with circular buffer for counted elements
  }
  TSMA2 = class
  private
    FTbl : TCBLIFOSingle;
    FDepth: integer;
    FTotalCnt: integer;
    FValue: single;
    FLastValue: single;
    FDenominator : single;
    FCurrSum : single;

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

{ TSMA2 }

constructor TSMA2.Create(MADepth: integer);
begin
  FDepth:=MADepth;
  FTbl:=TCBLIFOSingle.Create(FDepth);
  FTotalCnt:=0;
  FLastValue:=0;
  FValue:=0;

  FDenominator:=1.0/FDepth;
  FCurrSum:=0;
end;

destructor TSMA2.Destroy;
begin
  FTbl.Free;
  inherited;
end;

procedure TSMA2.Add(el: single);
begin
  if FTbl.Full then
    FCurrSum:=FCurrSum - FTbl.Last;
  inc(FTotalCnt);
  FTbl.Add(el);
  FCurrSum:=FCurrSum + el;
  if FTbl.Full then
    CalcValue;
end;

procedure TSMA2.CalcValue;
begin
  FLastValue:=FValue;
  FValue:=FCurrSum * FDenominator;
end;

end.
