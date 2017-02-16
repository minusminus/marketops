unit U_MultiQueryExecutor;

interface

uses
  Classes;

type
  {
    Base class for multi query executions
  }
  TMultiQueryExecutor = class
  private
    function GetQueryCount: integer;
  protected
    FBuf : TStringList;
  published
  public
    //number of queries in buffer
    property QueryCount : integer read GetQueryCount;

    constructor Create;
    destructor Destroy; override;

    //clears query buffer
    procedure Clear;
    //add query to buffer
    procedure Add(AQry : string); overload;
    procedure Add(AQry : string; const Args: array of const); overload;
  end;

implementation

uses
  SysUtils;

{ TMultiQueryExecutor }

constructor TMultiQueryExecutor.Create;
begin
  FBuf:=TStringList.Create;
end;

destructor TMultiQueryExecutor.Destroy;
begin
  FBuf.Free;
  inherited;
end;

procedure TMultiQueryExecutor.Add(AQry: string);
begin
  FBuf.Add(AQry);
end;

procedure TMultiQueryExecutor.Add(AQry: string; const Args: array of const);
begin
  Add( format(AQry, Args) );
end;

procedure TMultiQueryExecutor.Clear;
begin
  FBuf.Clear;
end;

function TMultiQueryExecutor.GetQueryCount: integer;
begin
  result:=FBuf.Count;
end;

end.
