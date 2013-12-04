object fFormCheckbox: TfFormCheckbox
  Left = 252
  Top = 289
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  ClientHeight = 99
  ClientWidth = 287
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  PixelsPerInch = 96
  TextHeight = 12
  object Label1: TLabel
    Left = 12
    Top = 10
    Width = 265
    Height = 19
    AutoSize = False
    Caption = #25552#31034'1:'
    Layout = tlBottom
    WordWrap = True
  end
  object BtnOK: TButton
    Left = 135
    Top = 66
    Width = 65
    Height = 22
    Caption = #30830#23450
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object BtnExit: TButton
    Left = 212
    Top = 66
    Width = 65
    Height = 22
    Cancel = True
    Caption = #21462#28040
    ModalResult = 2
    TabOrder = 1
  end
  object CheckBox1: TCheckBox
    Left = 12
    Top = 34
    Width = 97
    Height = 17
    Caption = #25552#31034#20869#23481'2'
    TabOrder = 2
  end
  object RadioYes: TRadioButton
    Left = 134
    Top = 14
    Width = 113
    Height = 17
    Caption = #25552#31034'1'
    TabOrder = 3
  end
  object RadioNo: TRadioButton
    Left = 134
    Top = 36
    Width = 113
    Height = 17
    Caption = #25552#31034'2'
    TabOrder = 4
  end
end
