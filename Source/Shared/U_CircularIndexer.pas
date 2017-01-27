unit U_CircularIndexer;

interface

type
  {
    circular indexer for circular buffer
    indexes from 0 to N-1
  }
  TCircularIndexer = class
  private
    FLength: integer;
    FPos : integer;
    FLoopsCount: integer;
  public
    property Length : integer read FLength;
    property Pos : integer read FPos;
    property LoopsCount : integer read FLoopsCount;

    constructor Create(ALength : integer);

    //resets to new position
    procedure SetPosition(ANewPosition : integer);
    //increments to next index position
    procedure Inc;
  end;

implementation

{ TCircularIndexer }

constructor TCircularIndexer.Create(ALength: integer);
begin
  FLength:=ALength;
  SetPosition(0);
end;

procedure TCircularIndexer.Inc;
begin
  FPos:=FPos + 1;
  if FPos>=FLength then
  begin
    FPos:=0;
    FLoopsCount:=FLoopsCount + 1;
  end;
end;

procedure TCircularIndexer.SetPosition(ANewPosition: integer);
begin
  FPos:=ANewPosition;
  FLoopsCount:=0;
end;

end.
