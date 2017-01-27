object DM: TDM
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 270
  Width = 341
  object DB: TADOConnection
    Left = 16
    Top = 24
  end
  object qryTemp: TADOQuery
    Connection = DB
    LockType = ltReadOnly
    Parameters = <>
    Left = 64
    Top = 24
  end
  object qryTemp2: TADOQuery
    Connection = DB
    LockType = ltReadOnly
    Parameters = <>
    Left = 112
    Top = 24
  end
  object qrySpolki: TADOQuery
    Connection = DB
    LockType = ltReadOnly
    Parameters = <>
    Left = 64
    Top = 72
  end
  object qryTemp3: TADOQuery
    Connection = DB
    LockType = ltReadOnly
    Parameters = <>
    Left = 160
    Top = 24
  end
end
