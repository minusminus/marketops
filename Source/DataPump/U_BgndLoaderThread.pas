unit U_BgndLoaderThread;

interface

uses
  Classes;

type
  TDownloadAsyncFile = class
  public
    ID : integer;
    URLPath : string;
    DestPath : string;
    FileName : string;
    Downloaded : boolean;
  end;

  TOnBgndDownloadedFile = procedure(AAsyncFileID : integer) of object;

  {
    Thread for async downloading set of files
  }
  TBgndLoaderThread = class(TThread)
  private
    FFilesToDL, FFilesReady : TList;
    FOnBgndDownloadedFile: TOnBgndDownloadedFile;

    procedure ClearFilesLists;
  protected
    procedure Execute; override;
  public
    property OnBgndDownloadedFile : TOnBgndDownloadedFile read FOnBgndDownloadedFile write FOnBgndDownloadedFile;

    constructor Create; overload;
    destructor Destroy; override;

    procedure AddFileToDownload(ADLObj : TDownloadAsyncFile);
  end;

implementation

uses U_InetFile, SysUtils;

{ TBgndLoaderThread }

constructor TBgndLoaderThread.Create;
begin
  inherited Create(true);
  Priority:=tpLowest;
  FreeOnTerminate:=false;
  FFilesToDL:=TList.Create;
  FFilesReady:=TList.Create;
end;

destructor TBgndLoaderThread.Destroy;
begin
  ClearFilesLists;
  FFilesReady.Free;
  FFilesToDL.Free;
  inherited;
end;

procedure TBgndLoaderThread.Execute;
var
  srcfn, destfn : string;
  o : TDownloadAsyncFile;
begin
  while FFilesToDL.Count>0 do
  begin
    if Terminated then break;
    o:=TDownloadAsyncFile(FFilesToDL[0]);

    srcfn:=o.URLPath + o.FileName;
    destfn:=o.DestPath + o.FileName + '.dl';
    GetInetFile(srcfn, destfn); //pobranie pliku z tymczasowa nazwa
    RenameFile(destfn, o.DestPath + o.FileName); //zmiana nazwy na docelowa
    FFilesReady.Add(o);
    FFilesToDL.Delete(0);
    if assigned(FOnBgndDownloadedFile) then
      FOnBgndDownloadedFile(o.ID);
  end;
end;

procedure TBgndLoaderThread.ClearFilesLists;
var
  i : integer;
begin
  for i := 0 to FFilesToDL.Count - 1 do
    TDownloadAsyncFile(FFilesToDL[i]).Free;
  FFilesToDL.Clear;
  for i := 0 to FFilesReady.Count - 1 do
    TDownloadAsyncFile(FFilesReady[i]).Free;
  FFilesReady.Clear;
end;

procedure TBgndLoaderThread.AddFileToDownload(ADLObj: TDownloadAsyncFile);
var
  o : TDownloadAsyncFile;
begin
  o:=TDownloadAsyncFile.Create;
  o.ID:=FFilesToDL.Count;
  o.URLPath:=ADLObj.URLPath;
  o.DestPath:=ADLObj.DestPath;
  o.FileName:=ADLObj.FileName;
  FFilesToDL.Add(o);
  ADLObj.ID:=o.ID;
end;

end.
