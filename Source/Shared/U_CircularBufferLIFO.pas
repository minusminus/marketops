unit U_CircularBufferLIFO;

interface

uses
  U_CircularIndexer;

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
//    FCurrPos, FLastPos : integer;
    FCurrPos, FLastPos : TCircularIndexer;

    //buffer position for specified index
    function GetBufPosition(AIndex : integer) : integer;
    //position of last element in buffer
    function GetLastBufPosition : integer;
    //moves current position to next in buffer
    procedure MoveToNextBufPosition;

    //increment position
    procedure IncrementPosition(i : TCircularIndexer);

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
  FCurrPos:=TCircularIndexer.Create(FCapacity);
  FLastPos:=TCircularIndexer.Create(FCapacity);
  Reset;
  InitializeStorage;
end;

destructor TCircularBuferLIFO.Destroy;
begin
  FinalizeStorage;
  FLastPos.Free;
  FCurrPos.Free;
  inherited;
end;

procedure TCircularBuferLIFO.Reset;
begin
  FCurrPos.SetPosition(0);
  FLastPos.SetPosition(-1);
  FInserted:=0;
  FFull:=false;
end;

function TCircularBuferLIFO.GetBufPosition(AIndex: integer): integer;
begin
  result:=FCurrPos.Pos - AIndex;
  if result<0 then
    result:=FCapacity + result;
end;

function TCircularBuferLIFO.GetLastBufPosition: integer;
begin
  result:=GetBufPosition(FCapacity - 1);
end;

procedure TCircularBuferLIFO.IncrementPosition(i: TCircularIndexer);
begin
  i.Inc;
  if i.LoopsCount>0 then FFull:=true;  
end;

procedure TCircularBuferLIFO.MoveToNextBufPosition;
begin
  IncrementPosition(FCurrPos);
  if FFull then IncrementPosition(FLastPos) else FLastPos.SetPosition(0);
  FInserted:=FInserted + 1;
end;

end.
