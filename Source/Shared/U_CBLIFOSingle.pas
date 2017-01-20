unit U_CBLIFOSingle;

interface

uses
  U_CircularBufferLIFO;

type
  TCBLIFOSingle = class(TCircularBuferLIFO)
  private
    FData : array of single;
    function GetData(Index: integer): single;
  protected
    procedure InitializeStorage; override;
    procedure FinalizeStorage; override;
  public
    property Data[Index : integer] : single read GetData; default;

    //add element
    procedure Add(el : single);

    //get value of first element
    function First : single;
    //and last
    function Last : single;
  end;

implementation

{ TCBLIFOSingle }

procedure TCBLIFOSingle.InitializeStorage;
begin
  SetLength(FData, FCapacity);
end;

procedure TCBLIFOSingle.FinalizeStorage;
begin
  SetLength(FData, 0);
end;

function TCBLIFOSingle.GetData(Index: integer): single;
begin
  result:=FData[ GetBufPosition(Index) ];
end;

procedure TCBLIFOSingle.Add(el: single);
begin
  FData[FCurrPos]:=el;
  MoveToNextBufPosition;
end;

function TCBLIFOSingle.First: single;
begin
  result:=FData[FCurrPos];
end;

function TCBLIFOSingle.Last: single;
begin
  result:=FData[GetLastBufPosition];
end;

end.
