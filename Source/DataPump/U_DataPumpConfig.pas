unit U_DataPumpConfig;

interface

uses
  Classes, U_Consts;

type
  {
    configuration of downloadable zip files
  }
  TDataPumpConfig = class
  private
    FDLPathsD, FDLZipFileNamesD : TStringList;
    FDLPathsI : TStringList;

    procedure InitCofnig;
  public
    constructor Create;
    destructor Destroy; override;

    function GetDLDzienneFullPath(AStockType : TMarketOpsStockType) : string;
    function GetDLDziennePath(AStockType : TMarketOpsStockType) : string;
    function GetDLDzienneFileName(AStockType : TMarketOpsStockType) : string;
    function GetDLCiaglePath(AStockType : TMarketOpsStockType) : string;
  end;

implementation

uses
  SysUtils, U_DM;

{ TDataPumpConfig }

constructor TDataPumpConfig.Create;
begin
  FDLPathsD:=TStringList.Create;
  FDLZipFileNamesD:=TStringList.Create;
  FDLPathsI:=TStringList.Create;
  InitCofnig;
end;

destructor TDataPumpConfig.Destroy;
begin
  FDLPathsI.Free;
  FDLZipFileNamesD.Free;
  FDLPathsD.Free;
  inherited;
end;

procedure TDataPumpConfig.InitCofnig;
begin
  FDLPathsD.Values[ inttostr(Ord(motGPWStock)) ]:='PathDzienne0';
  FDLPathsD.Values[ inttostr(Ord(motGPWIndex)) ]:='PathDzienne0';
  FDLPathsD.Values[ inttostr(Ord(motGPWIndexFuture)) ]:='PathDzienne0';
//  FDLPathsD.Values[ inttostr(Ord(motGPWOptions)) ]:='PathDzienne0';
  FDLPathsD.Values[ inttostr(Ord(motPLInvestmentFund)) ]:='PathDzienne4';
  FDLPathsD.Values[ inttostr(Ord(motNBPCurrency)) ]:='PathDzienne5';
  FDLPathsD.Values[ inttostr(Ord(motBossaFX)) ]:='PathDzienne6';

  FDLZipFileNamesD.Values[ inttostr(Ord(motGPWStock)) ]:='mstall.zip';
  FDLZipFileNamesD.Values[ inttostr(Ord(motGPWIndex)) ]:='mstall.zip';
  FDLZipFileNamesD.Values[ inttostr(Ord(motGPWIndexFuture)) ]:='mstall.zip';
//  FDLZipFileNamesD.Values[ inttostr(Ord(motGPWOptions)) ]:='mstall.zip';
  FDLZipFileNamesD.Values[ inttostr(Ord(motPLInvestmentFund)) ]:='mstfun.zip';
  FDLZipFileNamesD.Values[ inttostr(Ord(motNBPCurrency)) ]:='mstnbp.zip';
  FDLZipFileNamesD.Values[ inttostr(Ord(motBossaFX)) ]:='mstfx.zip';

  FDLPathsI.Values[ inttostr(Ord(motGPWStock)) ]:='PathCiagle0';
  FDLPathsI.Values[ inttostr(Ord(motGPWIndex)) ]:='PathCiagle0';
  FDLPathsI.Values[ inttostr(Ord(motGPWIndexFuture)) ]:='PathCiagle0';
//  FDLPathsI.Values[ inttostr(Ord(motGPWOptions)) ]:='PathDzienne0';
//  FDLPathsI.Values[ inttostr(Ord(motPLInvestmentFund)) ]:='PathDzienne4';
//  FDLPathsI.Values[ inttostr(Ord(motNBPCurrency)) ]:='PathDzienne5';
//  FDLPathsI.Values[ inttostr(Ord(motBossaFX)) ]:='PathDzienne6';
end;

function TDataPumpConfig.GetDLDzienneFullPath(
  AStockType: TMarketOpsStockType): string;
begin
  result:=GetDLDziennePath(AStockType) + GetDLDzienneFileName(AStockType);
end;

function TDataPumpConfig.GetDLDziennePath(
  AStockType: TMarketOpsStockType): string;
var
  s : string;
begin
  s:=FDLPathsD.Values[ inttostr(ord(AStockType)) ];
  if s='' then Exception.CreateFmt('Niezdefiniowana œcie¿ka dzienna dla typu %d', [Ord(AStockType)]);
  result:=dm.Settings[s];
end;

function TDataPumpConfig.GetDLCiaglePath(
  AStockType: TMarketOpsStockType): string;
var
  s : string;
begin
  s:=FDLPathsI.Values[ inttostr(ord(AStockType)) ];
  if s='' then Exception.CreateFmt('Niezdefiniowana œcie¿ka ci¹g³a dla typu %d', [Ord(AStockType)]);
  result:=dm.Settings[s];
end;

function TDataPumpConfig.GetDLDzienneFileName(
  AStockType: TMarketOpsStockType): string;
begin
  result:=FDLZipFileNamesD.Values[ inttostr(ord(AStockType)) ];
  if result='' then Exception.CreateFmt('Niezdefiniowany plik zip dla typu %d', [Ord(AStockType)]);
end;

end.
