object FormMain: TFormMain
  Left = 250
  Top = 141
  Caption = 'FormMain'
  ClientHeight = 327
  ClientWidth = 697
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Shell Dlg 2'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    697
    327)
  PixelsPerInch = 96
  TextHeight = 13
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 193
    Height = 185
    Caption = 'Parameters'
    TabOrder = 0
    DesignSize = (
      193
      185)
    object Label1: TLabel
      Left = 8
      Top = 28
      Width = 71
      Height = 13
      Caption = 'Win probability'
    end
    object Label2: TLabel
      Left = 8
      Top = 52
      Width = 68
      Height = 13
      Caption = 'Win/Loss ratio'
    end
    object Label3: TLabel
      Left = 8
      Top = 76
      Width = 46
      Height = 13
      Caption = 'Sim count'
    end
    object Label4: TLabel
      Left = 8
      Top = 100
      Width = 49
      Height = 13
      Caption = 'Sim length'
    end
    object lblInfo: TLabel
      Left = 8
      Top = 160
      Width = 30
      Height = 13
      Caption = 'lblInfo'
    end
    object edtWRatio: TEdit
      Left = 104
      Top = 24
      Width = 73
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      Text = '0,4'
    end
    object edtWLRatio: TEdit
      Left = 104
      Top = 48
      Width = 73
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
      Text = '1,5'
    end
    object edtCnt: TEdit
      Left = 104
      Top = 72
      Width = 73
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 2
      Text = '100'
    end
    object btnSimulate: TButton
      Left = 32
      Top = 128
      Width = 121
      Height = 25
      Caption = 'Sim'
      TabOrder = 4
      OnClick = btnSimulateClick
    end
    object edtSimLen: TEdit
      Left = 104
      Top = 96
      Width = 73
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 3
      Text = '1000'
    end
  end
  object mmLog: TMemo
    Left = 8
    Top = 200
    Width = 193
    Height = 121
    Anchors = [akLeft, akTop, akBottom]
    ScrollBars = ssBoth
    TabOrder = 1
  end
  object GroupBox2: TGroupBox
    Left = 216
    Top = 8
    Width = 473
    Height = 313
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = 'Series graph'
    TabOrder = 2
    object pbSeries: TPaintBox
      Left = 2
      Top = 15
      Width = 469
      Height = 296
      Align = alClient
      OnPaint = pbSeriesPaint
    end
  end
end
