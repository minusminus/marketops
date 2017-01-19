unit U_FormMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, U_MCSim, ExtCtrls;

type
  TFormMain = class(TForm)
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    edtWRatio: TEdit;                         
    edtWLRatio: TEdit;
    edtCnt: TEdit;
    btnSimulate: TButton;
    Label4: TLabel;
    edtSimLen: TEdit;
    lblInfo: TLabel;
    mmLog: TMemo;
    GroupBox2: TGroupBox;
    pbSeries: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSimulateClick(Sender: TObject);
    procedure pbSeriesPaint(Sender: TObject);
  private
    MCSim : TMCSim;

    procedure DrawSimulationData;
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  caption:=Application.Title;
  MCSim:=TMCSim.Create;
  lblInfo.Caption:='';
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  MCSim.Free;
end;

procedure TFormMain.DrawSimulationData;
var
  bmp : TBitmap;
begin
  if MCSim.SimCount=0 then exit;

  bmp:=TBitmap.Create;
  try
    bmp.Width:=pbSeries.Width;
    bmp.Height:=pbSeries.Height;
    MCSim.DrawSeries(bmp);
    pbSeries.Canvas.Draw(0,0, bmp);
  finally
    bmp.Free;
  end;
end;

procedure TFormMain.pbSeriesPaint(Sender: TObject);
begin
  DrawSimulationData;
end;

procedure TFormMain.btnSimulateClick(Sender: TObject);
begin
  mmLog.Clear;
  lblInfo.Caption:='Generating...';
  Application.ProcessMessages;
  MCSim.Simulate( StrToFloat(edtWRatio.Text), strtofloat(edtWLRatio.Text),
                  StrToInt(edtSimLen.Text), StrToInt(edtCnt.Text) );
  MCSim.CalculateStats;
  mmLog.Lines.AddStrings(MCSim.Stats);
  lblInfo.Caption:='Done';
  pbSeries.Repaint;
end;

end.
