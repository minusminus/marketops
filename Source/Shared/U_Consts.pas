unit U_Consts;

interface

type
  {
    MarketOps stock types:
    GPWStock (0) - GPW stocks
    GPWIndex (1) - GPW indexes
    GPWIndexFuture (2) - GPW futures
    GPWOptions (3) - GPW options UNUSED!
    PLInvestmentFund (4) - PL investment funds
    NBPCurrency (5) - NBP currency
    BossaFX (6) - bossa.pl forex items
  }
  TMarketOpsStockType = (motGPWStock, motGPWIndex, motGPWIndexFuture, motGPWOptions, motPLInvestmentFund, motNBPCurrency, motBossaFX);

  {
    MarketOps downloaded data type
    modataTicks (0) - ticks data
    modataDaily (1) - end of day data
  }
  TMarketOpsDataType = (modataTicks, modataDaily);

  {
    MarketOps generated data type
  }
  TMarketOpsDataGenType = (mogenMinute, mogenHour, mogenWeek, mogenMonth);

implementation

end.
