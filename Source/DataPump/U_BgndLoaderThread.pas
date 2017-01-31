unit U_BgndLoaderThread;

interface

uses
  Classes;

type
  TOnBgndDownloadedFile = procedure() of object;

  {
    Thread for async downloading set of files
  }
  TBgndLoaderThread = class(TThread)
  private
    FFiles : TStringList;
  protected
    procedure Execute; override;
  public
    //destination path for downloaded files
    DestPath : string;
    //file list in format: destination_file_path=http_path
    property Files : TStringList read FFiles;

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
  DestPath:='';
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
    GetInetFile(FFiles.ValueFromIndex[i], DestPath+fn+'.dl'); //pobranie pliku z tymczasowa nazwa
    RenameFile(DestPath+fn+'.dl', DestPath+fn); //zmiana nazwy na docelowa
  end;
end;

end.
