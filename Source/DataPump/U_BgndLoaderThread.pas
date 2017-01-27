unit U_BgndLoaderThread;

interface

uses
  Classes;

type
  {
    Thread for async downloading set of files
  }
  TBgndLoaderThread = class(TThread)
  private
  protected
    procedure Execute; override;
  public
    FFiles : TStringList; //file list in format: destination_file_path=http_path
    FDestPath : string;
    constructor Create; overload;
    destructor Destroy; override;
  end;

implementation

uses U_InetFile, SysUtils;

{ TBgndLoaderThread }

constructor TBgndLoaderThread.Create;
begin
  inherited Create(true);
  Priority:=tpLowest;
  FreeOnTerminate:=false;
  FFiles:=TStringList.Create;
  FDestPath:='';
end;

destructor TBgndLoaderThread.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TBgndLoaderThread.Execute;
var
  i : integer;
  fn : string;
begin
  for i := 0 to FFiles.Count - 1 do
  begin
    if Terminated then break;    
    fn:=ExtractFileName( FFiles.Names[i] );
    GetInetFile(FFiles.ValueFromIndex[i], FDestPath+fn+'.dl'); //pobranie pliku z tymczasowa nazwa
    RenameFile(FDestPath+fn+'.dl', FDestPath+fn); //zmiana nazwy na docelowa
  end;
end;

end.
