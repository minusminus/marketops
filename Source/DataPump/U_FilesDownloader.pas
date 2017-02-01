unit U_FilesDownloader;

interface

uses
  ZipMstr, U_BgndLoaderThread;

type
  TFilesDownloader = class
  private
    FBgndLoader : TBgndLoaderThread;

    procedure TerminateAndFreeBgndLoaderThread;
    function PrepareZIPFile(AZIPFN, ADestPath : string) : boolean;
  public
    constructor Create;
    destructor Destroy; override;

    {
      download and unzip specified file synchronously
      AURLPath - url of file to download
      ADestPath - destination folder, where file will be downloaded and unzipped
    }
    function DownloadAndUnzip(AURLPath, AFileName, ADestPath : string) : boolean;
  end;

implementation

uses
  rxfileutil, U_InetFile, SysUtils;

{ TFilesDownloader }

constructor TFilesDownloader.Create;
begin
  FBgndLoader:=nil;
end;

destructor TFilesDownloader.Destroy;
begin
  TerminateAndFreeBgndLoaderThread;
  inherited;
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

end.
