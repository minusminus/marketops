unit U_Utils;

interface

function PrepareIntVal( val : string ) : string;
function PrepareFloatVal( val : double ) : string;

implementation

uses
  SysUtils, rxstrutils;

function PrepareFloatVal(val: double): string;
begin
  result:=replacestr(format('%.2f',[val]), ',', '.');
end;

function PrepareIntVal(val: string): string;
begin
  result:=val;
  if trim(val)='' then result:='0';
end;

end.
