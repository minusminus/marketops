object FormMain: TFormMain
  Left = 289
  Top = 105
  Caption = 'FormMain'
  ClientHeight = 334
  ClientWidth = 488
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Shell Dlg 2'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pgcMain: TPageControl
    Left = 0
    Top = 0
    Width = 488
    Height = 334
    ActivePage = tabDL
    Align = alClient
    TabOrder = 0
    TabStop = False
    object tabDL: TTabSheet
      Caption = 'Pobieranie danych'
      object Panel2: TPanel
        Left = 0
        Top = 0
        Width = 480
        Height = 83
        Align = alTop
        BevelInner = bvRaised
        BevelOuter = bvLowered
        TabOrder = 0
        object Button1: TButton
          Left = 8
          Top = 8
          Width = 137
          Height = 25
          Action = actDLCiagle
          TabOrder = 0
        end
        object Button2: TButton
          Left = 8
          Top = 50
          Width = 137
          Height = 25
          Action = actDLDzienne
          TabOrder = 1
        end
        object Button3: TButton
          Left = 168
          Top = 8
          Width = 121
          Height = 25
          Action = actDLBreak
          TabOrder = 2
        end
        object Button7: TButton
          Left = 368
          Top = 8
          Width = 75
          Height = 25
          Caption = 'intra fw20ws'
          TabOrder = 3
          Visible = False
          OnClick = Button7Click
        end
        object cbDaneDzienne: TComboBox
          Left = 168
          Top = 50
          Width = 145
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          ItemIndex = 0
          TabOrder = 4
          Text = 'Wszystkie'
          Items.Strings = (
            'Wszystkie'
            'Tylko 0,1,2 (spolki, indeksy, kontrakty)'
            'Tylko 4 (fundusze)'
            'Tylko 5 (waluty NBP)'
            'Tylko 6 (forex)')
        end
      end
      object Panel1: TPanel
        Left = 0
        Top = 83
        Width = 480
        Height = 223
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object Label1: TLabel
          Left = 8
          Top = 8
          Width = 37
          Height = 13
          Caption = 'Post'#281'p:'
        end
        object lblLPPostep: TLabel
          Left = 48
          Top = 8
          Width = 54
          Height = 13
          Caption = 'lblLPPostep'
        end
        object Label3: TLabel
          Left = 168
          Top = 6
          Width = 86
          Height = 13
          Caption = 'Do ko'#324'ca pakietu:'
        end
        object lblLPCzasDoKoncaPakietu: TLabel
          Left = 256
          Top = 6
          Width = 121
          Height = 13
          Caption = 'lblLPCzasDoKoncaPakietu'
        end
        object lblLPSpolka: TLabel
          Left = 8
          Top = 32
          Width = 154
          Height = 13
          AutoSize = False
          Caption = 'lblLPSpolka'
        end
        object lblLPStan: TLabel
          Left = 168
          Top = 30
          Width = 43
          Height = 13
          Caption = 'lblLPStan'
        end
        object mmUpdateLog: TMemo
          Left = 0
          Top = 50
          Width = 480
          Height = 173
          Align = alBottom
          Anchors = [akLeft, akTop, akRight, akBottom]
          ScrollBars = ssBoth
          TabOrder = 0
        end
      end
    end
    object tabPodzial: TTabSheet
      Caption = 'Generowanie danych intra i week+'
      ImageIndex = 1
      object Panel3: TPanel
        Left = 0
        Top = 0
        Width = 480
        Height = 145
        Align = alTop
        BevelInner = bvRaised
        BevelOuter = bvLowered
        TabOrder = 0
        object Label2: TLabel
          Left = 8
          Top = 12
          Width = 56
          Height = 13
          Caption = 'Typ danych'
        end
        object Label4: TLabel
          Left = 8
          Top = 40
          Width = 96
          Height = 13
          Caption = 'Sp'#243#322'ka/Indeks/Fund'
        end
        object Label5: TLabel
          Left = 8
          Top = 126
          Width = 98
          Height = 13
          Caption = 'Post'#281'p generowania'
        end
        object lblGenProg: TLabel
          Left = 112
          Top = 126
          Width = 51
          Height = 13
          Caption = 'lblGenProg'
        end
        object cbGenDataType: TComboBox
          Left = 112
          Top = 8
          Width = 185
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          ItemIndex = 0
          TabOrder = 0
          Text = 'Tygodniowe'
          Items.Strings = (
            'Tygodniowe'
            'Miesi'#281'czne'
            '1 min'
            '2 min'
            '3 min'
            '4 min'
            '5 min'
            '10 min'
            '15 min'
            '20 min'
            '30 min'
            '60 min')
        end
        object cbSpolka: TComboBox
          Left = 112
          Top = 36
          Width = 185
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 1
        end
        object Button4: TButton
          Left = 112
          Top = 95
          Width = 185
          Height = 25
          Action = actGenIntraWeek
          TabOrder = 2
        end
        object Button5: TButton
          Left = 352
          Top = 40
          Width = 75
          Height = 25
          Caption = 'Button5'
          TabOrder = 3
          Visible = False
          OnClick = Button5Click
        end
        object cbGenType: TComboBox
          Left = 112
          Top = 64
          Width = 185
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 4
          Items.Strings = (
            'Wybrane'
            'Wszystkie'
            'Tylko typ 0 (akcje)'
            'Tylko typ 1 (indeksy)'
            'Tylko typ 2 (futures)'
            'Tylko typ 4 (fundusze)'
            'Tylko typ 5 (waluty NBP)'
            'Tylko typ 6 (forex)')
        end
      end
      object Panel4: TPanel
        Left = 0
        Top = 145
        Width = 480
        Height = 161
        Align = alClient
        BevelOuter = bvNone
        Caption = 'Panel4'
        TabOrder = 1
        object mmLogGen: TMemo
          Left = 0
          Top = 0
          Width = 480
          Height = 161
          Align = alClient
          ScrollBars = ssBoth
          TabOrder = 0
        end
      end
    end
    object tabMP: TTabSheet
      Caption = 'MarketProfile'
      ImageIndex = 2
      object Panel5: TPanel
        Left = 0
        Top = 0
        Width = 480
        Height = 113
        Align = alTop
        BevelInner = bvRaised
        BevelOuter = bvLowered
        TabOrder = 0
        object Label6: TLabel
          Left = 8
          Top = 12
          Width = 56
          Height = 13
          Caption = 'Typ danych'
        end
        object Label7: TLabel
          Left = 8
          Top = 40
          Width = 96
          Height = 13
          Caption = 'Sp'#243#322'ka/Indeks/Fund'
        end
        object cbMPDataType: TComboBox
          Left = 112
          Top = 8
          Width = 185
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          ItemIndex = 0
          TabOrder = 0
          Text = '30 min'
          Items.Strings = (
            '30 min')
        end
        object cbMPSpolka: TComboBox
          Left = 112
          Top = 36
          Width = 185
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 1
        end
        object Button6: TButton
          Left = 112
          Top = 82
          Width = 185
          Height = 25
          Action = actGenMP
          TabOrder = 2
        end
      end
      object mmLogMP: TMemo
        Left = 0
        Top = 113
        Width = 480
        Height = 193
        Align = alClient
        ScrollBars = ssBoth
        TabOrder = 1
      end
    end
  end
  object alMain: TActionList
    Left = 12
    Top = 216
    object actDLCiagle: TAction
      Caption = 'Dane intra'
      OnExecute = actDLCiagleExecute
    end
    object actDLDzienne: TAction
      Caption = 'Dane dzienne'
      OnExecute = actDLDzienneExecute
    end
    object actDLBreak: TAction
      Caption = 'Przerwij pobieranie'
      OnExecute = actDLBreakExecute
    end
    object actGenIntraWeek: TAction
      Caption = 'Generuj'
      OnExecute = actGenIntraWeekExecute
    end
    object actGenMP: TAction
      Caption = 'Generuj'
      OnExecute = actGenMPExecute
    end
  end
end
