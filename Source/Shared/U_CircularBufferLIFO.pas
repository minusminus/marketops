unit U_CircularBufferLIFO;

interface

type
  {
    Circular buffer LIFO
    adding always in the beggining of the buffer (buffer[0])
  }
  TCircularBuferLIFO = class
  private
  protected
    FCapacity: integer;
    FInserted: integer;
    FFull: boolean;
    FCurrPos, FLastPos : integer;

    //buffer position for specified index
    function GetBufPosition(AIndex : integer) : integer;
    //position of last element in buffer
    function GetLastBufPosition : integer;
    //moves current position to next in buffer
    function MoveToNextBufPosition : integer;

    //increment position
    procedure IncrementPosition(var i : integer);

    //data storage initialization and finalization
    procedure InitializeStorage; virtual; abstract;
    procedure FinalizeStorage; virtual; abstract;
  published
  public
    property Capacity : integer read FCapacity;
    property Inserted : integer read FInserted;
    //whole buffer was filled
    property Full : boolean read FFull;

    constructor Create(ACapacity : integer);
    destructor Destroy; override;

    //resets buffer
    procedure Reset;
  end;

implementation

{ TCircularBufer }

constructor TCircularBuferLIFO.Create(ACapacity: integer);
begin
  FCapacity:=ACapacity;
  Reset;
  InitializeStorage;
end;

destructor TCircularBuferLIFO.Destroy;
begin
  FinalizeStorage;
  inherited;
end;

procedure TCircularBuferLIFO.Reset;
begin
  FCurrPos:=0;
//  FLastPos:=FCapacity - 1;
  FLastPos:=-1;
  FInserted:=0;
  FFull:=false;
end;

function TCircularBuferLIFO.GetBufPosition(AIndex: integer): integer;
begin
  result:=FCurrPos - AIndex;
//  if result>=FCapacity then
////    result:=result mod FCapacity;
//    result:=FCapacity - 1;
  if result<0 then
    result:=FCapacity + result;
end;

function TCircularBuferLIFO.GetLastBufPosition: integer;
begin
  result:=GetBufPosition(FCapacity - 1);
end;

procedure TCircularBuferLIFO.IncrementPosition(var i: integer);
begin
  i:=i + 1;
  if i>=FCapacity then
  begin
    i:=0;
    FFull:=true;
  end;
end;

function TCircularBuferLIFO.MoveToNextBufPosition: integer;
begin
  IncrementPosition(FCurrPos);
  if FFull then IncrementPosition(FLastPos) else FLastPos:=0;
  FInserted:=FInserted + 1;
  result:=FCurrPos;
end;

end.
