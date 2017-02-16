unit U_NoReturnQueryExecutor;

interface

uses
  U_MultiQueryExecutor, ADODB;

type
  {
    Class for execution of queries without returning dataset (insert, delete).
    All queries executed in order of insertion (FIFO)
  }
  TNoReturnQueryExecutor = class(TMultiQueryExecutor)
  private
    //prepares one query string
    function PrepareQuery : string;
  public
    //executes all queries from buffer
    procedure Execute(ADB : TADOConnection);
  end;

implementation

uses Classes;

{ TNoReturnQueryExecutor }

procedure TNoReturnQueryExecutor.Execute(ADB : TADOConnection);
var
  s : string;
begin
  if FBuf.Count=0 then exit;
  s:=PrepareQuery;
  ADB.Execute(s);
end;

function TNoReturnQueryExecutor.PrepareQuery : string;
const
  C_END = ';'#13#10;
var
  i : integer;
begin
  result:='';
  for i := 0 to FBuf.Count - 1 do
    result:=result + FBuf[i] + C_END;
end;

end.
