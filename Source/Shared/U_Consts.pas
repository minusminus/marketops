unit U_Consts;

interface

type
  {
    MarketOps stock types:
    GPWStock (0) - GPW stocks
    GPWIndex (1) - GPW indexes
    GPWIndexFuture (2) - GPW futures
    PLInvestmentFund (3) - PL investment funds
    NBPCurrency (4) - NBP currency
    BossaFX (5) - bossa.pl forex items
  }
  TMarketOpsStockType = (motGPWStock, motGPWIndex, motGPWIndexFuture, motPLInvestmentFund, motNBPCurrency, motBossaFX);

implementation

end.
