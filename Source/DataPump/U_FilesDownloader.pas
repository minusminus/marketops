unit U_FilesDownloader;

interface

uses
  ZipMstr, U_BgndLoaderThread, Classes;

type
  TOnCheckDownloadBreak = procedure(var VBreakLoad : boolean) of object;

  TFilesDownloader = class
  private
    FBgndLoader : TBgndLoaderThread;
    FDLAsyncObjs : TList;
    FOnCheckDownloadBreak: TOnCheckDownloadBreak;

    procedure TerminateAndFreeBgndLoaderThread;
    function PrepareZIPFile(AZIPFN, ADestPath : string) : boolean;
    procedure ClearDLAsyncObjs;
    procedure OnBgndDownloadedFile(AAsyncFileID : integer);
  public
    property OnCheckDownloadBreak : TOnCheckDownloadBreak read FOnCheckDownloadBreak write FOnCheckDownloadBreak;

    constructor Create;
    destructor Destroy; override;

    {
      download and unzip specified file synchronously
      AURLPath - url of file to download
      ADestPath - destination folder, where file will be downloaded and unzipped
    }
    function DownloadAndUnzip(AURLPath, AFileName, ADestPath : string) : boolean;

    //async downaloading
    procedure DownloadAsync(AURLPath, AFileName, ADestPath : string);
    procedure StartAsyncDownload;
    procedure StopAsyncDownload;
    function WaitAndUnzipAsyncFile(AFileName : string) : boolean;
  end;

implementation

uses
  rxfileutil, U_InetFile, SysUtils;

{ TFilesDownloader }

constructor TFilesDownloader.Create;
begin
  FBgndLoader:=nil;
  FDLAsyncObjs:=TList.Create;
end;

destructor TFilesDownloader.Destroy;
begin
  TerminateAndFreeBgndLoaderThread;
  ClearDLAsyncObjs;
  FDLAsyncObjs.Free;
  inherited;
end;

procedure TFilesDownloader.ClearDLAsyncObjs;
var
  i : integer;
begin
  for i := 0 to FDLAsyncObjs.Count - 1 do
    TDownloadAsyncFile(FDLAsyncObjs[i]).Free;
  FDLAsyncObjs.Clear;
end;

function TFilesDownloader.DownloadAndUnzip(AURLPath, AFileName,
  ADestPath: string): boolean;
var
  destfn : string;
begin
  ADestPath:=normaldir(ADestPath);
  ForceDirectories(ADestPath);
//  destfn:=ADestPath + ExtractFileName(AURLPath);
  destfn:=ADestPath + AFileName;
  GetInetFile(AURLPath + AFileName, destfn);
  result:=PrepareZIPFile(destfn, ADestPath);
end;

function TFilesDownloader.PrepareZIPFile(AZIPFN, ADestPath: string) : boolean;
const
  C_ERRORZIPFILESIZE = 300; //minimal accepted correct zip file size
var
  FZip : TZipMaster;
begin
  result:=false;
  if GetFileSize(AZIPFN) < C_ERRORZIPFILESIZE then exit;
  //have to create it every time, FZip created in constructor generates "nothing to do" exceptions and messages
  FZip:=TZipMaster.Create(nil);
  try
    FZip.ZipFileName:=AZIPFN;
    FZip.ExtrBaseDir:=NormalDir(ADestPath);
    FZip.Extract;
  finally
    FZip.Free;
  end;
  result:=true;
end;

procedure TFilesDownloader.TerminateAndFreeBgndLoaderThread;
begin
  if FBgndLoader=nil then exit;
  if not FBgndLoader.Suspended then FBgndLoader.Terminate;
  if not FBgndLoader.Suspended then FBgndLoader.WaitFor;
  FreeAndNil(FBgndLoader);
end;

function TFilesDownloader.WaitAndUnzipAsyncFile(AFileName: string): boolean;
var
  i : integer;
  o : TDownloadAsyncFile;
  b : boolean;
begin
  result:=false;
  o:=nil;
  for i := 0 to FDLAsyncObjs.Count - 1 do
    if TDownloadAsyncFile(FDLAsyncObjs[i]).FileName=AFileName then
    begin
      o:=TDownloadAsyncFile(FDLAsyncObjs[i]);
      break;
    end;
  if o=nil then exit;

  while not o.Downloaded do
  begin
    if Assigned(FOnCheckDownloadBreak) then
    begin
      b:=false;
      FOnCheckDownloadBreak(b);
      if b then exit;
    end;
    sleep(1000);
  end;
  result:=PrepareZIPFile(o.DestPath + o.FileName, o.DestPath);
end;

procedure TFilesDownloader.DownloadAsync(AURLPath, AFileName,
  ADestPath: string);
var
  o : TDownloadAsyncFile;
begin
  o:=TDownloadAsyncFile.Create;
  o.URLPath:=AURLPath;
  o.DestPath:=ADestPath;
  o.FileName:=AFileName;
  o.Downloaded:=false;
  FDLAsyncObjs.Add(o);
end;

procedure TFilesDownloader.OnBgndDownloadedFile(AAsyncFileID: integer);
var
  i : integer;
begin
  for i := 0 to FDLAsyncObjs.Count - 1 do
    if TDownloadAsyncFile(FDLAsyncObjs[i]).ID=AAsyncFileID then
    begin
      TDownloadAsyncFile(FDLAsyncObjs[i]).Downloaded:=true;
      break;
    end;
end;

procedure TFilesDownloader.StartAsyncDownload;
var
  i : integer;
begin
  TerminateAndFreeBgndLoaderThread;
  if FDLAsyncObjs.Count=0 then exit;  
  FBgndLoader:=TBgndLoaderThread.Create;
  FBgndLoader.OnBgndDownloadedFile:=OnBgndDownloadedFile;
  for i := 0 to FDLAsyncObjs.Count - 1 do
    FBgndLoader.AddFileToDownload(TDownloadAsyncFile(FDLAsyncObjs[i]));
  FBgndLoader.Resume;
end;

procedure TFilesDownloader.StopAsyncDownload;
begin
  TerminateAndFreeBgndLoaderThread;
end;

end.
