unit U_UnionQueryExecutor;

interface

uses
  U_MultiQueryExecutor, ADODB;

type
  {
    Class for execution of queries returning dataset (selects in union).
    All queries executed in order of insertion (FIFO)
  }
  TUnionQueryExecutor = class(TMultiQueryExecutor)
  private
    //prepares one query string
    function PrepareQuery(AWhereFilter, AOrderBy : string) : string;
  public
    //executes all queries from buffer
    procedure Execute(AQry : TADOQuery; AWhereFilter, AOrderBy : string);
  end;

implementation

uses
  SysUtils;

{ TUnionQueryExecutor }

procedure TUnionQueryExecutor.Execute(AQry: TADOQuery; AWhereFilter,
  AOrderBy: string);
var
  s : string;
begin
  if FBuf.Count=0 then exit;
  s:=PrepareQuery(AWhereFilter, AOrderBy);
  AQry.Close;
  AQry.SQL.Text:=s;
  AQry.Open;
end;

function TUnionQueryExecutor.PrepareQuery(AWhereFilter, AOrderBy : string): string;
const
  C_DATAFIRST = '(%s)';
  C_DATANEXT = #13#10'union'#13#10'(%s)';
  C_DATAORDER = #13#10'order by %s';
  C_WHERE = 'select * from (%s) t where %s';
var
  i : integer;
begin
  result:=format(C_DATAFIRST, [FBuf[0]]);
  for i := 1 to FBuf.Count - 1 do
    result:=result + format(C_DATANEXT, [FBuf[i]]);
  if AWhereFilter<>'' then
    result:=format(C_WHERE, [result, AWhereFilter]);
  if AOrderBy<>'' then
    result:=result + format(C_DATAORDER, [AOrderBy]);
end;

end.
